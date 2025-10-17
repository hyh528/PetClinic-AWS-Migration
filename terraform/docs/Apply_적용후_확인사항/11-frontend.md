# 11. Frontend

## AWS 콘솔 확인 방법

1. **S3 > Buckets**:
    - `petclinic-dev-frontend-bucket`
2. **CloudFront > Distributions**:
    - `petclinic-dev-frontend-distribution`
3. **Route 53 > Hosted Zones** (선택사항):
    - `petclinic.dev` 호스팅 영역
4. **Certificate Manager > Certificates** (선택사항):
    - `*.petclinic.dev` SSL 인증서

## AWS CLI로 확인 방법

```bash
# S3 버킷 확인
aws s3 ls s3://petclinic-dev-frontend-bucket/ --region ap-northeast-2

# S3 버킷 정책 확인
aws s3api get-bucket-policy --bucket petclinic-dev-frontend-bucket --region ap-northeast-2 --query "Policy" | jq .

# CloudFront 배포 확인
aws cloudfront list-distributions --region ap-northeast-2 --query "DistributionList.Items[?Comment=='petclinic-dev-frontend-distribution'].[Id,DomainName,Status,LastModifiedTime]" --output table

# CloudFront 배포 세부 정보 확인
DISTRIBUTION_ID=$(aws cloudfront list-distributions --region ap-northeast-2 --query "DistributionList.Items[?Comment=='petclinic-dev-frontend-distribution'].Id" --output text)
aws cloudfront get-distribution --id $DISTRIBUTION_ID --region ap-northeast-2 --query "Distribution.DistributionConfig.[Origins.Items[0].DomainName,DefaultCacheBehavior.TargetOriginId]"

# Route 53 호스팅 영역 확인 (사용하는 경우)
aws route53 list-hosted-zones --query "HostedZones[?Name=='petclinic.dev.'].[Name,Id,ResourceRecordSetCount]" --output table

# SSL 인증서 확인 (사용하는 경우)
aws acm list-certificates --region us-east-1 --query "CertificateSummaryList[?DomainName=='*.petclinic.dev'].[DomainName,CertificateArn,Status]" --output table

# 상태 파일 확인
cd terraform/layers/11-frontend && terraform state list

data.terraform_remote_state.api_gateway
module.cloudfront.aws_cloudfront_distribution.frontend_distribution
module.cloudfront.aws_cloudfront_origin_access_identity.oai
module.s3_frontend.aws_s3_bucket.frontend_bucket
module.s3_frontend.aws_s3_bucket_policy.frontend_bucket_policy
module.s3_frontend.aws_s3_bucket_public_access_block.frontend_bucket
module.s3_frontend.aws_s3_bucket_versioning.frontend_bucket
module.s3_frontend.aws_s3_bucket_website_configuration.frontend_bucket

# output 확인
cd terraform/layers/11-frontend && terraform output

cloudfront_distribution_domain_name = "xxxxxxxxxxxxxx.cloudfront.net"
cloudfront_distribution_id = "xxxxxxxxxxxxxx"
s3_bucket_name = "petclinic-dev-frontend-bucket"
s3_bucket_regional_domain_name = "petclinic-dev-frontend-bucket.s3.ap-northeast-2.amazonaws.com"