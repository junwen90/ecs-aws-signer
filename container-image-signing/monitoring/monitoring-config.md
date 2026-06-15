# Monitoring Configuration

## CloudWatch Dashboards

### Container Signing Dashboard

Create a CloudWatch dashboard with the following widgets:

#### Lambda Metrics
- **Invocation Count**: Total invocations of verify-signature Lambda
- **Error Count**: Number of failed verifications
- **Duration**: P50, P90, P95 latency
- **Throttles**: Number of throttled invocations

#### ECR Metrics
- **Image Push Count**: Number of images pushed per repository
- **Scan Findings**: Vulnerability scan results

#### Custom Metrics
- **Signature Verification Success Rate**: Percentage of successful verifications
- **Deployment Success Rate**: Percentage of successful deployments after verification

## Alarms

### High Error Rate
- **Metric**: Lambda errors
- **Condition**: Errors > 5% of invocations over 5 minutes
- **Action**: SNS notification to DevOps team

### Verification Failure Spike
- **Metric**: Custom metric for verification failures
- **Condition**: > 3 failures in 10 minutes
- **Action**: SNS notification + PagerDuty

### Lambda Duration High
- **Metric**: Lambda duration P95
- **Condition**: P95 > 25 seconds over 10 minutes
- **Action**: SNS notification to investigate

## Log Groups

| Log Group | Retention | Purpose |
|-----------|-----------|---------|
| `/aws/lambda/verify-signature-dev` | 7 days | Dev environment |
| `/aws/lambda/verify-signature-staging` | 30 days | Staging environment |
| `/aws/lambda/verify-signature-production` | 90 days | Production environment |

## Log Query Examples

### Failed Verifications (Last 24 Hours)
```
fields @timestamp, @message
| filter @message like /verification failed/
| sort @timestamp desc
| limit 20
```

### Signature Verification Success Rate
```
filter @message like /verification passed/
| stats count() as success by bin(1h)
```

### Image Digests Deployed
```
filter @message like /Image signature verified/
| fields @message
| parse @message "*repository*: *" as repo, digest
| stats count() by repo
```

## SNS Topics

| Topic | Purpose | Subscribers |
|-------|---------|-------------|
| `container-signing-errors` | Lambda and verification errors | DevOps team email, Slack |
| `container-signing-deployments` | Deployment notifications | Ops team, Slack channel |
