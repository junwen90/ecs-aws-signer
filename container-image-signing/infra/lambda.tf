# Lambda Function for Signature Verification

resource "aws_lambda_function" "verify_signature" {
  filename         = "../lambda/verify-signature/verify-signature.zip"
  function_name    = "verify-signature-${var.environment}"
  role             = aws_iam_role.lambda_verify_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  timeout          = 60
  memory_size      = 256

  environment {
    variables = {
      ENVIRONMENT        = var.environment
      ALLOWED_ACCOUNT_ID = var.allowed_account_id
      LOG_LEVEL          = var.log_level
      ECS_CLUSTER_NAME   = var.ecs_cluster_name
      ECS_SERVICE_NAME   = var.ecs_service_name
    }
  }

  tracing_config {
    mode = "Active"
  }

  tags = {
    Name = "verify-signature-${var.environment}"
  }
}

# Lambda permission for Lambda invocation from pipeline
resource "aws_lambda_permission" "allow_invoke" {
  statement_id  = "AllowPipelineInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.verify_signature.function_name
  principal     = var.pipeline_principal

  source_arn = var.pipeline_principal_arn
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/verify-signature-${var.environment}"
  retention_in_days = 30

  tags = {
    Name = "verify-signature-logs-${var.environment}"
  }
}
