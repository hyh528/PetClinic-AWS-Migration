#!/bin/bash
# 잘못된 healthUrl을 가진 인스턴스 삭제 스크립트

ADMIN_URL="http://petclinic-dev-alb-1211424104.us-west-2.elb.amazonaws.com/admin"

echo "🔍 잘못된 인스턴스 검색 중..."

# 잘못된 URL 패턴: /actuator/health (without /api/{service}/)
wrong_instances=$(curl -s -H "Accept: application/json" "${ADMIN_URL}/instances" | \
  jq -r '.[] | select(.registration.healthUrl | test(".*/actuator/health$")) | .id')

if [ -z "$wrong_instances" ]; then
  echo "✅ 잘못된 인스턴스가 없습니다!"
  exit 0
fi

echo "🗑️  잘못된 인스턴스 삭제 중..."
for id in $wrong_instances; do
  echo "  Deleting: $id"
  curl -s -X DELETE "${ADMIN_URL}/instances/$id"
done

echo ""
echo "✅ 정리 완료!"
echo ""
echo "📊 남은 인스턴스 상태:"
curl -s -H "Accept: application/json" "${ADMIN_URL}/instances" | \
  jq -r '.[] | "\(.registration.name): \(.statusInfo.status)"'
