#!/bin/bash
# 스크립트: Admin 서버 연결 진단
# 목적: Admin 서버가 서비스들의 actuator에 접근하지 못하는 원인 파악

ADMIN_URL="http://petclinic-dev-alb-1211424104.us-west-2.elb.amazonaws.com/admin"
ALB_DNS="petclinic-dev-alb-1211424104.us-west-2.elb.amazonaws.com"

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}========================================"
echo -e "Admin 서버 연결 진단"
echo -e "========================================${NC}"
echo ""

# 1. 현재 등록된 인스턴스 확인
echo -e "${YELLOW}1. 현재 등록된 인스턴스 상태${NC}"
curl -s -H "Accept: application/json" "${ADMIN_URL}/instances" | jq -r '.[] | "\(.registration.name): \(.statusInfo.status) (ID: \(.id))"'
echo ""

# 2. 각 서비스의 헬스 엔드포인트 직접 테스트
echo -e "${YELLOW}2. 서비스 헬스 엔드포인트 직접 테스트 (외부에서)${NC}"
for service in customers vets visits; do
    echo -n "${service}-service: "
    health_url="http://${ALB_DNS}/api/${service}/actuator/health"
    response=$(curl -s -w "\n%{http_code}" "$health_url")
    http_code=$(echo "$response" | tail -n1)
    if [ "$http_code" -eq 200 ]; then
        echo -e "${GREEN}✓ OK (HTTP $http_code)${NC}"
    else
        echo -e "${RED}✗ FAILED (HTTP $http_code)${NC}"
    fi
done
echo ""

# 3. Admin 서버 자체 헬스 확인
echo -e "${YELLOW}3. Admin 서버 헬스 상태${NC}"
admin_health=$(curl -s "${ADMIN_URL}/actuator/health" | jq -r '.status')
if [ "$admin_health" == "UP" ]; then
    echo -e "${GREEN}✓ Admin Server: UP${NC}"
else
    echo -e "${RED}✗ Admin Server: $admin_health${NC}"
fi
echo ""

# 4. 특정 인스턴스의 상세 상태 확인
echo -e "${YELLOW}4. 등록된 인스턴스 상세 정보${NC}"
instance_ids=$(curl -s -H "Accept: application/json" "${ADMIN_URL}/instances" | jq -r '.[].id')
for id in $instance_ids; do
    echo -e "\n${CYAN}Instance ID: $id${NC}"
    curl -s -H "Accept: application/json" "${ADMIN_URL}/instances/$id" | jq '{
        name: .registration.name,
        status: .statusInfo.status,
        healthUrl: .registration.healthUrl,
        statusDetails: .statusInfo.details
    }'
done
echo ""

# 5. Admin 서버 환경 변수 확인
echo -e "${YELLOW}5. Admin 서버 환경 설정${NC}"
curl -s "${ADMIN_URL}/actuator/env" | jq '{
    "ALB_DNS_NAME": .propertySources[] | select(.name == "systemEnvironment") | .properties.ALB_DNS_NAME.value,
    "SPRING_PROFILES_ACTIVE": .propertySources[] | select(.name == "systemEnvironment") | .properties.SPRING_PROFILES_ACTIVE.value
}' 2>/dev/null || echo "환경 변수 조회 실패"
echo ""

# 6. 보안 그룹 및 네트워크 진단 제안
echo -e "${YELLOW}6. 문제 진단 요약${NC}"
echo -e "${CYAN}가능한 원인:${NC}"
echo "  1. Admin 서버가 ECS 내부에서 외부 ALB URL로 접근 시도 (Hairpin NAT 문제)"
echo "  2. ECS 보안 그룹에서 HTTPS(443) egress가 차단됨"
echo "  3. NAT Gateway 또는 Internet Gateway 설정 문제"
echo "  4. Admin 서버의 타임아웃 설정이 너무 짧음"
echo ""
echo -e "${CYAN}권장 해결 방법:${NC}"
echo "  ✓ Cloud Map(Service Discovery)를 사용하여 내부 DNS로 서비스 접근"
echo "  ✓ 또는 ECS 서비스 간 직접 통신 사용 (내부 IP)"
echo "  ✓ 보안 그룹 규칙에 HTTPS egress 추가"
echo ""
