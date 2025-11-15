#!/bin/bash
set -e

# 서울 리전 ECR에 이미지 빌드 및 Push 스크립트
# Platform: linux/amd64 (ECS Fargate 호환)

# 설정
AWS_REGION="ap-northeast-2"
AWS_ACCOUNT_ID="897722691159"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
NAME_PREFIX="petclinic-seoul-dev"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}서울 리전 ECR 이미지 빌드 및 Push${NC}"
echo -e "${GREEN}========================================${NC}"

# ECR 로그인
echo -e "\n${YELLOW}[1/4] ECR 로그인 중...${NC}"
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}

if [ $? -ne 0 ]; then
    echo -e "${RED}ECR 로그인 실패!${NC}"
    exit 1
fi
echo -e "${GREEN}✓ ECR 로그인 성공${NC}"

# 서비스 목록
SERVICES=("customers" "vets" "visits" "admin")
SERVICE_DIRS=(
    "spring-petclinic-customers-service"
    "spring-petclinic-vets-service"
    "spring-petclinic-visits-service"
    "spring-petclinic-admin-server"
)

# Maven 빌드
echo -e "\n${YELLOW}[2/4] Maven 빌드 중...${NC}"
./mvnw clean package -DskipTests

if [ $? -ne 0 ]; then
    echo -e "${RED}Maven 빌드 실패!${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Maven 빌드 성공${NC}"

# 각 서비스별 이미지 빌드 및 Push
echo -e "\n${YELLOW}[3/4] Docker 이미지 빌드 및 Push 중...${NC}"

for i in "${!SERVICES[@]}"; do
    SERVICE="${SERVICES[$i]}"
    SERVICE_DIR="${SERVICE_DIRS[$i]}"
    IMAGE_NAME="${NAME_PREFIX}-${SERVICE}"
    IMAGE_URI="${ECR_REGISTRY}/${IMAGE_NAME}:latest"
    
    echo -e "\n${YELLOW}처리 중: ${SERVICE}${NC}"
    echo "  디렉토리: ${SERVICE_DIR}"
    echo "  이미지: ${IMAGE_URI}"
    
    # Docker 이미지 빌드 (AMD64 플랫폼 명시)
    echo "  - 빌드 중 (platform: linux/amd64)..."
    docker buildx build \
        --platform linux/amd64 \
        -t ${IMAGE_NAME}:latest \
        -f ${SERVICE_DIR}/Dockerfile \
        ${SERVICE_DIR}
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}  ✗ ${SERVICE} 빌드 실패!${NC}"
        continue
    fi
    
    # ECR에 태그
    echo "  - 태그 중..."
    docker tag ${IMAGE_NAME}:latest ${IMAGE_URI}
    
    # ECR에 Push
    echo "  - Push 중..."
    docker push ${IMAGE_URI}
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}  ✓ ${SERVICE} 완료!${NC}"
    else
        echo -e "${RED}  ✗ ${SERVICE} Push 실패!${NC}"
    fi
done

# 완료
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}[4/4] 모든 작업 완료!${NC}"
echo -e "${GREEN}========================================${NC}"

# 이미지 확인
echo -e "\n${YELLOW}ECR 이미지 목록:${NC}"
for SERVICE in "${SERVICES[@]}"; do
    IMAGE_NAME="${NAME_PREFIX}-${SERVICE}"
    echo -e "  ${ECR_REGISTRY}/${IMAGE_NAME}:latest"
done

echo -e "\n${YELLOW}다음 단계:${NC}"
echo "1. ECS 서비스 업데이트:"
echo "   cd terraform-seoul/layers/07-application"
echo "   terraform apply -var-file=../../envs/seoul.tfvars"
echo ""
echo "2. 또는 ECS 서비스 강제 재배포:"
echo "   aws ecs update-service --cluster petclinic-seoul-dev-cluster --service <service-name> --force-new-deployment --region ap-northeast-2"
