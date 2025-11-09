# 🤖 Lambda GenAI 챗봇 문제 해결 가이드

> "Coco라는 반려동물을 키우고 있는 사람은 누구야?" → "죄송합니다. 제공된 데이터에는 정보가 없습니다."

## 🔍 문제 분석

Lambda GenAI 챗봇이 데이터베이스를 제대로 조회하지 못하고 있습니다.

### 가능한 원인

1. **RDS Data API가 비활성화**되어 있음
2. **Lambda 환경 변수** 설정 오류
3. **IAM 권한** 부족
4. **데이터베이스에 실제 데이터 없음**
5. **SQL 생성 로직** 문제

---

## 🛠️ 진단 및 해결 단계

### Step 1: 디버깅 스크립트 실행

```bash
# 스크립트에 실행 권한 부여
chmod +x debug_lambda_genai.sh

# 디버깅 스크립트 실행
./debug_lambda_genai.sh
```

**스크립트가 확인하는 항목:**
1. ✅ Lambda 함수 상태
2. ✅ Lambda 환경 변수
3. ✅ RDS Data API 활성화 상태
4. ✅ Secrets Manager 시크릿
5. ✅ Lambda 실행 테스트
6. ✅ Lambda 로그
7. ✅ 실제 DB 데이터

---

### Step 2: RDS Data API 활성화 확인

#### 문제 증상
```json
{
  "HttpEndpointEnabled": false
}
```

#### 해결 방법

**Option 1: Terraform으로 활성화**
```bash
cd terraform/layers/03-database
terraform apply

# null_resource.enable_data_api가 실행되는지 확인
```

**Option 2: AWS CLI로 수동 활성화**
```bash
# 클러스터 ARN 확인
CLUSTER_ARN=$(aws rds describe-db-clusters \
  --region us-west-2 \
  --query 'DBClusters[?contains(DBClusterIdentifier, `petclinic-dev`)].DBClusterArn' \
  --output text)

echo "Cluster ARN: $CLUSTER_ARN"

# Data API 활성화
aws rds modify-db-cluster \
  --db-cluster-identifier petclinic-dev-aurora-cluster \
  --enable-http-endpoint \
  --region us-west-2 \
  --apply-immediately

# 확인
aws rds describe-db-clusters \
  --db-cluster-identifier petclinic-dev-aurora-cluster \
  --region us-west-2 \
  --query 'DBClusters[0].HttpEndpointEnabled'
```

**주의**: Aurora Serverless v1은 즉시 지원, v2 및 Provisioned는 수동 활성화 필요

---

### Step 3: Lambda 환경 변수 확인

#### 올바른 설정 예시
```json
{
  "BEDROCK_MODEL_ID": "anthropic.claude-3-sonnet-20240229-v1:0",
  "LOG_LEVEL": "INFO",
  "DB_CLUSTER_ARN": "arn:aws:rds:us-west-2:123456789012:cluster:petclinic-dev-aurora-cluster",
  "DB_SECRET_ARN": "arn:aws:secretsmanager:us-west-2:123456789012:secret:rds!cluster-xxxxx"
}
```

#### 문제 확인
```bash
aws lambda get-function-configuration \
  --function-name petclinic-dev-genai-function \
  --region us-west-2 \
  --query 'Environment.Variables'
```

#### 수정 방법 (Terraform)
```bash
cd terraform/layers/06-lambda-genai
terraform apply
```

---

### Step 4: IAM 권한 확인

Lambda가 다음 권한을 가지고 있어야 합니다:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "rds-data:ExecuteStatement",
        "rds-data:BatchExecuteStatement"
      ],
      "Resource": "arn:aws:rds:us-west-2:*:cluster:petclinic-dev-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:us-west-2:*:secret:rds!cluster-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel"
      ],
      "Resource": "*"
    }
  ]
}
```

#### 확인 방법
```bash
# Lambda 실행 역할 확인
ROLE_NAME=$(aws lambda get-function \
  --function-name petclinic-dev-genai-function \
  --region us-west-2 \
  --query 'Configuration.Role' \
  --output text | cut -d'/' -f2)

echo "Role Name: $ROLE_NAME"

# 역할 정책 확인
aws iam list-attached-role-policies --role-name $ROLE_NAME
aws iam list-role-policies --role-name $ROLE_NAME
```

---

### Step 5: 데이터베이스 데이터 확인

#### RDS Data API로 직접 조회

```bash
# 클러스터 ARN 및 Secret ARN 확인
CLUSTER_ARN="arn:aws:rds:us-west-2:897722691159:cluster:petclinic-dev-aurora-cluster"
SECRET_ARN=$(aws secretsmanager list-secrets \
  --region us-west-2 \
  --query "SecretList[?contains(Name, 'petclinic') && contains(Name, 'rds')].ARN | [0]" \
  --output text)

echo "Secret ARN: $SECRET_ARN"

# Coco 검색
aws rds-data execute-statement \
  --resource-arn "$CLUSTER_ARN" \
  --secret-arn "$SECRET_ARN" \
  --database "petclinic" \
  --sql "SELECT p.id, p.name, o.first_name, o.last_name FROM pets p JOIN owners o ON p.owner_id = o.id WHERE p.name LIKE '%Coco%'" \
  --region us-west-2

# 전체 pets 확인
aws rds-data execute-statement \
  --resource-arn "$CLUSTER_ARN" \
  --secret-arn "$SECRET_ARN" \
  --database "petclinic" \
  --sql "SELECT * FROM pets LIMIT 10" \
  --region us-west-2
```

#### 데이터 없는 경우: 테스트 데이터 추가

```sql
-- Owner 추가
INSERT INTO owners (first_name, last_name, address, city, telephone) 
VALUES ('Jane', 'Doe', '123 Pet Street', 'Seattle', '555-1234');

-- Pet 추가
INSERT INTO pets (name, birth_date, type_id, owner_id) 
VALUES ('Coco', '2020-05-15', 1, LAST_INSERT_ID());
```

**RDS Data API로 실행:**
```bash
aws rds-data execute-statement \
  --resource-arn "$CLUSTER_ARN" \
  --secret-arn "$SECRET_ARN" \
  --database "petclinic" \
  --sql "INSERT INTO owners (first_name, last_name, address, city, telephone) VALUES ('Jane', 'Doe', '123 Pet Street', 'Seattle', '555-1234')" \
  --region us-west-2

# Owner ID 확인
OWNER_ID=$(aws rds-data execute-statement \
  --resource-arn "$CLUSTER_ARN" \
  --secret-arn "$SECRET_ARN" \
  --database "petclinic" \
  --sql "SELECT LAST_INSERT_ID() as id" \
  --region us-west-2 \
  --query 'records[0][0].longValue' \
  --output text)

echo "Owner ID: $OWNER_ID"

# Pet 추가
aws rds-data execute-statement \
  --resource-arn "$CLUSTER_ARN" \
  --secret-arn "$SECRET_ARN" \
  --database "petclinic" \
  --sql "INSERT INTO pets (name, birth_date, type_id, owner_id) VALUES ('Coco', '2020-05-15', 1, $OWNER_ID)" \
  --region us-west-2
```

---

### Step 6: Lambda 로그 상세 분석

#### CloudWatch Logs에서 확인할 내용

```bash
# 최근 30분 로그 확인
aws logs tail /aws/lambda/petclinic-dev-genai-function \
  --since 30m \
  --follow \
  --region us-west-2
```

#### 정상 동작 시 로그 패턴

```
INFO Lambda 함수 시작 - Request ID: xxx
INFO 질문 유형 분석: DATABASE_QUERY
INFO 데이터베이스 쿼리 시작: Coco라는 반려동물을 키우는 사람은 누구야?
INFO AI가 생성한 SQL: SELECT o.first_name, o.last_name FROM owners o JOIN pets p ON o.id = p.owner_id WHERE p.name LIKE '%Coco%'
INFO SQL 실행: SELECT o.first_name, o.last_name...
INFO 클러스터 ARN: arn:aws:rds:us-west-2:...
INFO 시크릿 ARN: arn:aws:secretsmanager:...
INFO SQL 실행 성공: 1개 결과
INFO 샘플 결과: [{'first_name': 'Jane', 'last_name': 'Doe'}]
INFO 컨텍스트 데이터 생성됨: 150자
INFO Bedrock AI 응답 생성 성공
```

#### 문제 발생 시 로그 패턴

```
ERROR SQL 실행 오류: HttpEndpoint is not enabled for DB cluster xxx
ERROR RDS Data API 클라이언트 초기화 실패: ...
ERROR 데이터베이스 조회 오류: AccessDeniedException
ERROR Bedrock AI 호출 실패: ...
```

---

### Step 7: Lambda 함수 재배포

코드를 수정한 경우:

```bash
cd terraform/layers/06-lambda-genai

# Lambda 함수 재배포
terraform apply

# 또는 강제 업데이트
terraform taint data.archive_file.lambda_zip
terraform taint aws_lambda_function.genai_function
terraform apply
```

---

## 🧪 테스트 방법

### 1. Lambda 콘솔에서 직접 테스트

**AWS Console → Lambda → petclinic-dev-genai-function → Test**

테스트 이벤트:
```json
{
  "httpMethod": "POST",
  "path": "/api/genai",
  "body": "{\"question\":\"Coco라는 반려동물을 키우는 사람은 누구야?\"}"
}
```

### 2. AWS CLI로 테스트

```bash
cat > test_payload.json <<EOF
{
  "httpMethod": "POST",
  "path": "/api/genai",
  "body": "{\"question\":\"Coco라는 반려동물을 키우는 사람은 누구야?\"}"
}
EOF

aws lambda invoke \
  --function-name petclinic-dev-genai-function \
  --payload file://test_payload.json \
  --region us-west-2 \
  response.json

cat response.json | jq '.body' -r | jq '.'
```

### 3. API Gateway를 통한 테스트

```bash
# API Gateway 엔드포인트 확인
APIGW_URL=$(aws apigatewayv2 get-apis \
  --region us-west-2 \
  --query "Items[?contains(Name, 'petclinic')].ApiEndpoint | [0]" \
  --output text)

echo "API Gateway URL: $APIGW_URL"

# POST 요청
curl -X POST "$APIGW_URL/api/genai" \
  -H "Content-Type: application/json" \
  -d '{"question":"Coco라는 반려동물을 키우는 사람은 누구야?"}'
```

---

## 🔧 일반적인 문제 및 해결책

### 문제 1: "HttpEndpoint is not enabled"

**원인**: RDS Data API가 비활성화

**해결**:
```bash
aws rds modify-db-cluster \
  --db-cluster-identifier petclinic-dev-aurora-cluster \
  --enable-http-endpoint \
  --region us-west-2 \
  --apply-immediately
```

### 문제 2: "AccessDeniedException"

**원인**: Lambda IAM 역할에 권한 부족

**해결**: Terraform으로 IAM 정책 재적용
```bash
cd terraform/layers/06-lambda-genai
terraform apply
```

### 문제 3: "DB_CLUSTER_ARN 환경 변수가 설정되지 않았습니다"

**원인**: Lambda 환경 변수 누락

**해결**: Terraform 재배포
```bash
cd terraform/layers/06-lambda-genai
terraform apply
```

### 문제 4: "데이터베이스 결과가 없습니다"

**원인**: DB에 실제 데이터 없음

**해결**: 테스트 데이터 추가 (Step 5 참조)

### 문제 5: SQL 생성 로직 문제

**원인**: AI가 잘못된 SQL 생성

**디버깅**:
1. Lambda 로그에서 "AI가 생성한 SQL" 확인
2. SQL을 직접 RDS Data API로 실행해서 결과 확인
3. 필요시 `lambda_function.py`의 프롬프트 수정

---

## 📊 성공 기준

모든 것이 정상 작동하면:

### 질문
```
Coco라는 반려동물을 키우는 사람은 누구야?
```

### 기대 응답
```json
{
  "question": "Coco라는 반려동물을 키우는 사람은 누구야?",
  "answer": "Coco라는 반려동물을 키우는 사람은 Jane Doe입니다.",
  "data_source": "aurora_rds_data_api",
  "question_type": "DATABASE_QUERY",
  "timestamp": "xxx"
}
```

### Lambda 로그
```
INFO 질문 유형 분석: DATABASE_QUERY
INFO SQL 실행 성공: 1개 결과
INFO 샘플 결과: [{'first_name': 'Jane', 'last_name': 'Doe'}]
```

---

## 🚀 추가 테스트 질문

```
✅ "휘권의 pet 이름이 뭐야?"
✅ "Maria의 pet name이 뭐야?"
✅ "George의 주소는 뭐야?"
✅ "Leo의 owner는 누구야?"
✅ "pet이 없는 owner는 누가 있는가?"
✅ "고양이를 키우는 사람은 누구야?"
```

---

## 📝 체크리스트

디버깅 시 다음 항목들을 순서대로 확인하세요:

- [ ] RDS Data API 활성화 확인 (`HttpEndpointEnabled: true`)
- [ ] Lambda 환경 변수 확인 (`DB_CLUSTER_ARN`, `DB_SECRET_ARN`)
- [ ] Lambda IAM 권한 확인 (`rds-data:ExecuteStatement`, `secretsmanager:GetSecretValue`)
- [ ] Secrets Manager 시크릿 존재 확인
- [ ] 데이터베이스에 테스트 데이터 존재 확인
- [ ] Lambda 로그에서 SQL 실행 로그 확인
- [ ] Lambda 로그에서 에러 메시지 확인
- [ ] AI가 생성한 SQL이 올바른지 확인
- [ ] 생성된 SQL을 직접 실행해서 결과 확인
- [ ] Lambda 함수 테스트 성공

---

**작성일**: 2024-11-08  
**버전**: 1.0  
**대상**: PetClinic Lambda GenAI 챗봇
