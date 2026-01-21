# Change: Adopt OpenTofu for AWS Infrastructure

## Why

AWS resources are currently managed manually via the AWS console. This creates several problems:

- **No version control** - Infrastructure changes are not tracked or auditable
- **Manual errors** - Easy to misconfigure resources via point-and-click
- **Disaster recovery** - Recreating infrastructure from scratch would be painful
- **Legacy cruft** - Dead SQS references, typos in policy names, duplicate policies accumulate
- **Region inconsistency** - Resources split between us-east-1 and us-east-2

OpenTofu (open source Terraform fork under Linux Foundation/CNCF) enables infrastructure-as-code to solve these problems.

## What Changes

### New Capability: Infrastructure as Code

- **OpenTofu project** in `infra/` directory
- **S3 state backend** with native locking (OpenTofu 1.10+, no DynamoDB needed)
- **All AWS resources** defined in HCL and version controlled
- **Cleanup of legacy cruft** (dead SQS refs, typos, duplicate policies)
- **Region unification** - Migrate images bucket from us-east-2 to us-east-1

### AWS Resources to Manage

| Resource Type | Items |
|--------------|-------|
| S3 Buckets | gallformers, gallformers-backups, gallformers-full-backups, state bucket |
| IAM Users | litestream-gallformers, s3-upload |
| IAM Policies | LitestreamGallformersBackup, s3-put (consolidated) |
| CloudFront | Distribution E3B3XXYW8G4SB2 |

### What We're NOT Changing

- **Fly.io** - Managed separately (fly.toml, not OpenTofu)
- **Auth0** - External service, managed via its dashboard
- **Domain/DNS** - Namecheap, managed separately
- **`jeff` IAM user** - Personal admin user excluded from IaC

## Impact

- **Affected code**: New `infra/` directory
- **Dependencies**: None - infrastructure work is independent
- **Risk**: Low - import existing resources, no changes until cleanup phase

## Success Criteria

1. All AWS resources defined in OpenTofu and state tracked
2. `tofu plan` shows no drift from actual infrastructure
3. Legacy IAM cruft cleaned up (dead SQS ref, typo, duplicate policies)
4. Images bucket migrated to us-east-1
5. CloudFront updated to use new bucket location
6. S3 CORS configured for presigned uploads from web app

## Open Questions

1. **gallformers-dev bucket**: Keep, migrate, or deprecate? (Likely deprecate - see `gallformers-chp5`)

## Related Beads

- `gallformers-nq4j` - Epic: Implement OpenTofu for AWS Infrastructure
- `gallformers-gbcn` - Set up OpenTofu project structure
- `gallformers-bfuu` - Import S3 buckets
- `gallformers-fa91` - Import IAM users/policies
- `gallformers-6vkv` - Import CloudFront
- `gallformers-111t` - Clean up legacy IAM policies
- `gallformers-1akk` - Migrate images bucket to us-east-1
- `gallformers-chp5` - Decide fate of gallformers-dev bucket
