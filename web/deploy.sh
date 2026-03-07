#!/bin/bash
set -e

DOMAIN="dressagecaller.app"
BUCKET_NAME="$DOMAIN"
REGION="us-east-1"
CERTIFICATE_ARN="arn:aws:acm:us-east-1:737146114400:certificate/7f6821d9-e615-4e55-944f-59c18eb4410b"
AWS_PROFILE="dressagecaller"

export AWS_PROFILE

echo "Creating S3 bucket: $BUCKET_NAME"
aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION" 2>/dev/null || echo "Bucket exists"

echo "Blocking public access"
aws s3api put-public-access-block --bucket "$BUCKET_NAME" \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "Uploading website files"
aws s3 sync . "s3://$BUCKET_NAME" --exclude ".*" --exclude "*.sh"

echo "Creating Origin Access Control"
OAC_ID=$(aws cloudfront create-origin-access-control \
  --origin-access-control-config \
  "Name=$BUCKET_NAME-oac,SigningProtocol=sigv4,SigningBehavior=always,OriginAccessControlOriginType=s3" \
  --query 'OriginAccessControl.Id' --output text 2>/dev/null || \
  aws cloudfront list-origin-access-controls --query "OriginAccessControlList.Items[?Name=='$BUCKET_NAME-oac'].Id | [0]" --output text)

echo "Creating CloudFront distribution"
DIST_ID=$(aws cloudfront create-distribution \
  --distribution-config "{
    \"CallerReference\":\"$(date +%s)\",
    \"Aliases\":{\"Quantity\":1,\"Items\":[\"$DOMAIN\"]},
    \"DefaultRootObject\":\"index.html\",
    \"Origins\":{\"Quantity\":1,\"Items\":[{
      \"Id\":\"S3-$BUCKET_NAME\",
      \"DomainName\":\"$BUCKET_NAME.s3.$REGION.amazonaws.com\",
      \"OriginAccessControlId\":\"$OAC_ID\",
      \"S3OriginConfig\":{\"OriginAccessIdentity\":\"\"}
    }]},
    \"DefaultCacheBehavior\":{
      \"TargetOriginId\":\"S3-$BUCKET_NAME\",
      \"ViewerProtocolPolicy\":\"redirect-to-https\",
      \"AllowedMethods\":{\"Quantity\":2,\"Items\":[\"GET\",\"HEAD\"],\"CachedMethods\":{\"Quantity\":2,\"Items\":[\"GET\",\"HEAD\"]}},
      \"CachePolicyId\":\"658327ea-f89d-4fab-a63d-7e88639e58f6\",
      \"Compress\":true
    },
    \"ViewerCertificate\":{
      \"ACMCertificateArn\":\"$CERTIFICATE_ARN\",
      \"SSLSupportMethod\":\"sni-only\",
      \"MinimumProtocolVersion\":\"TLSv1.2_2021\"
    },
    \"Comment\":\"DressageCaller website\",
    \"Enabled\":true
  }" --query 'Distribution.Id' --output text)

echo "Setting bucket policy for CloudFront access only"
aws s3api put-bucket-policy --bucket "$BUCKET_NAME" --policy "{
  \"Version\":\"2012-10-17\",
  \"Statement\":[{
    \"Sid\":\"AllowCloudFrontServicePrincipal\",
    \"Effect\":\"Allow\",
    \"Principal\":{\"Service\":\"cloudfront.amazonaws.com\"},
    \"Action\":\"s3:GetObject\",
    \"Resource\":\"arn:aws:s3:::$BUCKET_NAME/*\",
    \"Condition\":{\"StringEquals\":{\"AWS:SourceArn\":\"arn:aws:cloudfront::$(aws sts get-caller-identity --query Account --output text):distribution/$DIST_ID\"}}
  }]
}"

CF_DOMAIN=$(aws cloudfront get-distribution --id "$DIST_ID" --query 'Distribution.DomainName' --output text)
echo ""
echo "CloudFront distribution: $DIST_ID"
echo "CloudFront domain: $CF_DOMAIN"
echo ""
echo "Point $DOMAIN DNS to $CF_DOMAIN"
