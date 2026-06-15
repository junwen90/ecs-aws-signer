# ECS Signature Verification - Deployment & Testing Guide

## Prerequisites

1. AWS account with appropriate permissions
2. AWS CLI configured
3. Terraform >= 1.5.0
4. Docker installed locally
5. Node.js >= 18.0.0

---

## Phase 1: Prepare Lambda Package

Before deploying, you need to package the Lambda function:

```bash
cd lambda/verify-signature
npm install
npm run package
cd ../../
```

This creates `verify-signature.zip` in the `lambda/verify-signature/` directory, which Terraform will reference.

---

## Phase 2: Prepare Terraform Variables

Create a `variables.tfvars` file in the `infra/` directory:

```hcl
aws_region           = "ap-southeast-1"  # Change to your region
environment          = "dev"
prefix               = "mysf"
allowed_account_id   = "123456789012"    # Your AWS account ID
log_level            = "DEBUG"           # Use DEBUG for testing
oidc_provider_arn    = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"  # Optional for CI/CD
pipeline_principal   = "arn:aws:iam::123456789012:role/GitHubActionsRole"  # Optional
pipeline_principal_arn = "arn:aws:iam::123456789012:role/GitHubActionsRole"  # Optional
ecr_repository_arns  = []  # Will be created by Terraform
ecs_cluster_name     = "signing-test-cluster-dev"
ecs_service_name     = "signing-test-service-dev"
```

---

## Phase 3: Deploy Infrastructure

```bash
cd infra

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan deployment (review changes)
terraform plan -var-file="variables.tfvars"

# Apply deployment
terraform apply -var-file="variables.tfvars"
```

After successful deployment, Terraform will output:
- ECR repository URLs
- Lambda function name
- ECS cluster name
- CloudWatch log groups

Save these outputs for later reference.

---

## Phase 4: Manual Testing - Happy Path

### Step 1: Build and Push an Image

```bash
# 1. Login to ECR
aws ecr get-login-password --region ap-southeast-1 | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.ap-southeast-1.amazonaws.com

# 2. Build a test image
docker build -t signing-test:v1 .

# 3. Tag for ECR
docker tag signing-test:v1 <ACCOUNT_ID>.dkr.ecr.ap-southeast-1.amazonaws.com/mysf-<service-name>:v1

# 4. Push to ECR (AWS Signer will automatically sign this)
docker push <ACCOUNT_ID>.dkr.ecr.ap-southeast-1.amazonaws.com/mysf-<service-name>:v1

# 5. Wait 10-15 seconds for AWS Signer to sign the image
sleep 15

# 6. Verify signature was created
aws signer describe-sign-jobs \
  --platform-id AWS::ECRContainerImage \
  --region ap-southeast-1
```

### Step 2: Update ECS Service with New Image

```bash
# Get the image digest from the push output or ECR
IMAGE_DIGEST=$(aws ecr describe-images \
  --repository-name mysf-<service-name> \
  --image-ids imageTag=v1 \
  --query 'imageDetails[0].imageId.imageDigest' \
  --output text \
  --region ap-southeast-1)

echo "Image Digest: $IMAGE_DIGEST"

# Update the ECS task definition with the new image
aws ecs update-service \
  --cluster signing-test-cluster-dev \
  --service signing-test-service-dev \
  --force-new-deployment \
  --region ap-southeast-1
```

### Step 3: Monitor Verification

```bash
# Check Lambda logs in real-time
aws logs tail /aws/lambda/verify-signature-dev --follow --region ap-southeast-1

# Expected output (Happy Path):
# - "Image verified in ECR"
# - "Sign job status check" with status "Completed"
# - "Trusted signer verified"
# - "Signature verification passed"
```

### Step 4: Verify Task Launched

```bash
# List ECS tasks to confirm they're running
aws ecs list-tasks \
  --cluster signing-test-cluster-dev \
  --region ap-southeast-1

# Describe the task to see details
aws ecs describe-tasks \
  --cluster signing-test-cluster-dev \
  --tasks <TASK_ARN> \
  --region ap-southeast-1
```

---

## Phase 5: Testing - Failure Path (Optional)

To test the failure scenario where signature verification fails:

### Option 1: Use an Unsigned Image

```bash
# Create a new ECR repository without signing enabled
aws ecr create-repository \
  --repository-name test-unsigned \
  --region ap-southeast-1

# Push an image there (no auto-signing)
docker tag signing-test:v1 <ACCOUNT_ID>.dkr.ecr.ap-southeast-1.amazonaws.com/test-unsigned:v1
docker push <ACCOUNT_ID>.dkr.ecr.ap-southeast-1.amazonaws.com/test-unsigned:v1

# Manually update ECS service with this unsigned image
# This should fail verification and task should be stopped
```

### Option 2: Wait for Signer Timeout

Just push an image and immediately trigger ECS deployment (without waiting for AWS Signer to complete signing). The Lambda should detect that signing is incomplete and block the deployment.

---

## Troubleshooting

### Lambda logs show "No sign jobs found"

**Cause**: AWS Signer may not have auto-signed the image yet or is still processing.

**Solution**: 
- Wait 15-20 seconds after pushing the image
- Verify the signing profile exists: `aws signer get-signing-profile --platform-id AWS::ECRContainerImage --region ap-southeast-1`

### Lambda timeout

**Cause**: Lambda timeout set too short or verification taking longer than expected.

**Solution**:
- Increase Lambda timeout in `infra/lambda.tf` (currently 60 seconds)
- Check CloudWatch logs for performance bottlenecks

### EventBridge rule not triggering

**Cause**: ECS task state change event not matching the rule pattern.

**Solution**:
- Check EventBridge rule in CloudWatch: AWS Console → EventBridge → Rules
- Monitor the rule's "Invocations" metric
- Verify the task is transitioning to PROVISIONING state

### ECS task not starting

**Cause**: 
- Security group blocking egress
- VPC/subnet configuration
- IAM role missing permissions

**Solution**:
- Check ECS task logs in CloudWatch: `/ecs/signing-test-dev`
- Verify security group allows outbound traffic on all ports (0.0.0.0/0)
- Check IAM role permissions for ECS task execution role

---

## Cleanup

To remove all resources:

```bash
cd infra
terraform destroy -var-file="variables.tfvars"
```

---

## Next Steps

After successful testing:

1. **Test with real application images** - Replace nginx with your actual service image
2. **Automate with CI/CD** - Integrate with GitHub Actions to auto-push signed images
3. **Production deployment** - Replicate this setup in your production AWS account
4. **Monitoring & Alerts** - Set up CloudWatch alarms for signature verification failures

---

## Flow Summary

```
Push Docker Image
      ↓
ECR receives image
      ↓
AWS Signer auto-signs (10-15 seconds)
      ↓
User triggers ECS service update
      ↓
ECS task transitions to PROVISIONING
      ↓
EventBridge detects state change
      ↓
EventBridge invokes Verification Lambda
      ↓
Lambda extracts image digest from task definition
      ↓
Lambda calls AWS Signer to verify signature
      ↓
If Valid: Task continues → RUNNING
If Invalid: Task stopped → STOPPED
```
