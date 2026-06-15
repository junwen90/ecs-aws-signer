# Container Image Signing - Infrastructure

This directory contains infrastructure-as-code for enabling ECR managed signing
and the signature verification Lambda function.

## Structure

- `main.tf` - Main infrastructure configuration
- `iam.tf` - IAM roles and policies
- `ecr.tf` - ECR repository configuration with signing enabled
- `lambda.tf` - Lambda function for signature verification
- `variables.tf` - Input variables
- `outputs.tf` - Output values

## Prerequisites

- AWS CLI configured
- Terraform >= 1.5
- AWS provider >= 5.0

## Usage

```bash
terraform init
terraform plan -var="environment=staging"
terraform apply -var="environment=staging"
```
