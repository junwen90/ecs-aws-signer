# Container Image Signing - Implementation Files

This repository contains all implementation files for the Container Image Signing project.

## Structure

```
container-image-signing/
├── infra/                          # Terraform infrastructure code
│   ├── main.tf                     # Terraform provider configuration
│   ├── iam.tf                      # IAM roles and policies
│   ├── ecr.tf                      # ECR repository with signing enabled
│   ├── lambda.tf                   # Lambda function configuration
│   ├── variables.tf                # Input variables
│   ├── outputs.tf                  # Output values
│   ├── variables.example.tfvars    # Example variable values
│   ├── .gitignore
│   └── README.md
├── lambda/
│   └── verify-signature/           # Signature verification Lambda
│       ├── index.js                # Lambda handler and verification logic
│       ├── index.test.js           # Unit tests
│       ├── package.json            # Node.js dependencies
│       └── .gitignore
├── pipeline/
│   └── build-sign-deploy.yml       # CI/CD pipeline configuration
├── sop/                            # Standard Operating Procedures
│   ├── container-image-signing-sop.md
│   └── break-glass-register.md
└── monitoring/
    └── monitoring-config.md        # CloudWatch dashboards and alarms
```

## Quick Start

### 1. Deploy Infrastructure

```bash
cd infra
terraform init
terraform plan -var-file="variables.example.tfvars"
terraform apply -var-file="variables.example.tfvars"
```

### 2. Deploy Lambda

```bash
cd lambda/verify-signature
npm install
npm run package
# Lambda will be deployed by Terraform
```

### 3. Configure Pipeline

- Copy `pipeline/build-sign-deploy.yml` to your CI/CD project
- Update environment variables for your service
- Configure GitHub Actions secrets

### 4. Deploy to Pilot Service

- Select one service for pilot (recommend starting with smallest)
- Enable ECR signing for the pilot repository
- Run pipeline and verify end-to-end flow

## Services in Scope

1. C2FA
2. WF Admin
3. Student Admin
4. SPFace (eAttendance modules)
5. WF UAM

## Documentation

- SOP: `sop/container-image-signing-sop.md`
- Break-Glass: `sop/break-glass-register.md`
- Monitoring: `monitoring/monitoring-config.md`
