# IAM Roles and Policies for Container Image Signing

# Role for ECR to perform signing with AWS Signer
resource "aws_iam_role" "ecr_signing_role" {
  name = "ecr-signing-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecr.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "ecr-signing-role-${var.environment}"
  }
}

# Policy allowing ECR to use AWS Signer
resource "aws_iam_role_policy" "ecr_signing_policy" {
  name = "ecr-signing-policy-${var.environment}"
  role = aws_iam_role.ecr_signing_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "signer:DescribeSignJob",
          "signer:GetSigningProfile",
          "signer:StartSignJob"
        ]
        Resource = "*"
      }
    ]
  })
}

# Role for Lambda signature verification
resource "aws_iam_role" "lambda_verify_role" {
  name = "lambda-verify-signature-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "lambda-verify-signature-role-${var.environment}"
  }
}

# Policy for Lambda to verify signatures and access ECS resources
resource "aws_iam_role_policy" "lambda_verify_policy" {
  name = "lambda-verify-policy-${var.environment}"
  role = aws_iam_role.lambda_verify_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "signer:DescribeSignJob",
          "signer:GetSigningProfile",
          "ecr:DescribeImage",
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeTaskDefinition",
          "ecs:StopTask",
          "ecs:DescribeTasks"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:CompleteLifecycleAction"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/verify-signature-*"
      }
    ]
  })
}

# Role for CI/CD pipeline to push images and trigger verification
resource "aws_iam_role" "pipeline_role" {
  name = "pipeline-ecr-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

# Policy for pipeline to interact with ECR
resource "aws_iam_role_policy" "pipeline_policy" {
  name = "pipeline-ecr-policy-${var.environment}"
  role = aws_iam_role.pipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:GetAuthorizationToken",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
        Resource = var.ecr_repository_arns
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = aws_lambda_function.verify_signature.arn
      }
    ]
  })
}
