# Standard Operating Procedure - Container Image Signing

## 1. Purpose

This SOP defines the procedures for building, signing, verifying, and deploying
container images to ECS Fargate using Amazon ECR managed signing with AWS Signer.

## 2. Scope

This SOP applies to all 5 ECS services in the MySF environment:
- C2FA
- WF Admin
- Student Admin
- SPFace (eAttendance modules)
- WF UAM

## 3. Prerequisites

- Images must be built via the approved CI/CD pipeline
- ECR repositories must have managed signing enabled
- Lambda verification function must be deployed and operational
- IAM roles and policies must be configured per infrastructure code

## 4. Image Build and Push

### 4.1 Build Process

1. Developer pushes code to `main` or `release/*` branch
2. CI/CD pipeline triggers automatically
3. Docker image is built using the Dockerfile in the repository root
4. Image is tagged with commit SHA: `<repo>:<sha>`

### 4.2 Push to ECR

1. Pipeline authenticates to Amazon ECR
2. Image is pushed to the private ECR repository
3. Image tag mutability is set to IMMUTABLE
4. ECR automatically triggers AWS Signer to sign the image

### 4.3 Digest Tracking

- Image digest is captured and stored in pipeline logs
- Digest format: `sha256:<64-char-hex-string>`
- Digest is passed to verification step before deployment

## 5. Signature Verification

### 5.1 Automated Verification

1. After image push, pipeline invokes Lambda function `verify-signature-<env>`
2. Lambda verifies:
   - Image exists in ECR repository
   - Signature exists in AWS Signer and status is "Completed"
   - Signature is from a trusted signer (allowed AWS account)
3. If verification passes: deployment proceeds
4. If verification fails: deployment is blocked, pipeline fails

### 5.2 Manual Verification (if needed)

```bash
# Check if image exists in ECR
aws ecr describe-images \
  --repository-name <repo-name> \
  --image-ids imageDigest=<digest>

# Invoke verification Lambda manually
aws lambda invoke \
  --function-name "verify-signature-<env>" \
  --payload "{\"repository\": \"<repo-name>\", \"imageDigest\": \"<digest>\"}" \
  /tmp/verify-response.json

cat /tmp/verify-response.json
```

## 6. Failure Handling

### 6.1 Common Failure Scenarios

| Scenario | Cause | Action |
|----------|-------|--------|
| Signature not found | ECR signing not yet complete | Wait 1-2 minutes and retry |
| Signature from untrusted signer | IAM misconfiguration | Check AWS account ID in Lambda config |
| Image not found in ECR | Push failed or wrong digest | Verify image was pushed successfully |
| Lambda invocation timeout | Lambda resource limits | Check CloudWatch logs, increase timeout if needed |

### 6.2 Retry Procedure

1. Check CloudWatch logs for error details:
   ```bash
   aws logs tail /aws/lambda/verify-signature-<env> --follow
   ```
2. Fix the root cause
3. Re-run the pipeline or re-trigger deployment
4. Verify signature again before proceeding

## 7. Exception Handling - Break-Glass Process

### 7.1 When to Use

- Critical production issue requiring immediate deployment
- Signing infrastructure outage
- Verified image cannot be signed due to technical issue

### 7.2 Break-Glass Procedure

1. **Request**: Submit break-glass request to DevOps lead with:
   - Reason for exception
   - Image digest to be deployed
   - Impact of not deploying

2. **Approval**: DevOps lead approves and documents the exception

3. **Temporary Bypass**: DevOps team temporarily updates Lambda to allow the specific digest:
   ```bash
   # Update Lambda environment variable with allowed digests
   aws lambda update-function-configuration \
     --function-name "verify-signature-<env>" \
     --environment "Variables={ALLOWED_DIGESTS=<comma-separated-digests>}"
   ```

4. **Deploy**: Run pipeline with the approved image

5. **Restore**: After deployment, revert Lambda configuration

6. **Document**: Log the incident in the break-glass register with:
   - Date/time
   - Requestor
   - Reason
   - Image deployed
   - Approval

### 7.3 Post-Incident

- Review root cause within 48 hours
- Implement fix to prevent recurrence
- Update SOP if procedures need improvement

## 8. Monitoring and Audit

### 8.1 CloudWatch Metrics

- Lambda invocation count and duration
- Lambda error rate
- ECR image push count

### 8.2 CloudWatch Logs

- Lambda logs retained for 30 days
- Pipeline logs retained per CI/CD settings
- Search logs by environment and date

### 8.3 Audit Trail

- All deployments logged with image digest
- Signature verification results logged
- Break-glass incidents logged and reviewed

### 8.4 Alerting

- Alert on Lambda error rate > 5%
- Alert on deployment failures
- Alert on signature verification failures

## 9. Roles and Responsibilities

| Role | Responsibility |
|------|---------------|
| Developer | Write code, trigger pipeline |
| DevOps Team | Maintain pipeline, infrastructure, Lambda |
| Operations Team | Monitor deployments, handle incidents |
| Security Team | Review policies, audit access |
| DevOps Lead | Approve break-glass requests |

## 10. Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-06-09 | DevOps Team | Initial version |
