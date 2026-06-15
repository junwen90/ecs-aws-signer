output "ecr_repository_urls" {
  description = "URLs of ECR repositories with signing enabled"
  value       = { for k, v in aws_ecr_repository.signing_enabled : k => v.repository_url }
}

output "lambda_function_arn" {
  description = "ARN of the signature verification Lambda function"
  value       = aws_lambda_function.verify_signature.arn
}

output "lambda_function_name" {
  description = "Name of the signature verification Lambda function"
  value       = aws_lambda_function.verify_signature.function_name
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for Lambda"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}
