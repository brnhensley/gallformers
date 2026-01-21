# Capability: AWS Infrastructure

Infrastructure-as-code management for all AWS resources using OpenTofu.

## ADDED Requirements

### Requirement: OpenTofu project structure

The repository MUST include an `infra/` directory containing OpenTofu configuration files that define all AWS infrastructure.

#### Scenario: Developer initializes OpenTofu
Given the `infra/` directory exists
When the developer runs `tofu init`
Then OpenTofu initializes successfully with S3 backend

#### Scenario: Developer views planned changes
Given OpenTofu is initialized
When the developer runs `tofu plan`
Then OpenTofu displays any differences between config and actual state

---

### Requirement: S3 state backend with native locking

OpenTofu state MUST be stored in S3 with encryption and native file-based locking (no DynamoDB required).

#### Scenario: State is persisted to S3
Given OpenTofu is configured with S3 backend
When the developer runs `tofu apply`
Then state is written to `gallformers-terraform-state` bucket
And state file is encrypted at rest

#### Scenario: Concurrent applies are prevented
Given two developers attempt `tofu apply` simultaneously
When the second apply starts
Then it fails with a lock error until the first completes

---

### Requirement: S3 buckets managed via OpenTofu

All S3 buckets MUST be defined in OpenTofu and can be created, updated, or destroyed through IaC.

#### Scenario: Bucket configuration matches code
Given S3 buckets are imported into OpenTofu
When the developer runs `tofu plan`
Then no drift is reported for bucket configuration

#### Scenario: Bucket policy changes are tracked
Given a bucket policy is modified in OpenTofu config
When the developer runs `tofu apply`
Then the bucket policy is updated in AWS

---

### Requirement: IAM users and policies managed via OpenTofu

IAM users and their policies MUST be defined in OpenTofu (excluding personal admin users).

#### Scenario: IAM policy changes are tracked
Given IAM policies are imported into OpenTofu
When the developer runs `tofu plan`
Then no drift is reported for IAM configuration

#### Scenario: New IAM policy can be created
Given a new policy is defined in OpenTofu config
When the developer runs `tofu apply`
Then the policy is created in AWS IAM

---

### Requirement: CloudFront distribution managed via OpenTofu

The CloudFront distribution for image delivery MUST be defined in OpenTofu.

#### Scenario: CloudFront origin can be updated
Given CloudFront is imported into OpenTofu
When the developer changes the origin in config
And runs `tofu apply`
Then the CloudFront distribution origin is updated

---

### Requirement: Images bucket in us-east-1

The main images bucket (`gallformers`) MUST be located in us-east-1 to match Fly.io region.

#### Scenario: Images bucket is in correct region
Given the images bucket is defined in OpenTofu
When inspecting the bucket configuration
Then the region is us-east-1

---

### Requirement: S3 CORS for presigned uploads

The images bucket MUST have CORS configured to allow presigned URL uploads from the web application.

#### Scenario: Presigned upload succeeds from allowed origin
Given CORS is configured on the images bucket
When a browser at gallformers.org uploads via presigned URL
Then the upload succeeds without CORS errors

#### Scenario: Presigned upload blocked from unknown origin
Given CORS is configured on the images bucket
When a browser at evil.com attempts upload via presigned URL
Then the upload fails with CORS error
