#!/bin/bash

# Rate Limiting 모니터링 스크립트
# 이 스크립트는 API Gateway와 ALB의 Rate Limiting 상태를 모니터링합니다.

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 설정
REGION="us-west-2"
NAME_PREFIX="petclinic-dev"

echo -e "${BLUE}🔍 Rate Limiting 모니터링 시작...${NC}"
echo "=================================================="

# API Gateway 메트릭 확인
echo -e "\n${YELLOW}📊 API Gateway 메트릭 확인${NC}"
echo "--------------------------------------------------"

# API Gateway 이름 가져오기
API_GATEWAY_NAME=$(aws apigateway get-rest-apis \
  --region $REGION \
  --query "items[?name=='${NAME_PREFIX}-api'].name" \
  --output text)

if [ -n "$API_GATEWAY_NAME" ]; then
  echo -e "✅ API Gateway 발견: ${API_GATEWAY_NAME}"
  
  # 최근 1시간 동안의 요청 수
  CURRENT_TIME=$(date -u +%Y-%m-%dT%H:%M:%S)
  ONE_HOUR_AGO=$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S)
  
  echo "📈 최근 1시간 API Gateway 메트릭:"
  
  # 총 요청 수
  TOTAL_REQUESTS=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/ApiGateway \
    --metric-name Count \
    --dimensions Name=ApiName,Value=$API_GATEWAY_NAME Name=Stage,Value=dev \
    --start-time $ONE_HOUR_AGO \
    --end-time $CURRENT_TIME \
    --period 3600 \
    --statistics Sum \
    --region $REGION \
    --query 'Datapoints[0].Sum' \
    --output text 2>/dev/null || echo "0")
  
  echo "  - 총 요청 수: ${TOTAL_REQUESTS:-0}"
  
  # 4XX 에러
  ERROR_4XX=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/ApiGateway \
    --metric-name 4XXError \
    --dimensions Name=ApiName,Value=$API_GATEWAY_NAME Name=Stage,Value=dev \
    --start-time $ONE_HOUR_AGO \
    --end-time $CURRENT_TIME \
    --period 3600 \
    --statistics Sum \
    --region $REGION \
    --query 'Datapoints[0].Sum' \
    --output text 2>/dev/null || echo "0")
  
  echo "  - 4XX 에러: ${ERROR_4XX:-0}"
  
  # 평균 지연시간
  AVG_LATENCY=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/ApiGateway \
    --metric-name Latency \
    --dimensions Name=ApiName,Value=$API_GATEWAY_NAME Name=Stage,Value=dev \
    --start-time $ONE_HOUR_AGO \
    --end-time $CURRENT_TIME \
    --period 3600 \
    --statistics Average \
    --region $REGION \
    --query 'Datapoints[0].Average' \
    --output text 2>/dev/null || echo "0")
  
  echo "  - 평균 지연시간: ${AVG_LATENCY:-0}ms"
else
  echo -e "❌ API Gateway를 찾을 수 없습니다."
fi

# ALB 메트릭 확인
echo -e "\n${YELLOW}🔄 ALB 메트릭 확인${NC}"
echo "--------------------------------------------------"

# ALB ARN 가져오기
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --region $REGION \
  --query "LoadBalancers[?LoadBalancerName=='${NAME_PREFIX}-alb'].LoadBalancerArn" \
  --output text)

if [ -n "$ALB_ARN" ]; then
  ALB_NAME=$(echo $ALB_ARN | cut -d'/' -f2-4)
  echo -e "✅ ALB 발견: ${ALB_NAME}"
  
  echo "📈 최근 1시간 ALB 메트릭:"
  
  # 총 요청 수
  ALB_REQUESTS=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/ApplicationELB \
    --metric-name RequestCount \
    --dimensions Name=LoadBalancer,Value=$ALB_NAME \
    --start-time $ONE_HOUR_AGO \
    --end-time $CURRENT_TIME \
    --period 3600 \
    --statistics Sum \
    --region $REGION \
    --query 'Datapoints[0].Sum' \
    --output text 2>/dev/null || echo "0")
  
  echo "  - 총 요청 수: ${ALB_REQUESTS:-0}"
  
  # 타겟 응답 시간
  ALB_RESPONSE_TIME=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/ApplicationELB \
    --metric-name TargetResponseTime \
    --dimensions Name=LoadBalancer,Value=$ALB_NAME \
    --start-time $ONE_HOUR_AGO \
    --end-time $CURRENT_TIME \
    --period 3600 \
    --statistics Average \
    --region $REGION \
    --query 'Datapoints[0].Average' \
    --output text 2>/dev/null || echo "0")
  
  echo "  - 평균 응답 시간: ${ALB_RESPONSE_TIME:-0}초"
else
  echo -e "❌ ALB를 찾을 수 없습니다."
fi

# WAF 메트릭 확인
echo -e "\n${YELLOW}🛡️ WAF 메트릭 확인${NC}"
echo "--------------------------------------------------"

# WAF Web ACL 목록 가져오기
WAF_ACLS=$(aws wafv2 list-web-acls \
  --scope REGIONAL \
  --region $REGION \
  --query "WebACLs[?contains(Name, '${NAME_PREFIX}')].{Name:Name,Id:Id}" \
  --output text)

if [ -n "$WAF_ACLS" ]; then
  echo "$WAF_ACLS" | while read -r WAF_NAME WAF_ID; do
    echo -e "✅ WAF Web ACL 발견: ${WAF_NAME}"
    
    # 차단된 요청 수
    BLOCKED_REQUESTS=$(aws cloudwatch get-metric-statistics \
      --namespace AWS/WAFV2 \
      --metric-name BlockedRequests \
      --dimensions Name=WebACL,Value=$WAF_NAME Name=Region,Value=$REGION \
      --start-time $ONE_HOUR_AGO \
      --end-time $CURRENT_TIME \
      --period 3600 \
      --statistics Sum \
      --region $REGION \
      --query 'Datapoints[0].Sum' \
      --output text 2>/dev/null || echo "0")
    
    echo "  - 차단된 요청 수: ${BLOCKED_REQUESTS:-0}"
    
    # 허용된 요청 수
    ALLOWED_REQUESTS=$(aws cloudwatch get-metric-statistics \
      --namespace AWS/WAFV2 \
      --metric-name AllowedRequests \
      --dimensions Name=WebACL,Value=$WAF_NAME Name=Region,Value=$REGION \
      --start-time $ONE_HOUR_AGO \
      --end-time $CURRENT_TIME \
      --period 3600 \
      --statistics Sum \
      --region $REGION \
      --query 'Datapoints[0].Sum' \
      --output text 2>/dev/null || echo "0")
    
    echo "  - 허용된 요청 수: ${ALLOWED_REQUESTS:-0}"
  done
else
  echo -e "❌ WAF Web ACL을 찾을 수 없습니다."
fi

# CloudWatch 알람 상태 확인
echo -e "\n${YELLOW}🚨 CloudWatch 알람 상태${NC}"
echo "--------------------------------------------------"

ALARMS=$(aws cloudwatch describe-alarms \
  --alarm-name-prefix $NAME_PREFIX \
  --region $REGION \
  --query 'MetricAlarms[].{Name:AlarmName,State:StateValue,Reason:StateReason}' \
  --output table)

if [ -n "$ALARMS" ]; then
  echo "$ALARMS"
else
  echo -e "❌ 관련 CloudWatch 알람을 찾을 수 없습니다."
fi

echo -e "\n${GREEN}✅ Rate Limiting 모니터링 완료${NC}"
echo "=================================================="

# 권장사항 출력
echo -e "\n${BLUE}💡 권장사항:${NC}"
echo "1. 높은 4XX 에러율이 감지되면 Rate Limiting 설정을 검토하세요."
echo "2. 차단된 요청이 많다면 정당한 트래픽인지 확인하세요."
echo "3. 응답 시간이 높다면 백엔드 서비스 성능을 점검하세요."
echo "4. 정기적으로 이 스크립트를 실행하여 트래픽 패턴을 모니터링하세요."