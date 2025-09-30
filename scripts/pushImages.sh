#!/bin/bash

# ==========================================
# AWS ECR로 마이크로서비스 이미지 푸시 스크립트
# ==========================================
# 석겸이의 Application 레이어에서 사용
# 기존 레거시 스크립트를 AWS ECR용으로 개선

set -e  # 에러 발생 시 스크립트 중단

# 환경 변수 설정 (기본값)
AWS_REGION="${AWS_REGION:-ap-northeast-2}"
VERSION="${VERSION:-latest}"

# 마이크로서비스 목록 (기존 레거시 서비스들)
SERVICES=(
    "spring-petclinic-config-server" # AWS parameter store로 대체 예정
    "spring-petclinic-discovery-server" # AWS Cloud Map으로 대체 예정
    "spring-petclinic-api-gateway" # AWS API Gateway로 대체 예정
    "spring-petclinic-visits-service" # ECS Fargate로 배포
    "spring-petclinic-vets-service" # ECS Fargate로 배포
    "spring-petclinic-customers-service" # ECS Fargate로 배포
    "spring-petclinic-admin-server" # ECS Fargate로 배포 + CloudWatch
)

echo "🚀 AWS ECR로 마이크로서비스 이미지 푸시 시작"
echo "📍 리전: $AWS_REGION"
echo "🏷️  버전: $VERSION"
echo "📦 서비스 개수: ${#SERVICES[@]}"

# ==========================================
# 1. AWS ECR 로그인
# ==========================================
echo ""
echo "🔐 AWS ECR에 로그인 중..."
if ! aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $(aws sts get-caller-identity --query Account --output text).dkr.ecr.$AWS_REGION.amazonaws.com; then
    echo "❌ ECR 로그인 실패!"
    exit 1
fi
echo "✅ ECR 로그인 성공"

# ==========================================
# 2. ECR 리포지토리 URL 구성
# ==========================================
ECR_REGISTRY=$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$AWS_REGION.amazonaws.com

# ==========================================
# 3. 각 서비스별 이미지 빌드 및 푸시
# ==========================================
for service in "${SERVICES[@]}"; do
    echo ""
    echo "🏗️  [$service] 이미지 빌드 중..."

    # Dockerfile 존재 확인
    if [ ! -f "Dockerfile.$service" ]; then
        echo "⚠️  Dockerfile.$service가 존재하지 않습니다. 건너뜁니다."
        continue
    fi

    # 이미지 빌드
    if ! docker build -t $service -f Dockerfile.$service .; then
        echo "❌ [$service] 이미지 빌드 실패!"
        exit 1
    fi
    echo "✅ [$service] 이미지 빌드 성공"

    # 태그 설정
    ECR_REPO_URL="$ECR_REGISTRY/$service"
    echo "🏷️  [$service] 태그 설정 중..."
    docker tag $service:latest $ECR_REPO_URL:$VERSION

    # ECR 푸시
    echo "📤 [$service] ECR로 푸시 중..."
    if ! docker push $ECR_REPO_URL:$VERSION; then
        echo "❌ [$service] ECR 푸시 실패!"
        exit 1
    fi
    echo "✅ [$service] ECR 푸시 성공"

    echo "📋 [$service] 완료: $ECR_REPO_URL:$VERSION"
done

# ==========================================
# 4. 완료 요약
# ==========================================
echo ""
echo "🎉 모든 마이크로서비스 이미지 푸시 완료!"
echo ""
echo "📋 푸시된 이미지들:"
for service in "${SERVICES[@]}"; do
    ECR_REPO_URL="$ECR_REGISTRY/$service"
    echo "  - $ECR_REPO_URL:$VERSION"
done

echo ""
echo "💡 다음 단계:"
echo "1. terraform output ecr_repository_url 로 URL 확인"
echo "2. terraform output alb_dns_name 로 ALB URL 확인"
echo "3. ECS 서비스가 자동으로 새 이미지 사용"
echo ""
echo "🔧 추가 작업:"
echo "- 각 서비스별 ECR 리포지토리 생성 필요"
echo "- ECS 태스크 정의에서 이미지 URL 업데이트"
