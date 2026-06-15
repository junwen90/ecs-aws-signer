variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  default     = "staging"
}

variable "prefix" {
  description = "Resource name prefix"
  type        = string
  default     = "mysf"
}

variable "allowed_account_id" {
  description = "AWS account ID allowed to deploy signed images"
  type        = string
}

variable "log_level" {
  description = "Log level for Lambda function"
  type        = string
  default     = "INFO"
  validation {
    condition     = contains(["DEBUG", "INFO", "WARN", "ERROR"], var.log_level)
    error_message = "Log level must be DEBUG, INFO, WARN, or ERROR."
  }
}

variable "services" {
  description = "List of ECS services in scope"
  type = object({
    name = string
  })
  default = [
    { name = "c2fa" },
    { name = "wf-admin" },
    { name = "student-admin" },
    { name = "spface-eattendance" },
    { name = "wf-uam" }
  ]
}

variable "ecr_repository_arns" {
  description = "ARNs of ECR repositories"
  type        = list(string)
  default     = []
}

variable "oidc_provider_arn" {
  description = "OIDC provider ARN for GitHub Actions"
  type        = string
}

variable "pipeline_principal" {
  description = "Principal ARN allowed to invoke verification Lambda"
  type        = string
}

variable "pipeline_principal_arn" {
  description = "Source ARN for Lambda permission"
  type        = string
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster for signature verification testing"
  type        = string
  default     = "signing-test-cluster"
}

variable "ecs_service_name" {
  description = "Name of the ECS service"
  type        = string
  default     = "signing-test-service"
}
