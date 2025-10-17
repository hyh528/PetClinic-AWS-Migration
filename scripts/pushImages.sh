#!/bin/bash

# ==========================================
# AWS ECR에 마이크로서비스 이미지 푸시 스크립트
# ==========================================
# 실제 Spring Boot 애플리케이션 빌드 및 ECR 푸시
# Maven 빌드 + Docker 이미지 빌드 + ECR 푸시

set -e  # 에러 발생 시 스크립트 중단

# 환경 변수 설정 (기본값)
AWS_REGION="${AWS_REGION:-ap-southeast-2}"
VERSION="${VERSION:-latest}"
AWS_PROFILE="${AWS_PROFILE:-default}"
ECR_REGISTRY="${ECR_REGISTRY:-897722691159.dkr.ecr.ap-southeast-2.amazonaws.com}"

# 마이크로서비스 목록 (실제 배포할 서비스들)
SERVICES=(
    "spring-petclinic-visits-service"     # ECS Fargate에 배포
    "spring-petclinic-vets-service"       # ECS Fargate에 배포
    "spring-petclinic-customers-service"  # ECS Fargate에 배포
    "spring-petclinic-admin-server"       # ECS Fargate에 배포 + CloudWatch
)

echo "AWS ECR에 마이크로서비스 이미지 푸시 시작"
echo "리전: $AWS_REGION"
echo "버전: $VERSION"
echo "서비스 개수: ${#SERVICES[@]}"

# ==========================================
# 1. AWS ECR 로그인
# ==========================================
echo ""
echo "AWS ECR에 로그인 중..."
if ! aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY; then
    echo "❌ ECR 로그인 실패!"
    exit 1
fi
echo "✅ ECR 로그인 성공"

# ==========================================
# 3. 서비스별 이미지 빌드 및 푸시
# ==========================================
for service in "${SERVICES[@]}"; do
    echo ""
    echo "🔄 [$service] 이미지 빌드 중..."

    # 서비스 디렉토리로 이동
    SERVICE_DIR="$service"
    if [ ! -d "$SERVICE_DIR" ]; then
        echo "❌ $SERVICE_DIR 디렉토리가 존재하지 않습니다. 건너뜁니다."
        continue
    fi

    cd "$SERVICE_DIR"

    # Maven 빌드 (프로덕션 JAR 생성)
    echo "📦 [$service] Maven 빌드 중..."
    # 프로젝트 루트로 이동해서 Maven wrapper 실행
    pushd ../../../ > /dev/null
    if ! ./mvnw clean package -DskipTests -pl $service -am -q; then
        echo "❌ [$service] Maven 빌드 실패!"
        popd > /dev/null
        cd "$SERVICE_DIR"
        exit 1
    fi
    popd > /dev/null
    echo "✅ [$service] Maven 빌드 성공"

    # Dockerfile 존재 확인
    if [ ! -f "Dockerfile" ]; then
        echo "❌ $SERVICE_DIR/Dockerfile이 존재하지 않습니다. 건너뜁니다."
        cd ..
        continue
    fi

    # Docker 이미지 빌드
    if ! docker build -t $service .; then
        echo "❌ [$service] Docker 이미지 빌드 실패!"
        cd ..
        exit 1
    fi
    echo "✅ [$service] Docker 이미지 빌드 성공"

    # ECR 리포지토리 이름 매핑 (환경 변수 또는 기본값 사용)
    case $service in
        "spring-petclinic-customers-service")
            ECR_REPO_NAME="petclinic-customers"
            ;;
        "spring-petclinic-vets-service")
            ECR_REPO_NAME="petclinic-vets"
            ;;
        "spring-petclinic-visits-service")
            ECR_REPO_NAME="petclinic-visits"
            ;;
        "spring-petclinic-admin-server")
            ECR_REPO_NAME="petclinic-admin"
            ;;
        *)
            ECR_REPO_NAME="${service#spring-petclinic-}"
            ECR_REPO_NAME="${ECR_REPO_NAME%-service}"
            ;;
    esac

    # 태그 설정
    ECR_REPO_URL="$ECR_REGISTRY/$ECR_REPO_NAME"
    echo "🏷️  [$service] 태그 설정 중... ($ECR_REPO_NAME)"
    docker tag $service:latest $ECR_REPO_URL:$VERSION

    # ECR 푸시
    echo "📤 [$service] ECR에 푸시 중..."
    if ! docker push $ECR_REPO_URL:$VERSION; then
        echo "❌ [$service] ECR 푸시 실패!"
        cd ..
        exit 1
    fi
    echo "✅ [$service] ECR 푸시 성공"

    echo "📍 [$service] 완료: $ECR_REPO_URL:$VERSION"

    # 원래 디렉토리로 돌아가기
    cd ..
done

# ==========================================
# 4. 완료 요약
# ==========================================
echo ""
echo "🎉 모든 마이크로서비스 이미지 푸시 완료!"
echo ""
echo "📋 푸시된 이미지들:"
for service in "${SERVICES[@]}"; do
    case $service in
        "spring-petclinic-customers-service")
            ECR_REPO_NAME="petclinic-customers"
            ;;
        "spring-petclinic-vets-service")
            ECR_REPO_NAME="petclinic-vets"
            ;;
        "spring-petclinic-visits-service")
            ECR_REPO_NAME="petclinic-visits"
            ;;
        "spring-petclinic-admin-server")
            ECR_REPO_NAME="petclinic-admin"
            ;;
        *)
            ECR_REPO_NAME="${service#spring-petclinic-}"
            ECR_REPO_NAME="${ECR_REPO_NAME%-service}"
            ;;
    esac
    ECR_REPO_URL="$ECR_REGISTRY/$ECR_REPO_NAME"
    echo "  - $ECR_REPO_URL:$VERSION"
done

# Terraform에서 사용할 이미지 매핑 파일 생성
echo ""
echo "📄 Terraform용 이미지 매핑 파일 생성 중..."
cat > images.properties << EOF
customers-service=$ECR_REGISTRY/petclinic-customers@$VERSION
vets-service=$ECR_REGISTRY/petclinic-vets@$VERSION
visits-service=$ECR_REGISTRY/petclinic-visits@$VERSION
admin-server=$ECR_REGISTRY/petclinic-admin@$VERSION
EOF
echo "✅ images.properties 파일 생성 완료"

echo ""
echo " 다음 단계:"
echo "1. terraform output ecr_repository_url 으로 URL 확인"
echo "2. terraform output alb_dns_name 으로 ALB URL 확인"
echo "3. ECS 서비스를 재시작하여 새 이미지를 사용"
echo ""
echo "💡 추가 작업:"
echo "- 서비스별 ECR 리포지토리 생성 필요"
echo "- ECS 서비스에서 이미지 URL 업데이트"
