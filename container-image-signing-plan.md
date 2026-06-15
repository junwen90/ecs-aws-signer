# Container Image Signing – Implementation Plan

## Timeline
- Start: 08 June 2026
- Target Complete: 26 June 2026
- Duration: 18 working days

---

## Phase 1: Design & Setup (Days 1–3) | 08–10 June

- [ ] **1.1** Review current CI/CD pipeline for all 5 services (C2FA, WF Admin, Student Admin, SPFace, WF UAM)
- [ ] **1.2** Select pilot service (smallest/easiest – recommend starting with one service)
- [ ] **1.3** Design signature verification flow (Lambda + ECR + AWS Signer)
- [ ] **1.4** Define IAM roles/policies for ECR signing, Lambda verification, ECS deployment
- [ ] **1.5** Document architecture and get stakeholder approval

**Owner:** DevOps / Platform Team
**Est. Effort:** 3 days

---

## Phase 2: ECR Signing Configuration (Days 4–6) | 11–13 June

- [ ] **2.1** Enable AWS Signer on pilot service's ECR repository
- [ ] **2.2** Configure ECR managed signing rules
- [ ] **2.3** Push test image and verify signature is generated in AWS Signer
- [ ] **2.4** Validate image digest tracking in CI/CD pipeline

**Owner:** DevOps / Platform Team
**Est. Effort:** 3 days

---

## Phase 3: Lambda Verification Step (Days 7–10) | 14–17 June

- [ ] **3.1** Develop Lambda function to verify image signature against AWS Signer
- [ ] **3.2** Implement trust policy validation (only signed images from trusted signers)
- [ ] **3.3** Add failure handling: block deployment if verification fails
- [ ] **3.4** Write unit/integration tests for Lambda verification logic
- [ ] **3.5** Deploy Lambda to dev/staging environment for testing

**Owner:** Backend / Platform Team
**Est. Effort:** 4 days

---

## Phase 4: CI/CD Pipeline Integration (Days 11–13) | 18–20 June

- [ ] **4.1** Integrate Lambda verification step into CI/CD pipeline (pre-deployment gate)
- [ ] **4.2** Update pipeline to pass image digest to verification step
- [ ] **4.3** Add pipeline notifications for verification pass/fail
- [ ] **4.4** Test full flow on pilot service: build → push → sign → verify → deploy

**Owner:** DevOps / CI/CD Team
**Est. Effort:** 3 days

---

## Phase 5: SOP & Runbook Development (Days 14–15) | 21–22 June

- [ ] **5.1** Document image build/push SOP with digest tracking
- [ ] **5.2** Document signature verification step and failure handling procedures
- [ ] **5.3** Create break-glass exception process for urgent deployments
- [ ] **5.4** Define monitoring/alerting for verification outcomes (CloudWatch)
- [ ] **5.5** Review SOPs with operations team

**Owner:** DevOps / Operations Team
**Est. Effort:** 2 days

---

## Phase 6: Pilot Validation & Rollout (Days 16–18) | 23–26 June

- [ ] **6.1** Deploy pilot service to production with signing enabled
- [ ] **6.2** Monitor first few deployments end-to-end
- [ ] **6.3** Validate monitoring, logging, and alerting
- [ ] **6.4** Roll out to remaining 4 services
- [ ] **6.5** Final review and sign-off

**Owner:** All Teams
**Est. Effort:** 3 days

---

## Risk & Mitigation

| Risk | Mitigation |
|------|-----------|
| Signing failure blocks deployment | Break-glass SOP with manual override process |
| Lambda verification latency | Optimize Lambda; add timeout/fallback config |
| IAM misconfiguration | Review policies with security team before production |
| Rollout delays | Start with pilot, validate early, cascade quickly |

---

## AWS Cost Impact Summary

| Service | Cost Level | Notes |
|---------|-----------|-------|
| ECR Managed Signing / AWS Signer | Low–Moderate | Scales with image pushes |
| Lambda (verification) | Low | Scales with deployments |
| CloudWatch Logs/Metrics | Low | Retain for audit |
| EventBridge (optional) | Low | If used for orchestration |
| **Overall** | **Low** | Shared across all 5 services |

---

## Client Communication Points

- SOPs updated to cover signing, verification, and failure handling
- Security benefit: only verified, signed images deploy to production
- Shared setup across all services – low incremental cost per service
- External AWS costs: low and predictable
- Target completion: 26 June 2026
