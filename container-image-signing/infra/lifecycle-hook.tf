# ECS Task Verification via EventBridge (for Fargate)

# EventBridge Rule to capture ECS task state changes (PROVISIONING -> RUNNING)
resource "aws_cloudwatch_event_rule" "ecs_task_state_change" {
  name        = "ecs-task-state-change-${var.environment}"
  description = "Trigger signature verification on ECS task state changes"

  event_pattern = jsonencode({
    source      = ["aws.ecs"]
    detail-type = ["ECS Task State Change"]
    detail = {
      clusterArn = [aws_ecs_cluster.signing_test.arn]
      taskArn    = [] # Will be populated at runtime
      lastStatus = ["PROVISIONING"]
    }
  })

  tags = {
    Name = "ecs-task-state-change-${var.environment}"
  }
}

# EventBridge Target - invoke verification Lambda
resource "aws_cloudwatch_event_target" "verify_signature_lambda" {
  rule      = aws_cloudwatch_event_rule.ecs_task_state_change.name
  target_id = "VerifySignatureLambda"
  arn       = aws_lambda_function.verify_signature.arn
  role_arn  = aws_iam_role.eventbridge_lambda_role.arn

  dead_letter_config {
    arn = aws_sqs_queue.verification_dlq.arn
  }

  input_transformer {
    input_paths = {
      taskArn       = "$.detail.taskArn"
      clusterArn    = "$.detail.clusterArn"
      lastStatus    = "$.detail.lastStatus"
      taskDefinition = "$.detail.taskDefinitionArn"
    }
    input_template = jsonencode({
      taskArn        = "<taskArn>"
      clusterArn     = "<clusterArn>"
      lastStatus     = "<lastStatus>"
      taskDefinition = "<taskDefinition>"
    })
  }
}

# DLQ for failed verification events
resource "aws_sqs_queue" "verification_dlq" {
  name                      = "ecs-verification-dlq-${var.environment}"
  message_retention_seconds = 1209600

  tags = {
    Name = "ecs-verification-dlq-${var.environment}"
  }
}

# Lambda permission for EventBridge to invoke
resource "aws_lambda_permission" "allow_eventbridge_invoke" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.verify_signature.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ecs_task_state_change.arn
}

# IAM Role for EventBridge to invoke Lambda
resource "aws_iam_role" "eventbridge_lambda_role" {
  name = "eventbridge-lambda-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "eventbridge-lambda-role-${var.environment}"
  }
}

# IAM Policy for EventBridge role
resource "aws_iam_role_policy" "eventbridge_lambda_policy" {
  name = "eventbridge-lambda-policy-${var.environment}"
  role = aws_iam_role.eventbridge_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = aws_lambda_function.verify_signature.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.verification_dlq.arn
      }
    ]
  })
}
