#!/bin/bash

# =============================================================================
# Application Layer 배포 스크립트
# =============================================================================
# 목적: PetClinic 애플리케이션 레이어를 자동으로 배포
# 사용법: ./deploy-application.sh [환경] [이미지 태그]
# 예시: ./deploy-application.sh dev develop-2025-10-18-d56286b

set -e

# 환경 변수 설정
ENVIRONMENT=${1:-"dev"}
IMAGE_TAG=${2:-"latest"}

if [ "$ENVIRONMENT" != "dev" ] && [ "$ENVIRONMENT" != "staging" ] && [ "$ENVIRONMENT" != "prod" ]; then
    echo "❌ 잘못된 환경: $ENVIRONMENT. 사용 가능한 환경: dev, staging, prod"
    exit 1
fi

echo "🚀 PetClinic Application Layer 배포 시작"
echo "환경: $ENVIRONMENT"
echo "이미지 태그: $IMAGE_TAG"

# ECR 리포지토리 정보 가져오기
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile petclinic-dev)
REGION="ap-southeast-2"

if [ -z "$ACCOUNT_ID" ] || [ -z "$REGION" ]; then
    echo "❌ AWS 프로필 설정을 확인해주세요"
    exit 1
fi

echo "AWS 계정: $ACCOUNT_ID"
echo "리전: $REGION"

# SHA256 다이제스트 조회 및 서비스 이미지 맵 생성
echo "🔍 SHA256 다이제스트 조회 중..."

CUSTOMERS_DIGEST=$(aws ecr describe-images --repository-name "petclinic-$ENVIRONMENT-customers" --image-ids imageTag=$IMAGE_TAG --region $REGION --profile "petclinic-$ENVIRONMENT" --query 'imageDetails[0].imageDigest' --output text)
VETS_DIGEST=$(aws ecr describe-images --repository-name "petclinic-$ENVIRONMENT-vets" --image-ids imageTag=$IMAGE_TAG --region $REGION --profile "petclinic-$ENVIRONMENT" --query 'imageDetails[0].imageDigest' --output text)
VISITS_DIGEST=$(aws ecr describe-images --repository-name "petclinic-$ENVIRONMENT-visits" --image-ids imageTag=$IMAGE_TAG --region $REGION --profile "petclinic-$ENVIRONMENT" --query 'imageDetails[0].imageDigest' --output text)
ADMIN_DIGEST=$(aws ecr describe-images --repository-name "petclinic-$ENVIRONMENT-admin" --image-ids imageTag=$IMAGE_TAG --region $REGION --profile "petclinic-$ENVIRONMENT" --query 'imageDetails[0].imageDigest' --output text)

CUSTOMERS_IMAGE="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/petclinic-$ENVIRONMENT-customers@$CUSTOMERS_DIGEST"
VETS_IMAGE="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/petclinic-$ENVIRONMENT-vets@$VETS_DIGEST"
VISITS_IMAGE="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/petclinic-$ENVIRONMENT-visits@$VISITS_DIGEST"
ADMIN_IMAGE="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/petclinic-$ENVIRONMENT-admin@$ADMIN_DIGEST"

SERVICE_IMAGE_MAP="customers=\"$CUSTOMERS_IMAGE\",vets=\"$VETS_IMAGE\",visits=\"$VISITS_IMAGE\",admin=\"$ADMIN_IMAGE\""

echo "📦 서비스 이미지 맵:"
echo "  customers: $CUSTOMERS_IMAGE"
echo "  vets: $VETS_IMAGE"
echo "  visits: $VISITS_IMAGE"
echo "  admin: $ADMIN_IMAGE"

# Terraform 작업 디렉터리로 이동
cd "$(dirname "$0")/../layers/07-application"

# 동적 terraform.tfvars 파일 생성
echo "📝 동적 terraform.tfvars 파일 생성 중..."
cat > terraform.tfvars << EOF
# 동적으로 생성된 서비스 이미지 맵
service_image_map = {
  customers = "$CUSTOMERS_IMAGE"
  vets      = "$VETS_IMAGE"
  visits    = "$VISITS_IMAGE"
  admin     = "$ADMIN_IMAGE"
}
EOF

echo "✅ terraform.tfvars 파일 생성 완료"

# Terraform 초기화
echo "🔧 Terraform 초기화 중..."
terraform init -backend-config="../../backend.hcl" -backend-config="backend.config" -reconfigure

# Terraform 계획
echo "📋 배포 계획 확인 중..."
terraform plan \
    -var-file="../../envs/${ENVIRONMENT}.tfvars" \
    -var-file="terraform.tfvars" \
    -out=tfplan

# Terraform 적용
echo "⚡ 배포 실행 중..."
terraform apply tfplan

# 배포 상태 확인
echo "✅ 배포 완료! 서비스 상태 확인 중..."
aws ecs describe-services \
    --cluster "petclinic-${ENVIRONMENT}-cluster" \
    --services "petclinic-${ENVIRONMENT}-customers" "petclinic-${ENVIRONMENT}-vets" "petclinic-${ENVIRONMENT}-visits" "petclinic-${ENVIRONMENT}-admin" \
    --region "$REGION" \
    --profile "petclinic-$ENVIRONMENT" \
    --query 'services[].[serviceName,runningCount,desiredCount,status]' \
    --output table

echo "🎉 Application Layer 배포 완료!"
echo "ALB URL: $(terraform output -raw alb_dns_name)"
echo "헬스체크: $(terraform output -raw health_check_url)"