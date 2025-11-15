#!/bin/bash

# 서울 리전 ECS 서비스 로그 확인 스크립트

AWS_REGION="ap-northeast-2"
NAME_PREFIX="petclinic-seoul-dev"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}ECS 서비스 로그 확인${NC}"
echo -e "${GREEN}========================================${NC}"

SERVICES=("customers" "vets" "visits" "admin")

for SERVICE in "${SERVICES[@]}"; do
    LOG_GROUP="/ecs/${NAME_PREFIX}-${SERVICE}"
    
    echo -e "\n${BLUE}=== ${SERVICE} 서비스 로그 ===${NC}"
    echo "로그 그룹: ${LOG_GROUP}"
    
    # 로그 그룹 존재 확인
    if aws logs describe-log-groups \
        --log-group-name-prefix "$LOG_GROUP" \
        --region "$AWS_REGION" \
        --query 'logGroups[0].logGroupName' \
        --output text 2>/dev/null | grep -q "$LOG_GROUP"; then
        
        echo -e "${GREEN}✓ 로그 그룹 존재${NC}"
        
        # 최근 10분간 로그 출력
        echo -e "\n${YELLOW}최근 로그 (10분):${NC}"
        aws logs tail "$LOG_GROUP" \
            --since 10m \
            --region "$AWS_REGION" \
            --format short 2>/dev/null | tail -50
        
        # 에러 패턴 검색
        echo -e "\n${YELLOW}에러 검색:${NC}"
        aws logs tail "$LOG_GROUP" \
            --since 30m \
            --region "$AWS_REGION" \
            --format short 2>/dev/null | \
            grep -iE "error|exception|failed|fatal|refused|denied" | \
            tail -20
    else
        echo -e "${RED}✗ 로그 그룹을 찾을 수 없습니다${NC}"
    fi
    
    echo -e "\n${YELLOW}----------------------------------------${NC}"
done

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}로그 확인 완료${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\n${YELLOW}실시간 로그 모니터링:${NC}"
echo "  aws logs tail /ecs/${NAME_PREFIX}-vets --follow --region ${AWS_REGION}"
