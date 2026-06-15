const { SignerClient, DescribeSignJobsCommand, GetSigningProfileCommand } = require("@aws-sdk/client-signer");
const { ECRClient, DescribeImagesCommand } = require("@aws-sdk/client-ecr");
const { ECSClient, DescribeTaskDefinitionCommand, StopTaskCommand } = require("@aws-sdk/client-ecs");
const { AutoScalingClient, CompleteLifecycleActionCommand } = require("@aws-sdk/client-auto-scaling");
const { randomUUID } = require("crypto");

const signerClient = new SignerClient();
const ecrClient = new ECRClient();
const ecsClient = new ECSClient();
const autoscalingClient = new AutoScalingClient();

const ALLOWED_ACCOUNT_ID = process.env.ALLOWED_ACCOUNT_ID;
const LOG_LEVEL = process.env.LOG_LEVEL || "INFO";
const ENVIRONMENT = process.env.ENVIRONMENT;

function log(level, message, data = null) {
  const entry = {
    timestamp: new Date().toISOString(),
    level,
    environment: ENVIRONMENT,
    message,
  };
  if (data) entry.data = data;
  console.log(JSON.stringify(entry));
}

exports.handler = async (event) => {
  log("INFO", "Signature verification started", { event });

  try {
    // Parse the event - could be EventBridge, direct API call, or Lifecycle Hook
    const verificationContext = parseEvent(event);
    
    if (!verificationContext) {
      throw new Error("Unable to parse verification context from event");
    }

    log("INFO", "Verification context extracted", verificationContext);

    const { repository, imageDigest, taskArn, clusterArn, taskDefinition } = verificationContext;

    // Verify the image signature
    const signatureValid = await verifySignature(repository, imageDigest);

    if (!signatureValid) {
      log("ERROR", "Image signature verification failed", {
        repository,
        imageDigest,
        taskArn,
      });

      // Stop the task if signature is invalid
      if (taskArn && clusterArn) {
        await stopECSTask(taskArn, clusterArn);
      }

      return {
        statusCode: 400,
        body: JSON.stringify({
          message: "Signature verification failed",
          imageDigest,
          action: "Task stopped",
        }),
      };
    }

    log("INFO", "Signature verification passed", {
      repository,
      imageDigest,
      taskArn,
    });

    return {
      statusCode: 200,
      body: JSON.stringify({
        message: "Image signature verified successfully",
        repository,
        imageDigest,
        verifiedAt: new Date().toISOString(),
      }),
    };
  } catch (error) {
    log("ERROR", "Signature verification failed", {
      error: error.message,
      stack: error.stack,
    });

    return {
      statusCode: 400,
      body: JSON.stringify({
        message: "Signature verification failed",
        error: error.message,
      }),
    };
  }
};

// Parse the event to extract repository and image digest
function parseEvent(event) {
  log("DEBUG", "Parsing event structure", { eventKeys: Object.keys(event) });

  // Handle EventBridge event (from ECS task state change)
  if (event.taskArn && event.clusterArn) {
    return {
      eventType: "eventbridge",
      taskArn: event.taskArn,
      clusterArn: event.clusterArn,
      taskDefinition: event.taskDefinition,
      // Will be extracted later from task definition
      repository: null,
      imageDigest: null,
    };
  }

  // Handle direct Lambda invocation with repository and imageDigest
  if (event.repository && event.imageDigest) {
    return {
      eventType: "direct",
      repository: event.repository,
      imageDigest: event.imageDigest,
      taskArn: event.taskArn || null,
      clusterArn: event.clusterArn || null,
    };
  }

  // Handle SNS event (from Lifecycle Hook)
  if (event.Records && event.Records[0] && event.Records[0].Sns) {
    const message = JSON.parse(event.Records[0].Sns.Message);
    return {
      eventType: "sns",
      lifecycleContext: message,
      taskArn: null,
      clusterArn: null,
    };
  }

  throw new Error("Unable to parse event - unexpected structure");
}

// Extract image digest from ECS task definition
async function extractImageDigestFromTask(taskDefinitionArn) {
  try {
    const command = new DescribeTaskDefinitionCommand({
      taskDefinition: taskDefinitionArn,
    });

    const response = await ecsClient.send(command);

    if (!response.taskDefinition || !response.taskDefinition.containerDefinitions) {
      throw new Error("No container definitions found in task definition");
    }

    // Get the first container's image
    const containerDef = response.taskDefinition.containerDefinitions[0];
    const image = containerDef.image;

    if (!image) {
      throw new Error("No image found in container definition");
    }

    log("DEBUG", "Image extracted from task definition", { image });

    // Parse the image reference (format: <registry>/<repository>:<tag> or <registry>/<repository>@<digest>)
    const imageParts = image.split("/");
    const repository = imageParts.slice(1).join("/").split(":")[0].split("@")[0];

    log("DEBUG", "Repository extracted from image", { repository, fullImage: image });

    return { repository, image };
  } catch (error) {
    log("ERROR", "Failed to extract image from task definition", {
      taskDefinitionArn,
      error: error.message,
    });
    throw error;
  }
}

// Verify signature of the image
async function verifySignature(repository, imageDigest) {
  // Step 1: Verify image exists in ECR
  if (repository && imageDigest) {
    await verifyImageInECR(repository, imageDigest);
  }

  // Step 2: Verify signature exists in AWS Signer
  const signatureValid = await verifySignatureInSigner(imageDigest);

  if (!signatureValid) {
    return false;
  }

  // Step 3: Verify signature is from trusted signer
  const trusted = await verifyTrustedSigner();

  return trusted;
}

async function stopECSTask(taskArn, clusterArn) {
  try {
    const command = new StopTaskCommand({
      cluster: clusterArn,
      task: taskArn,
      reason: "Image signature verification failed",
    });

    await ecsClient.send(command);
    log("INFO", "ECS task stopped due to signature verification failure", { taskArn });
  } catch (error) {
    log("ERROR", "Failed to stop ECS task", {
      taskArn,
      error: error.message,
    });
    throw error;
  }
}

async function verifyImageInECR(repository, imageDigest) {
  try {
    const command = new DescribeImagesCommand({
      repositoryName: repository,
      imageIds: [{ imageDigest: imageDigest }],
    });

    const response = await ecrClient.send(command);

    if (!response.imageDetails || response.imageDetails.length === 0) {
      throw new Error(`Image ${imageDigest} not found in ECR repository ${repository}`);
    }

    log("DEBUG", "Image verified in ECR", { repository, imageDigest });
  } catch (error) {
    log("ERROR", "ECR image verification failed", {
      repository,
      imageDigest,
      error: error.message,
    });
    throw error;
  }
}

async function verifySignatureInSigner(imageDigest) {
  try {
    const command = new DescribeSignJobsCommand({});
    const response = await signerClient.send(command);

    if (!response.signJobs || response.signJobs.length === 0) {
      log("WARN", "No sign jobs found in AWS Signer");
      return false;
    }

    // Find sign job matching the image digest
    const matchingJob = response.signJobs.find((job) => {
      return job.imageReferences?.some(
        (ref) => ref.digest === imageDigest
      );
    });

    if (!matchingJob) {
      log("WARN", "No matching sign job found for image", { imageDigest });
      return false;
    }

    const isValid = matchingJob.status === "Completed";

    log("DEBUG", "Sign job status check", {
      imageDigest,
      jobId: matchingJob.signJobId,
      status: matchingJob.status,
      isValid,
    });

    return isValid;
  } catch (error) {
    log("ERROR", "Signer verification failed", {
      imageDigest,
      error: error.message,
    });
    throw error;
  }
}

async function verifyTrustedSigner() {
  try {
    const command = new GetSigningProfileCommand({
      platformId: "AWS::ECRContainerImage",
    });

    const response = await signerClient.send(command);

    if (!response) {
      log("WARN", "No signing profile found");
      return false;
    }

    const signerAccountId = response.arn?.split(":")[4];

    if (signerAccountId !== ALLOWED_ACCOUNT_ID) {
      log("WARN", "Signer account mismatch", {
        expected: ALLOWED_ACCOUNT_ID,
        actual: signerAccountId,
      });
      return false;
    }

    log("DEBUG", "Trusted signer verified", { signerAccountId });
    return true;
  } catch (error) {
    log("ERROR", "Trusted signer verification failed", {
      error: error.message,
    });
    throw error;
  }
}
