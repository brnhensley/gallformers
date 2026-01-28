#!/usr/bin/env bash
#
# Import existing CloudFront distribution into OpenTofu state.
#
# Prerequisites:
#   - AWS credentials configured for account 885187511538
#   - tofu init already run in infra/
#
# Usage:
#   Run each command individually (or the whole script) from the infra/ directory.
#   Review `tofu plan` output after importing to check for drift.
#
# NOTE: After import, `tofu plan` will show drift because:
#   - The origin is changing from gallformers.s3.amazonaws.com to the new
#     us-east-1 images bucket
#   - An Origin Access Control is being added (security improvement)
#   This drift is expected and intentional.

set -euo pipefail

cd "$(dirname "$0")"

# --- Origin Access Control ---

# OAC is new — no import needed, it will be created by tofu apply.

# --- CloudFront Distribution ---

# Existing images CDN distribution (dhz6u1p7t6okk.cloudfront.net)
tofu import aws_cloudfront_distribution.images E3B3XXYW8G4SB2
