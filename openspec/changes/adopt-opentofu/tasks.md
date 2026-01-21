# Tasks: Adopt OpenTofu for AWS Infrastructure

## Phase 1: Project Setup

### 1.1 OpenTofu Installation and Project Structure
- [ ] 1.1.1 Install OpenTofu locally (`brew install opentofu`)
- [ ] 1.1.2 Create `infra/` directory in repo root
- [ ] 1.1.3 Create `infra/main.tf` with AWS provider and backend config
- [ ] 1.1.4 Create `infra/variables.tf` for configurable values
- [ ] 1.1.5 Create `infra/outputs.tf` for output values
- [ ] 1.1.6 Add `.gitignore` entries for `.terraform/`, `*.tfstate*`, `.terraform.lock.hcl`

### 1.2 State Backend
- [ ] 1.2.1 Create S3 bucket `gallformers-terraform-state` in us-east-1
- [ ] 1.2.2 Enable versioning on state bucket
- [ ] 1.2.3 Enable encryption on state bucket
- [ ] 1.2.4 Run `tofu init` to initialize backend
- [ ] 1.2.5 Verify state file created in S3

## Phase 2: Import Existing Resources

### 2.1 Import S3 Buckets
- [ ] 2.1.1 Create `infra/s3.tf` with resource definitions
- [ ] 2.1.2 Import `gallformers-backups` bucket
- [ ] 2.1.3 Import `gallformers-backups` versioning config
- [ ] 2.1.4 Import `gallformers-backups` bucket policy
- [ ] 2.1.5 Import `gallformers-full-backups` bucket
- [ ] 2.1.6 Import `gallformers-full-backups` versioning config
- [ ] 2.1.7 Run `tofu plan` to verify no drift

### 2.2 Import IAM Users and Policies
- [ ] 2.2.1 Create `infra/iam.tf` with resource definitions
- [ ] 2.2.2 Import `litestream-gallformers` user
- [ ] 2.2.3 Import `s3-upload` user
- [ ] 2.2.4 Import `LitestreamGallformersBackup` policy
- [ ] 2.2.5 Import `s3-put` policy
- [ ] 2.2.6 Import policy attachments
- [ ] 2.2.7 Import inline policy `GallfomersImagesPolicy`
- [ ] 2.2.8 Run `tofu plan` to verify no drift

### 2.3 Import CloudFront Distribution
- [ ] 2.3.1 Create `infra/cloudfront.tf` with resource definition
- [ ] 2.3.2 Import CloudFront distribution `E3B3XXYW8G4SB2`
- [ ] 2.3.3 Run `tofu plan` to verify no drift

## Phase 3: Migrate Images Bucket

### 3.1 Create New Bucket
- [ ] 3.1.1 Add new `gallformers` bucket resource in us-east-1 to `infra/s3.tf`
- [ ] 3.1.2 Configure bucket policy for public read
- [ ] 3.1.3 Configure public access block settings
- [ ] 3.1.4 Enable versioning on new bucket
- [ ] 3.1.5 Apply changes to create new bucket

### 3.2 Sync Content
- [ ] 3.2.1 Schedule migration during low-traffic period
- [ ] 3.2.2 Run `aws s3 sync` from old bucket to new bucket
- [ ] 3.2.3 Verify object count matches
- [ ] 3.2.4 Spot check random images are accessible

### 3.3 Update CloudFront
- [ ] 3.3.1 Update CloudFront origin in `infra/cloudfront.tf`
- [ ] 3.3.2 Run `tofu apply` to update distribution
- [ ] 3.3.3 Verify images load via CloudFront URL
- [ ] 3.3.4 Invalidate CloudFront cache if needed

### 3.4 Cleanup Old Bucket
- [ ] 3.4.1 Verify all access goes through new bucket
- [ ] 3.4.2 Remove old bucket from OpenTofu state
- [ ] 3.4.3 Delete old bucket via AWS console (manual, safety)

## Phase 4: IAM Cleanup

### 4.1 Remove Dead SQS Reference
- [ ] 4.1.1 Update `infra/iam.tf` to remove SQS statement from policy
- [ ] 4.1.2 Run `tofu plan` to verify change
- [ ] 4.1.3 Apply change

### 4.2 Consolidate s3-upload Policies
- [ ] 4.2.1 Create new consolidated `GallformersImageUpload` policy (note: fixes typo)
- [ ] 4.2.2 Attach new policy to `s3-upload` user
- [ ] 4.2.3 Remove old `s3-put` policy attachment
- [ ] 4.2.4 Remove inline `GallfomersImagesPolicy`
- [ ] 4.2.5 Delete old policies
- [ ] 4.2.6 Verify s3-upload user still has correct permissions

## Phase 5: S3 CORS Configuration

### 5.1 Configure CORS for Presigned Uploads
- [ ] 5.1.1 Add CORS configuration to images bucket in `infra/s3.tf`
- [ ] 5.1.2 Allow origins: gallformers.org, gallformers.com, gallformers.fly.dev, localhost:4000
- [ ] 5.1.3 Allow methods: PUT, GET
- [ ] 5.1.4 Run `tofu apply` to configure CORS
- [ ] 5.1.5 Test presigned URL upload from localhost

## Phase 6: Documentation and Decisions

### 6.1 Documentation
- [ ] 6.1.1 Update `CLAUDE.md` with `infra/` directory and OpenTofu commands
- [ ] 6.1.2 Create `infra/README.md` with setup instructions
- [ ] 6.1.3 Document credential management (AWS CLI profile or env vars)

### 6.2 Decide on gallformers-dev Bucket
- [ ] 6.2.1 Check if bucket is actively used
- [ ] 6.2.2 Check if bucket has any content
- [ ] 6.2.3 Make deprecate/migrate/keep decision
- [ ] 6.2.4 Execute decision (likely deprecate)

## Dependencies

```
Phase 1 (Setup) → Phase 2 (Import)
Phase 2 (Import) → Phase 3 (Migrate) [for S3 import]
Phase 2 (Import) → Phase 4 (IAM Cleanup) [for IAM import]
Phase 3 (Migrate) → Phase 5 (CORS) [bucket must exist]
```

## Parallelizable Work

After Phase 2:
- Phase 3 (Migrate bucket) and Phase 4 (IAM Cleanup) can run in parallel
- Phase 6 (Documentation) can happen anytime

## Related Beads

| Bead | Task |
|------|------|
| `gallformers-gbcn` | Phase 1 |
| `gallformers-bfuu` | Phase 2.1 |
| `gallformers-fa91` | Phase 2.2 |
| `gallformers-6vkv` | Phase 2.3 |
| `gallformers-1akk` | Phase 3 |
| `gallformers-111t` | Phase 4 |
| `gallformers-chp5` | Phase 6.2 |
