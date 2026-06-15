# AWS Signer Configuration for Container Image Signing

# Signing Profile for ECR Images
resource "aws_signer_signing_profile" "ecr_signing_profile" {
  platform_id = "AWS::ECRContainerImage"
  name        = "ecr-signing-profile-${var.environment}"

  signature_validity {
    value = 3650
    type  = "DAYS"
  }

  tags = {
    Name = "ecr-signing-profile-${var.environment}"
  }
}

# CloudWatch Event Rule to trigger signing on ECR push
resource "aws_cloudwatch_event_rule" "ecr_image_push" {
  name        = "ecr-image-push-${var.environment}"
  description = "Trigger AWS Signer when image is pushed to ECR"

  event_pattern = jsonencode({
    source      = ["aws.ecr"]
    detail-type = ["ECR Image Action"]
    detail = {
      action = ["PUSH"]
      result = ["SUCCESS"]
    }
  })

  tags = {
    Name = "ecr-image-push-${var.environment}"
  }
}

# CloudWatch Event Target (invoke Signer)
# Note: AWS automatically signs images when they are pushed to ECR with signing enabled
# This rule can be used for additional logging/notifications

resource "aws_cloudwatch_event_target" "ecr_push_logging" {
  rule      = aws_cloudwatch_event_rule.ecr_image_push.name
  target_id = "ECRPushLogging"
  arn       = aws_cloudwatch_log_group.ecr_push_logs.arn

  dead_letter_config {
    arn = aws_sqs_queue.ecr_push_dlq.arn
  }
}

# CloudWatch Log Group for ECR push events
resource "aws_cloudwatch_log_group" "ecr_push_logs" {
  name              = "/aws/events/ecr-push-${var.environment}"
  retention_in_days = 7

  tags = {
    Name = "ecr-push-logs-${var.environment}"
  }
}

# DLQ for failed events
resource "aws_sqs_queue" "ecr_push_dlq" {
  name                      = "ecr-push-dlq-${var.environment}"
  message_retention_seconds = 1209600

  tags = {
    Name = "ecr-push-dlq-${var.environment}"
  }
}

# Policy to allow CloudWatch Events to put logs
resource "aws_cloudwatch_log_resource_policy" "ecr_push_log_policy" {
  policy_name = "ecr-push-log-policy-${var.environment}"

  policy_text = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "logs:PutLogEvents"
        Resource = "${aws_cloudwatch_log_group.ecr_push_logs.arn}:*"
      }
    ]
  })
}

# Update ECR repository encryption with KMS (optional but recommended)
# This is referenced in ecr.tf - ensuring signing profile is available for use
