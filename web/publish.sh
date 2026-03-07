#!/bin/bash
set -e

BUCKET_NAME="dressagecaller.app"
AWS_PROFILE="dressagecaller"

export AWS_PROFILE

echo "Uploading website files to S3..."
aws s3 sync . "s3://$BUCKET_NAME" --exclude ".*" --exclude "*.sh" --exclude "*.json" --delete

echo "Creating CloudFront invalidation..."
DIST_ID=$(aws cloudfront list-distributions --query "DistributionList.Items[?Aliases.Items[?contains(@, '$BUCKET_NAME')]].Id | [0]" --output text)

if [ -n "$DIST_ID" ]; then
  INVALIDATION_ID=$(aws cloudfront create-invalidation --distribution-id "$DIST_ID" --paths "/*" --query 'Invalidation.Id' --output text)
  echo "Invalidation created: $INVALIDATION_ID"
else
  echo "Warning: CloudFront distribution not found"
fi

echo ""
echo "Deployment complete!"
