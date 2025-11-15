#!/bin/bash
set -e

# 서울 리전 ECR 리포지토리의 Tag Immutability 비활성화 스크립트

AWS_REGION="ap-northeast-2"
NAME_PREFIX="petclinic-seoul-dev"

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}ECR Tag Immutability 비활성화${NC}"
echo -e "${GREEN}========================================${NC}"

SERVICES=("customers" "vets" "visits" "admin")

for SERVICE in "${SERVICES[@]}"; do
    REPO_NAME="${NAME_PREFIX}-${SERVICE}"
    echo -e "\n${YELLOW}처리 중: ${REPO_NAME}${NC}"
    
    aws ecr put-image-tag-mutability \
        --repository-name "$REPO_NAME" \
        --image-tag-mutability MUTABLE \
        --region "$AWS_REGION"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}  ✓ ${REPO_NAME} - Tag Immutability 비활성화 완료${NC}"
    else
        echo -e "${RED}  ✗ ${REPO_NAME} - 실패${NC}"
    fi
done

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}모든 작업 완료!${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\n${YELLOW}이제 이미지를 push할 수 있습니다:${NC}"
echo "  ./scripts/push-images-seoul.sh"
