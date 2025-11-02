#!/bin/bash

# 프론트엔드 배포 스크립트
# 사용법: ./scripts/deploy-frontend.sh [environment]

set -e

# 환경 설정
ENVIRONMENT=${1:-dev}
AWS_REGION="us-west-2"

# 환경별 설정
case $ENVIRONMENT in
    "dev")
        S3_BUCKET="petclinic-dev-frontend-dev"
        CLOUDFRONT_DISTRIBUTION="ECU0OIUYY0NGN"  # 실제 distribution ID로 변경 필요
        ;;
    "staging")
        S3_BUCKET="petclinic-staging-frontend"
        CLOUDFRONT_DISTRIBUTION="YOUR_STAGING_DISTRIBUTION_ID"
        ;;
    "prod")
        S3_BUCKET="petclinic-prod-frontend"
        CLOUDFRONT_DISTRIBUTION="YOUR_PROD_DISTRIBUTION_ID"
        ;;
    *)
        echo "❌ 잘못된 환경: $ENVIRONMENT"
        echo "사용법: $0 [dev|staging|prod]"
        exit 1
        ;;
esac

# 색상 출력 함수
print_info() {
    echo -e "\033[0;34mℹ️  $1\033[0m"
}

print_success() {
    echo -e "\033[0;32m✅ $1\033[0m"
}

print_error() {
    echo -e "\033[0;31m❌ $1\033[0m"
}

print_warning() {
    echo -e "\033[0;33m⚠️  $1\033[0m"
}

# 프론트엔드 파일 존재 확인
FRONTEND_DIR="spring-petclinic-api-gateway/src/main/resources/static"

if [ ! -d "$FRONTEND_DIR" ]; then
    print_error "프론트엔드 디렉토리를 찾을 수 없습니다: $FRONTEND_DIR"
    exit 1
fi

print_info "환경: $ENVIRONMENT"
print_info "S3 버킷: $S3_BUCKET"
print_info "CloudFront 배포: $CLOUDFRONT_DISTRIBUTION"
print_info "프론트엔드 디렉토리: $FRONTEND_DIR"

# 파일 개수 확인
FILE_COUNT=$(find "$FRONTEND_DIR" -type f | wc -l)
print_info "배포할 파일 개수: $FILE_COUNT"

# AWS CLI 확인
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI가 설치되어 있지 않습니다."
    exit 1
fi

# AWS 인증 확인
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS 인증이 필요합니다. 'aws configure' 또는 환경변수를 설정하세요."
    exit 1
fi

print_info "S3로 파일 동기화 중..."
if aws s3 sync "$FRONTEND_DIR/" "s3://$S3_BUCKET/" --delete --size-only; then
    print_success "S3 동기화 완료"
else
    print_error "S3 동기화 실패"
    exit 1
fi

# 업로드된 파일 수 확인
UPLOADED_COUNT=$(aws s3 ls "s3://$S3_BUCKET/" --recursive | wc -l)
print_info "S3에 업로드된 파일 수: $UPLOADED_COUNT"

# CloudFront 캐시 무효화
print_info "CloudFront 캐시 무효화 중..."
INVALIDATION_ID=$(aws cloudfront create-invalidation \
    --distribution-id "$CLOUDFRONT_DISTRIBUTION" \
    --paths "/*" \
    --query 'Invalidation.Id' \
    --output text)

if [ $? -eq 0 ]; then
    print_success "CloudFront 캐시 무효화 요청 완료 (ID: $INVALIDATION_ID)"
else
    print_error "CloudFront 캐시 무효화 실패"
    exit 1
fi

# CloudFront URL 가져오기
CF_DOMAIN=$(aws cloudfront get-distribution \
    --id "$CLOUDFRONT_DISTRIBUTION" \
    --query 'Distribution.DomainName' \
    --output text)

print_success "프론트엔드 배포 완료!"
echo ""
echo "📊 배포 요약:"
echo "  🌐 URL: https://$CF_DOMAIN"
echo "  📦 S3 버킷: $S3_BUCKET"
echo "  🚀 CloudFront 배포: $CLOUDFRONT_DISTRIBUTION"
echo "  📁 파일 수: $FILE_COUNT"
echo "  🔄 캐시 무효화 ID: $INVALIDATION_ID"
echo ""
print_info "캐시 무효화는 최대 15분 소요될 수 있습니다."