#!/bin/bash

# Lambda GenAI 챗봇 디버깅 스크립트
# Coco라는 반려동물 주인을 찾지 못하는 문제 진단

set -e

REGION="us-west-2"
LAMBDA_NAME="petclinic-dev-genai-function"

echo "=========================================="
echo "Lambda GenAI 챗봇 디버깅"
echo "=========================================="
echo ""

# 1. Lambda 함수 상태 확인
echo "1. Lambda 함수 상태 확인..."
echo "----------------------------------------"
aws lambda get-function --function-name $LAMBDA_NAME --region $REGION --query 'Configuration.{State:State,LastModified:LastModified,Runtime:Runtime,Timeout:Timeout,MemorySize:MemorySize}' --output table

# 2. Lambda 환경 변수 확인
echo ""
echo "2. Lambda 환경 변수 확인..."
echo "----------------------------------------"
aws lambda get-function-configuration --function-name $LAMBDA_NAME --region $REGION --query 'Environment.Variables' --output json | jq '.'

# 3. RDS 클러스터 Data API 활성화 확인
echo ""
echo "3. RDS 클러스터 Data API 활성화 확인..."
echo "----------------------------------------"
CLUSTER_ARN=$(aws rds describe-db-clusters --region $REGION --query 'DBClusters[?contains(DBClusterIdentifier, `petclinic-dev`)].DBClusterArn' --output text)
echo "Cluster ARN: $CLUSTER_ARN"

aws rds describe-db-clusters --region $REGION --query "DBClusters[?contains(DBClusterIdentifier, 'petclinic-dev')].{Identifier:DBClusterIdentifier,HttpEndpointEnabled:HttpEndpointEnabled,Status:Status}" --output table

# 4. Secrets Manager 확인
echo ""
echo "4. Secrets Manager 시크릿 확인..."
echo "----------------------------------------"
aws secretsmanager list-secrets --region $REGION --query "SecretList[?contains(Name, 'petclinic') || contains(Name, 'rds')].{Name:Name,ARN:ARN}" --output table

# 5. Lambda 테스트 실행 - Coco 질문
echo ""
echo "5. Lambda 테스트 실행 - 'Coco라는 반려동물을 키우는 사람은 누구야?'..."
echo "----------------------------------------"
cat > /tmp/lambda_test_payload.json <<EOF
{
  "httpMethod": "POST",
  "path": "/api/genai",
  "body": "{\"question\":\"Coco라는 반려동물을 키우는 사람은 누구야?\"}"
}
EOF

echo "테스트 페이로드:"
cat /tmp/lambda_test_payload.json | jq '.'

echo ""
echo "Lambda 실행 중..."
aws lambda invoke \
  --function-name $LAMBDA_NAME \
  --payload file:///tmp/lambda_test_payload.json \
  --region $REGION \
  /tmp/lambda_response.json \
  --log-type Tail \
  --query 'LogResult' \
  --output text | base64 -d

echo ""
echo "Lambda 응답:"
cat /tmp/lambda_response.json | jq '.'

# 6. Lambda 최근 로그 확인
echo ""
echo "6. Lambda 최근 로그 확인 (최근 10분)..."
echo "----------------------------------------"
echo "로그 스트림 가져오는 중..."

# 최근 로그 스트림 찾기
LATEST_STREAM=$(aws logs describe-log-streams \
  --log-group-name "/aws/lambda/$LAMBDA_NAME" \
  --region $REGION \
  --order-by LastEventTime \
  --descending \
  --max-items 1 \
  --query 'logStreams[0].logStreamName' \
  --output text)

if [ -n "$LATEST_STREAM" ] && [ "$LATEST_STREAM" != "None" ]; then
  echo "최신 로그 스트림: $LATEST_STREAM"
  echo ""
  echo "로그 내용:"
  aws logs get-log-events \
    --log-group-name "/aws/lambda/$LAMBDA_NAME" \
    --log-stream-name "$LATEST_STREAM" \
    --region $REGION \
    --limit 50 \
    --query 'events[*].message' \
    --output text | tail -30
else
  echo "❌ 로그 스트림을 찾을 수 없습니다."
fi

# 7. 실제 DB 데이터 확인 (Data API 사용)
echo ""
echo "7. 실제 DB 데이터 확인 (Coco가 있는지 확인)..."
echo "----------------------------------------"

# DB Secret ARN 가져오기
SECRET_ARN=$(aws secretsmanager list-secrets --region $REGION --query "SecretList[?contains(Name, 'petclinic') && contains(Name, 'rds')].ARN | [0]" --output text)

if [ -n "$SECRET_ARN" ] && [ "$SECRET_ARN" != "None" ]; then
  echo "Secret ARN: $SECRET_ARN"
  echo "Cluster ARN: $CLUSTER_ARN"
  echo ""
  echo "pets 테이블에서 'Coco' 검색 중..."
  
  aws rds-data execute-statement \
    --resource-arn "$CLUSTER_ARN" \
    --secret-arn "$SECRET_ARN" \
    --database "petclinic" \
    --sql "SELECT p.id, p.name, o.first_name, o.last_name FROM pets p JOIN owners o ON p.owner_id = o.id WHERE p.name LIKE '%Coco%'" \
    --region $REGION \
    --query 'records' \
    --output json | jq '.'
  
  echo ""
  echo "전체 pets 수 확인..."
  aws rds-data execute-statement \
    --resource-arn "$CLUSTER_ARN" \
    --secret-arn "$SECRET_ARN" \
    --database "petclinic" \
    --sql "SELECT COUNT(*) as total_pets FROM pets" \
    --region $REGION \
    --query 'records' \
    --output json | jq '.'
else
  echo "❌ Secret ARN을 찾을 수 없습니다."
fi

echo ""
echo "=========================================="
echo "디버깅 완료!"
echo "=========================================="
echo ""
echo "📊 결과 분석:"
echo "1. HttpEndpointEnabled가 true인지 확인"
echo "2. Lambda 환경 변수에 DB_CLUSTER_ARN, DB_SECRET_ARN이 올바른지 확인"
echo "3. Lambda 로그에서 'SQL 실행' 관련 로그 확인"
echo "4. DB에 실제로 'Coco'라는 pet이 있는지 확인"
echo ""
echo "💡 다음 단계:"
echo "- HttpEndpointEnabled가 false면: terraform apply로 Data API 활성화"
echo "- DB에 Coco가 없으면: 테스트 데이터 추가 필요"
echo "- Lambda 로그에 에러가 있으면: 해당 에러 메시지 확인"
