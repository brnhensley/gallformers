# S3 and IAM Setup for Backups

Step-by-step guide to set up AWS infrastructure for Litestream backups.

## Prerequisites

- AWS CLI installed and configured (`aws configure`)
- AWS account with permissions to create S3 buckets and IAM users

## 1. Create S3 Bucket

```bash
# Create the bucket in us-east-1 (matches Fly.io iad region)
aws s3api create-bucket \
  --bucket gallformers-backups \
  --region us-east-1

# Enable versioning for recovery from accidental overwrites
aws s3api put-bucket-versioning \
  --bucket gallformers-backups \
  --versioning-configuration Status=Enabled
```

## 2. Configure Public Read Policy

Create a bucket policy that allows public read access only to the `public/` prefix (for daily snapshots), while keeping Litestream backups private.

```bash
# Create policy file
cat > /tmp/bucket-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadSnapshots",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::gallformers-backups/public/*"
    }
  ]
}
EOF

# Apply the bucket policy
aws s3api put-bucket-policy \
  --bucket gallformers-backups \
  --policy file:///tmp/bucket-policy.json
```

## 3. Create IAM User for Litestream

```bash
# Create the IAM user
aws iam create-user --user-name litestream-gallformers
```

## 4. Create IAM Policy

Create a policy that grants Litestream the minimum permissions needed:

```bash
# Create policy file
cat > /tmp/litestream-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "LitestreamBackups",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::gallformers-backups",
        "arn:aws:s3:::gallformers-backups/*"
      ]
    }
  ]
}
EOF

# Create the policy in IAM
aws iam create-policy \
  --policy-name LitestreamGallformersBackup \
  --policy-document file:///tmp/litestream-policy.json
```

Note the ARN returned (e.g., `arn:aws:iam::123456789012:policy/LitestreamGallformersBackup`).

## 5. Attach Policy to User

```bash
# Replace with your actual account ID
aws iam attach-user-policy \
  --user-name litestream-gallformers \
  --policy-arn arn:aws:iam::YOUR_ACCOUNT_ID:policy/LitestreamGallformersBackup
```

To find your account ID:
```bash
aws sts get-caller-identity --query Account --output text
```

## 6. Generate Access Keys

```bash
aws iam create-access-key --user-name litestream-gallformers
```

This outputs:
```json
{
  "AccessKey": {
    "UserName": "litestream-gallformers",
    "AccessKeyId": "AKIA...",
    "SecretAccessKey": "...",
    "Status": "Active",
    "CreateDate": "..."
  }
}
```

**Save these credentials securely** - the secret access key is only shown once.

## 7. Configure Fly.io Secrets

Add the credentials to Fly.io (task 13.4):

```bash
fly secrets set \
  LITESTREAM_ACCESS_KEY_ID=AKIA... \
  LITESTREAM_SECRET_ACCESS_KEY=... \
  -a gallformers
```

## 8. Configure GitHub Actions Secrets

For the daily snapshot workflow (task 13.5), add to GitHub repository secrets:

- `AWS_ACCESS_KEY_ID` - Same as LITESTREAM_ACCESS_KEY_ID
- `AWS_SECRET_ACCESS_KEY` - Same as LITESTREAM_SECRET_ACCESS_KEY

## Verification

After setup, verify the configuration:

```bash
# Test bucket exists and versioning is enabled
aws s3api get-bucket-versioning --bucket gallformers-backups

# Test IAM user has correct permissions (run as the litestream user)
# Create a test profile first:
aws configure --profile litestream-test
# Enter the access key ID and secret key

# Test write access
echo "test" | aws s3 cp - s3://gallformers-backups/test.txt --profile litestream-test

# Test read access
aws s3 cp s3://gallformers-backups/test.txt - --profile litestream-test

# Clean up test file
aws s3 rm s3://gallformers-backups/test.txt --profile litestream-test

# Test public read (this should work without credentials)
curl -I https://gallformers-backups.s3.amazonaws.com/public/test.txt
# Expected: 404 (file doesn't exist yet, but access is allowed)
```

## Lifecycle Rules (Optional)

To control costs, add lifecycle rules to delete old Litestream generations:

```bash
cat > /tmp/lifecycle.json << 'EOF'
{
  "Rules": [
    {
      "ID": "DeleteOldLitestreamVersions",
      "Status": "Enabled",
      "Filter": {
        "Prefix": "litestream/"
      },
      "NoncurrentVersionExpiration": {
        "NoncurrentDays": 30
      }
    }
  ]
}
EOF

aws s3api put-bucket-lifecycle-configuration \
  --bucket gallformers-backups \
  --lifecycle-configuration file:///tmp/lifecycle.json
```

## Summary

| Resource | Value |
|----------|-------|
| Bucket | `gallformers-backups` |
| Region | `us-east-1` |
| Litestream path | `s3://gallformers-backups/litestream` |
| Public snapshot | `s3://gallformers-backups/public/gallformers.sqlite` |
| Public URL | `https://gallformers-backups.s3.amazonaws.com/public/gallformers.sqlite` |
| IAM user | `litestream-gallformers` |

## Next Steps

After completing this setup:
1. Add Litestream to Docker image (task 13.3)
2. Configure Fly.io secrets (task 13.4)
3. Create daily snapshot workflow (task 13.5)
