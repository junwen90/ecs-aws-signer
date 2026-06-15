const { DescribeSignJobsCommand, GetSigningProfileCommand } = require("@aws-sdk/client-signer");
const { ECRClient, DescribeImagesCommand } = require("@aws-sdk/client-ecr");

const mockSignerClient = {
  send: jest.fn(),
};

const mockEcrClient = {
  send: jest.fn(),
};

jest.mock("@aws-sdk/client-signer", () => ({
  SignerClient: jest.fn(() => mockSignerClient),
  DescribeSignJobsCommand: jest.fn(),
  GetSigningProfileCommand: jest.fn(),
}));

jest.mock("@aws-sdk/client-ecr", () => ({
  ECRClient: jest.fn(() => mockEcrClient),
  DescribeImagesCommand: jest.fn(),
}));

describe("Signature Verification", () => {
  let handler;

  beforeAll(async () => {
    process.env.ALLOWED_ACCOUNT_ID = "123456789012";
    process.env.ENVIRONMENT = "test";

    handler = require("./index").handler;
  });

  beforeEach(() => {
    jest.clearAllMocks();
  });

  test("should verify a valid signed image", async () => {
    mockEcrClient.send.mockResolvedValueOnce({
      imageDetails: [{ imageDigest: "sha256:abc123" }],
    });

    mockSignerClient.send
      .mockResolvedValueOnce({
        signJobs: [
          {
            signJobId: "job-123",
            status: "Completed",
            imageReferences: [{ digest: "sha256:abc123" }],
          },
        ],
      })
      .mockResolvedValueOnce({
        arn: "arn:aws:signer:us-east-1:123456789012:/signing-profiles/my-profile",
      });

    const event = {
      repository: "my-service",
      imageDigest: "sha256:abc123",
    };

    const result = await handler(event);

    expect(result.statusCode).toBe(200);
    expect(JSON.parse(result.body).message).toBe("Image signature verified successfully");
  });

  test("should reject image without signature", async () => {
    mockEcrClient.send.mockResolvedValueOnce({
      imageDetails: [{ imageDigest: "sha256:unsigned" }],
    });

    mockSignerClient.send.mockResolvedValueOnce({
      signJobs: [],
    });

    const event = {
      repository: "my-service",
      imageDigest: "sha256:unsigned",
    };

    const result = await handler(event);

    expect(result.statusCode).toBe(400);
    expect(JSON.parse(result.body).message).toBe("Signature verification failed");
  });

  test("should reject missing parameters", async () => {
    const event = {
      repository: "my-service",
    };

    const result = await handler(event);

    expect(result.statusCode).toBe(400);
  });
});
