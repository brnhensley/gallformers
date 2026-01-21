# Design: Adopt OpenTofu for AWS Infrastructure

## Decision: OpenTofu

**Why OpenTofu over alternatives:**

| Tool | Verdict | Reason |
|------|---------|--------|
| **OpenTofu** | Chosen | Truly open source (MPL 2.0), CNCF/Linux Foundation, S3 state with native locking, huge ecosystem |
| Terraform | Rejected | BSL license (not open source since 2023), vendor lock-in concerns |
| Pulumi | Rejected | Vendor dependency unless self-hosting state, more complexity |
| CloudFormation | Rejected | AWS-only, verbose YAML, poor ergonomics |
| Ansible | Rejected | Procedural not declarative, poor state tracking |

## Architecture

```
infra/
├── main.tf           # Provider config, backend
├── variables.tf      # Input variables
├── outputs.tf        # Output values
├── s3.tf             # S3 buckets and configs
├── iam.tf            # IAM users, roles, policies
├── cloudfront.tf     # CloudFront distribution
├── lambda.tf         # Lambda function (future)
└── .gitignore        # Ignore .terraform/, *.tfstate*
```

## State Backend

S3 backend with native locking (OpenTofu 1.10+):

```hcl
terraform {
  backend "s3" {
    bucket       = "gallformers-terraform-state"
    key          = "infra/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true  # Native S3 locking, no DynamoDB
  }
}
```

## Region Strategy

Unify all resources to **us-east-1** (N. Virginia) to match Fly.io `iad` datacenter:

| Resource | Current | Target |
|----------|---------|--------|
| gallformers bucket | us-east-2 | us-east-1 (migrate) |
| gallformers-backups | us-east-1 | us-east-1 (no change) |
| gallformers-full-backups | us-east-1 | us-east-1 (no change) |
| CloudFront | Global | Global (update origin) |
| IAM | Global | Global |

## Images Bucket Migration

The `gallformers` bucket must be migrated from us-east-2 to us-east-1. S3 buckets cannot be moved, so:

1. Create new bucket `gallformers` in us-east-1 (same name possible after deletion, or use new name)
2. Sync all objects with `aws s3 sync`
3. Update CloudFront origin
4. Update app configs if bucket name changes
5. Delete old bucket

**Consideration**: During sync, CloudFront will serve cached content. Schedule during low-traffic period.

## IAM Cleanup

Current state has cruft:

| Issue | Fix |
|-------|-----|
| Dead SQS reference in `GallfomersImagesPolicy` | Remove statement |
| Typo: `GallfomersImagesPolicy` | Rename to `GallformersImagesPolicy` |
| Duplicate policies on s3-upload user | Consolidate into single managed policy |
| No versioning on images bucket | Enable versioning |

## Security Considerations

- **Access keys not in IaC** - Stored in Fly.io secrets / GitHub secrets
- **State encryption** - S3 bucket with encryption enabled
- **No admin user** - `jeff` IAM user excluded from OpenTofu management
- **Least privilege** - Each IAM user/role has minimal required permissions
