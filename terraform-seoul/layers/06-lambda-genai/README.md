# 06-lambda-genai 레이어 🤖

## 목차
- [개요](#개요)
- [AWS Lambda와 Bedrock 개념](#aws-lambda와-bedrock-개념)
- [GenAI ECS 서비스 대체](#genai-ecs-서비스-대체)
- [Lambda 함수 아키텍처](#lambda-함수-아키텍처)
- [RDS Data API 사용](#rds-data-api-사용)
- [코드 구조](#코드-구조)
- [배포 방법](#배포-방법)
- [문제 해결](#문제-해결)

---

## 개요

**06-lambda-genai 레이어**는 **AI 챗봇 기능**을 서버리스로 제공합니다.
기존 **GenAI ECS 서비스**를 **AWS Lambda + Bedrock**으로 대체했습니다.

### 이 레이어가 하는 일
- ✅ Lambda 함수 배포 (Python 3.11)
- ✅ Amazon Bedrock Claude 3 Sonnet 모델 사용
- ✅ RDS Data API로 Aurora MySQL 쿼리
- ✅ VPC 내부에서 실행 (데이터베이스 접근)
- ✅ **GenAI ECS 서비스 제거** - 서버리스 전환

### 다른 레이어와의 관계
```
01-network (VPC, Private Subnet)
    ↓
03-database (Aurora MySQL)
    ↓
06-lambda-genai (이 레이어) 🤖
    ↓
07-application (API Gateway 또는 ALB 연동)
```

---

## ⚠️ 서울 리전 (ap-northeast-2) 사용 시 중요 사항

### Bedrock Cross-Region Inference Profile 사용

서울 리전에서 Claude 모델을 사용하려면 **Cross-Region Inference Profile**을 사용해야 합니다.

#### 문제 상황
```
❌ 직접 모델 ID 사용 시 에러:
"Invocation of model ID anthropic.claude-3-sonnet-20240229-v1:0 with on-demand throughput isn't supported. 
Retry your request with the ID or ARN of an inference profile that contains this model."
```

#### 해결 방법
```python
# ❌ 잘못된 방법 (서울 리전에서 직접 호출)
model_id = 'anthropic.claude-3-5-sonnet-20240620-v1:0'

# ✅ 올바른 방법 (Cross-Region Inference Profile 사용)
model_id = 'us.anthropic.claude-3-5-sonnet-20240620-v1:0'
```

#### 자동 처리
람다 함수는 서울 리전을 자동으로 감지하여 적절한 모델 ID를 사용합니다:

```python
# 서울 리전에서는 Cross-Region Inference Profile 사용
region = os.getenv('AWS_REGION', 'ap-northeast-2')
if region == 'ap-northeast-2':
    model_id = 'us.anthropic.claude-3-5-sonnet-20240620-v1:0'
```

### 지원되는 모델 ID (서울 리전)

| 원본 모델 ID | 서울 리전 Cross-Region Profile |
|-------------|-------------------------------|
| anthropic.claude-3-5-sonnet-20240620-v1:0 | us.anthropic.claude-3-5-sonnet-20240620-v1:0 |
| anthropic.claude-3-sonnet-20240229-v1:0 | us.anthropic.claude-3-sonnet-20240229-v1:0 |
| anthropic.claude-3-haiku-20240307-v1:0 | us.anthropic.claude-3-haiku-20240307-v1:0 |

**참고**: Cross-Region Inference Profile을 사용하면 요청이 US 리전의 Bedrock으로 라우팅되지만, 람다 함수는 서울 리전에서 실행됩니다.

---

## AWS Lambda와 Bedrock 개념

### 1. AWS Lambda란? ⚡

**쉽게 설명**: Lambda는 **서버 없이 코드를 실행**하는 서비스입니다.

```
기존 ECS 방식:
- ECS Task 항상 실행 (24/7)
- 최소 CPU/메모리 할당 필요
- 요청 없어도 과금

Lambda 방식:
- 요청이 있을 때만 실행
- 실행 시간만큼만 과금 (ms 단위)
- 자동 스케일링 (동시 실행 수천 개)
```

**우리 프로젝트**: 
- Runtime: Python 3.11
- Memory: 512 MB
- Timeout: 60초
- VPC: Private App Subnet

---

### 2. Amazon Bedrock이란? 🧠

**쉽게 설명**: Bedrock은 **AWS의 AI 모델 서비스**입니다.

OpenAI, Anthropic, AI21 등의 LLM 모델을 API로 사용할 수 있습니다.

#### 지원 모델

| 모델 | 제공사 | 특징 | 우리 사용 |
|------|--------|------|----------|
| **Claude 3 Sonnet** | Anthropic | 균형잡힌 성능/속도 | ✅ 사용 |
| Claude 3 Opus | Anthropic | 최고 성능 | ❌ |
| Claude 3 Haiku | Anthropic | 빠른 속도 | ❌ |
| Titan | Amazon | AWS 자체 모델 | ❌ |
| Llama 2 | Meta | 오픈소스 | ❌ |

**우리 모델**: `anthropic.claude-3-sonnet-20240229-v1:0`

**선택 이유**:
- 한국어 지원 우수
- 가격/성능 균형
- 긴 컨텍스트 지원 (200K 토큰)

---

### 3. RDS Data API란? 🔌

**쉽게 설명**: RDS Data API는 **HTTP로 데이터베이스를 쿼리**하는 서비스입니다.

#### 기존 방식 (JDBC/MySQL Connector)

```python
# ❌ 기존: VPC 연결 필요, Connection Pool 관리
import pymysql

connection = pymysql.connect(
    host='aurora-endpoint',
    user='petclinic',
    password='password',
    database='petclinic',
    port=3306
)

cursor = connection.cursor()
cursor.execute("SELECT * FROM owners")
results = cursor.fetchall()
```

**문제점**:
- Lambda가 VPC에 있어야 함 (Cold Start 느림)
- Connection Pool 관리 어려움
- 동시 연결 수 제한

#### RDS Data API 방식

```python
# ✅ 새 방식: HTTP API, VPC 불필요 (하지만 우리는 VPC 사용)
import boto3

client = boto3.client('rds-data')

response = client.execute_statement(
    resourceArn='arn:aws:rds:...:cluster:petclinic',
    secretArn='arn:aws:secretsmanager:...:secret:...',
    database='petclinic',
    sql='SELECT * FROM owners'
)

results = response['records']
```

**장점**:
- Connection Pool 불필요
- 자동 연결 관리
- 동시 연결 수 무제한
- IAM 기반 인증

**우리 프로젝트**: RDS Data API 사용 (VPC 내에서 실행)

---

## GenAI ECS 서비스 대체

### 기존 아키텍처 (GenAI ECS)

```
┌────────────────────────────────────────────────┐
│  GenAI ECS Service                             │
│  - ECS Fargate 컨테이너                        │
│  - 항상 실행 (24/7)                            │
│  - CPU 256, Memory 512 MB                      │
│  - 비용: $20-30/월                             │
└────────────────────────────────────────────────┘
              ↓
        JDBC 연결
              ↓
┌────────────────────────────────────────────────┐
│  Aurora MySQL                                  │
│  - Connection Pool 관리 필요                   │
└────────────────────────────────────────────────┘
```

**문제점**:
- 요청이 없어도 항상 실행
- JDBC Connection Pool 관리
- ECS 리소스 점유

---

### 새 아키텍처 (Lambda + Bedrock)

```
┌────────────────────────────────────────────────┐
│  AWS Lambda (서버리스)                          │
│  - 요청 시에만 실행                             │
│  - Python 3.11, 512 MB                         │
│  - 비용: $0-5/월 (사용량 기반)                  │
└────────────────────────────────────────────────┘
         ↓                    ↓
    RDS Data API         Bedrock API
         ↓                    ↓
┌──────────────┐     ┌─────────────────┐
│ Aurora MySQL │     │ Claude 3 Sonnet │
└──────────────┘     └─────────────────┘
```

**장점**:
- ✅ **비용 절감** ($20-30/월 → $0-5/월)
- ✅ **자동 스케일링** (트래픽에 따라)
- ✅ **관리 간소화** (서버 없음)
- ✅ **RDS Data API** (연결 관리 자동)

---

## Lambda 함수 아키텍처

### 1. 전체 구조

```
┌─────────────────────────────────────────────────────────┐
│             Lambda Function                              │
│  ┌───────────────────────────────────────────────────┐  │
│  │  lambda_handler(event, context)                   │  │
│  │  - 입력: 사용자 질문                              │  │
│  │  - 출력: AI 응답                                  │  │
│  └──────────┬────────────────────────────────────────┘  │
│             │                                            │
│  ┌──────────▼────────────────────────────────────────┐  │
│  │  1. 데이터베이스 정보 조회 (RDS Data API)        │  │
│  │     - owners, pets, vets, visits 테이블           │  │
│  │     - SQL: SELECT * FROM ...                      │  │
│  └──────────┬────────────────────────────────────────┘  │
│             │                                            │
│  ┌──────────▼────────────────────────────────────────┐  │
│  │  2. 프롬프트 생성                                 │  │
│  │     - 시스템 프롬프트 + DB 데이터 + 사용자 질문  │  │
│  └──────────┬────────────────────────────────────────┘  │
│             │                                            │
│  ┌──────────▼────────────────────────────────────────┐  │
│  │  3. Bedrock API 호출 (Claude 3 Sonnet)          │  │
│  │     - 모델: anthropic.claude-3-sonnet            │  │
│  │     - 응답: AI 답변                               │  │
│  └──────────┬────────────────────────────────────────┘  │
│             │                                            │
│  ┌──────────▼────────────────────────────────────────┐  │
│  │  4. 응답 반환                                     │  │
│  │     - JSON 형식                                   │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

---

### 2. Lambda 함수 코드 구조

```python
# lambda_function.py

def lambda_handler(event, context):
    """Lambda 진입점"""
    try:
        # 1. 사용자 질문 파싱
        body = json.loads(event.get('body', '{}'))
        user_question = body.get('question', '')
        
        # 2. 데이터베이스 정보 조회
        db_context = get_database_context()
        
        # 3. Bedrock 호출
        ai_response = call_bedrock_api(user_question, db_context)
        
        # 4. 응답 반환
        return {
            'statusCode': 200,
            'body': json.dumps({
                'answer': ai_response
            })
        }
    except Exception as e:
        logger.error(f"오류 발생: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def get_database_context():
    """RDS Data API로 DB 조회"""
    client = boto3.client('rds-data')
    
    # Owners 조회
    owners = execute_sql(
        'petclinic',
        'SELECT id, first_name, last_name, city FROM owners'
    )
    
    # Pets 조회
    pets = execute_sql(
        'petclinic',
        'SELECT id, name, birth_date, owner_id FROM pets'
    )
    
    return {
        'owners': owners,
        'pets': pets
    }

def call_bedrock_api(question, db_context):
    """Bedrock Claude 3 호출"""
    bedrock = boto3.client('bedrock-runtime')
    
    prompt = f"""
    당신은 PetClinic 데이터베이스 전문가입니다.
    
    데이터베이스 정보:
    {json.dumps(db_context, ensure_ascii=False)}
    
    사용자 질문: {question}
    
    위 데이터를 바탕으로 질문에 답변해주세요.
    """
    
    response = bedrock.invoke_model(
        modelId='anthropic.claude-3-sonnet-20240229-v1:0',
        body=json.dumps({
            'anthropic_version': 'bedrock-2023-05-31',
            'messages': [{
                'role': 'user',
                'content': prompt
            }],
            'max_tokens': 1000,
            'temperature': 0.7
        })
    )
    
    result = json.loads(response['body'].read())
    return result['content'][0]['text']
```

---

### 3. 환경 변수

```hcl
# main.tf
environment {
  variables = {
    AWS_REGION       = "us-west-2"
    BEDROCK_MODEL_ID = "anthropic.claude-3-sonnet-20240229-v1:0"
    LOG_LEVEL        = "INFO"
    DB_CLUSTER_ARN   = "arn:aws:rds:...:cluster:petclinic-dev"
    DB_SECRET_ARN    = "arn:aws:secretsmanager:...:secret:..."
  }
}
```

---

## RDS Data API 사용

### 1. SQL 실행 예시

```python
def execute_sql(database: str, sql: str):
    """RDS Data API로 SQL 실행"""
    client = boto3.client('rds-data')
    
    response = client.execute_statement(
        resourceArn=os.getenv('DB_CLUSTER_ARN'),
        secretArn=os.getenv('DB_SECRET_ARN'),
        database=database,
        sql=sql,
        includeResultMetadata=True
    )
    
    # 결과 파싱
    records = response['records']
    columns = [col['name'] for col in response['columnMetadata']]
    
    results = []
    for record in records:
        row = {}
        for i, value in enumerate(record):
            # 값 타입에 따라 파싱
            if 'stringValue' in value:
                row[columns[i]] = value['stringValue']
            elif 'longValue' in value:
                row[columns[i]] = value['longValue']
            # ...
        results.append(row)
    
    return results
```

---

### 2. 지원되는 SQL 문

| SQL 타입 | 지원 | 예시 |
|---------|------|------|
| SELECT | ✅ | `SELECT * FROM owners` |
| INSERT | ✅ | `INSERT INTO pets VALUES (...)` |
| UPDATE | ✅ | `UPDATE owners SET ...` |
| DELETE | ✅ | `DELETE FROM visits WHERE ...` |
| Transaction | ✅ | `BEGIN; ... COMMIT;` |
| Stored Procedure | ❌ | 지원 안 함 |

---

### 3. IAM 권한

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "rds-data:ExecuteStatement",
        "rds-data:BatchExecuteStatement",
        "rds-data:BeginTransaction",
        "rds-data:CommitTransaction",
        "rds-data:RollbackTransaction"
      ],
      "Resource": "arn:aws:rds:us-west-2:*:cluster:petclinic-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:us-west-2:*:secret:petclinic-*"
    }
  ]
}
```

---

## 코드 구조

### 파일 구성

```
06-lambda-genai/
├── main.tf                  # Lambda 함수 및 IAM 역할
├── lambda_function.py       # Lambda 함수 코드 (Python)
├── data.tf                  # 01-network, 03-database 조회
├── variables.tf             # 변수 정의
├── outputs.tf               # 출력값
├── backend.tf               # Terraform 상태 저장
├── backend.config           # 백엔드 키 설정
├── terraform.tfvars         # 실제 값 입력
└── README.md                # 이 문서
```

---

### main.tf - Lambda 리소스

```hcl
# IAM 역할
resource "aws_iam_role" "lambda_execution_role" {
  name = "petclinic-lambda-genai-execution-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Bedrock 권한
resource "aws_iam_role_policy" "bedrock_invoke_policy" {
  name = "petclinic-lambda-bedrock-invoke-policy"
  role = aws_iam_role.lambda_execution_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ]
      Resource = "*"
    }]
  })
}

# RDS Data API 권한
resource "aws_iam_role_policy" "rds_data_api_policy" {
  name = "petclinic-lambda-rds-data-api-policy"
  role = aws_iam_role.lambda_execution_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds-data:ExecuteStatement",
          "rds-data:BatchExecuteStatement"
        ]
        Resource = "arn:aws:rds:us-west-2:*:cluster:petclinic-*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:us-west-2:*:secret:petclinic-*"
      }
    ]
  })
}

# Lambda 함수
resource "aws_lambda_function" "genai_function" {
  filename      = "lambda_function.zip"
  function_name = "petclinic-genai-function"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  timeout       = 60
  memory_size   = 512
  
  # VPC 설정 (Aurora 접근용)
  vpc_config {
    subnet_ids         = values(data.terraform_remote_state.network.outputs.private_app_subnet_ids)
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
  
  environment {
    variables = {
      AWS_REGION       = "us-west-2"
      BEDROCK_MODEL_ID = "anthropic.claude-3-sonnet-20240229-v1:0"
      LOG_LEVEL        = "INFO"
      DB_CLUSTER_ARN   = data.terraform_remote_state.database.outputs.cluster_arn
      DB_SECRET_ARN    = data.terraform_remote_state.database.outputs.master_user_secret_name
    }
  }
}

# Lambda 보안 그룹
resource "aws_security_group" "lambda_sg" {
  name   = "petclinic-lambda-genai-sg"
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id
}

# HTTPS Outbound (Bedrock API)
resource "aws_security_group_rule" "lambda_https_outbound" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.lambda_sg.id
}

# MySQL Outbound (Aurora)
resource "aws_security_group_rule" "lambda_mysql_outbound" {
  type              = "egress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  cidr_blocks       = ["10.0.0.0/16"]
  security_group_id = aws_security_group.lambda_sg.id
}
```

---

## 배포 방법

### 사전 요구사항

1. **01-network 레이어 배포 완료**
```bash
terraform output -state=../01-network/terraform.tfstate vpc_id
```

2. **03-database 레이어 배포 완료**
```bash
terraform output -state=../03-database/terraform.tfstate cluster_arn
```

3. **Bedrock 모델 액세스 활성화**
```bash
# AWS Console → Bedrock → Model access
# Claude 3 Sonnet 활성화 필요
```

---

### 배포 순서

#### 1단계: 작업 디렉토리 이동
```bash
cd terraform/layers/06-lambda-genai
```

#### 2단계: 변수 파일 확인
```bash
cat terraform.tfvars
```

예시:
```hcl
name_prefix = "petclinic"
environment = "dev"
aws_region  = "us-west-2"
aws_profile = "default"

# Bedrock 설정
bedrock_model_id = "anthropic.claude-3-sonnet-20240229-v1:0"

# 데이터베이스 설정
db_user = "petclinic"
db_name = "petclinic"
db_port = "3306"

# 백엔드
backend_bucket = "petclinic-tfstate-oregon-dev"

tags = {
  Project     = "petclinic"
  Environment = "dev"
  ManagedBy   = "terraform"
}
```

#### 3단계: Terraform 초기화
```bash
terraform init \
  -backend-config=../../backend.hcl \
  -backend-config=backend.config
```

#### 4단계: 실행 계획 확인
```bash
terraform plan -var-file=terraform.tfvars
```

**확인사항**:
- Lambda 함수 1개
- IAM 역할 1개
- IAM 정책 3개 (Bedrock, RDS Data API, VPC)
- 보안 그룹 1개

#### 5단계: 배포 실행
```bash
terraform apply -var-file=terraform.tfvars
```

**소요 시간**: 약 2-3분

#### 6단계: Lambda 함수 테스트
```bash
# Lambda 함수 호출
aws lambda invoke \
  --function-name petclinic-genai-function \
  --payload '{"body":"{\"question\":\"Coco라는 반려동물을 키우고 있는 사람은 누구야?\"}"}' \
  response.json

# 응답 확인
cat response.json
```

---

## 문제 해결

### 문제 1: Bedrock 모델 액세스 거부
```
AccessDeniedException: You don't have access to the model
```

**원인**: Bedrock 모델 액세스 미활성화

**해결**:
```bash
# AWS Console에서 활성화
1. Bedrock Console → Model access
2. "Manage model access" 클릭
3. "Anthropic - Claude 3 Sonnet" 체크
4. "Request model access" 클릭
5. 승인 대기 (수 분 소요)
```

---

### 문제 2: RDS Data API 실행 실패
```
BadRequestException: Database cluster is not enabled for Data API
```

**원인**: Aurora 클러스터에서 Data API 미활성화

**해결**:
```bash
# Aurora 클러스터 수정
aws rds modify-db-cluster \
  --db-cluster-identifier petclinic-dev-aurora-cluster \
  --enable-http-endpoint \
  --apply-immediately

# 상태 확인
aws rds describe-db-clusters \
  --db-cluster-identifier petclinic-dev-aurora-cluster \
  --query 'DBClusters[0].HttpEndpointEnabled'
```

---

### 문제 3: Lambda Timeout
```
Task timed out after 60.00 seconds
```

**원인**: Bedrock API 응답 느림 또는 DB 쿼리 지연

**해결**:
```bash
# Timeout 증가
terraform apply -var="lambda_timeout=120"

# 또는 main.tf 수정
resource "aws_lambda_function" "genai_function" {
  timeout = 120  # 60 → 120초
}
```

---

### 문제 4: Cold Start 느림
```
첫 요청: 10초 소요
이후 요청: 2초 소요
```

**원인**: VPC Lambda Cold Start

**해결책**:
1. **Provisioned Concurrency** (비용 증가)
```hcl
resource "aws_lambda_provisioned_concurrency_config" "this" {
  function_name = aws_lambda_function.genai_function.function_name
  provisioned_concurrent_executions = 1  # 항상 1개 Warm
}
```

2. **CloudWatch 예약 이벤트** (5분마다 호출)
```hcl
resource "aws_cloudwatch_event_rule" "keep_warm" {
  name = "lambda-keep-warm"
  schedule_expression = "rate(5 minutes)"
}
```

---

### 디버깅 명령어

```bash
# 1. Lambda 함수 정보
aws lambda get-function --function-name petclinic-genai-function

# 2. 최근 로그 확인
aws logs tail /aws/lambda/petclinic-genai-function --follow

# 3. Lambda 환경 변수 확인
aws lambda get-function-configuration \
  --function-name petclinic-genai-function \
  --query 'Environment.Variables'

# 4. IAM 역할 정책 확인
aws iam list-attached-role-policies \
  --role-name petclinic-lambda-genai-execution-role

# 5. Lambda 테스트 호출
aws lambda invoke \
  --function-name petclinic-genai-function \
  --log-type Tail \
  --payload '{"body":"{\"question\":\"안녕하세요\"}"}' \
  response.json

# 6. Bedrock 모델 목록
aws bedrock list-foundation-models \
  --region us-west-2 \
  --query 'modelSummaries[?contains(modelId, `claude`)].modelId'
```

---

## 비용 예상

### Lambda 비용

| 구성 요소 | 사양 | 월 비용 (USD) |
|----------|------|---------------|
| Lambda 요청 | 10,000회/월 | $0.20 |
| Lambda 실행 시간 | 512MB, 3초/요청 | $1.00 |
| VPC ENI | 1개 | $0 (무료) |
| CloudWatch Logs | 1GB | $0.50 |
| **Lambda 합계** | - | **$1.70** |

### Bedrock 비용

| 모델 | 입력 토큰 | 출력 토큰 | 월 비용 (USD) |
|------|----------|----------|---------------|
| Claude 3 Sonnet | $0.003/1K | $0.015/1K | $3-10 (사용량 기반) |

**예시 계산** (10,000회 호출):
- 입력: 500 토큰/요청 × 10,000 = 5M 토큰 → $15
- 출력: 200 토큰/요청 × 10,000 = 2M 토큰 → $30
- **합계**: **$45/월**

### 총 비용

| 항목 | 월 비용 (USD) |
|------|---------------|
| Lambda | $1.70 |
| Bedrock | $45 (사용량 기반) |
| **합계** | **$46.70** |

**비교** (기존 GenAI ECS):
- ECS: $30/월 (항상 실행)
- Lambda + Bedrock: $46.70/월 (사용량 기반)

**주의**: 트래픽이 적으면 Lambda가 저렴, 많으면 ECS가 저렴

---

## 다음 단계

Lambda GenAI 레이어 배포가 완료되면:

1. **07-application**: ECS 서비스 및 ALB 배포
2. **API Gateway 연동** (선택): Lambda를 HTTPS 엔드포인트로 노출

```bash
cd ../07-application
terraform init -backend-config=../../backend.hcl -backend-config=backend.config
terraform plan -var-file=terraform.tfvars
```

---

## 요약

### 핵심 개념 정리
- ✅ **Lambda**: 서버리스 함수 실행
- ✅ **Bedrock**: AWS AI 모델 서비스 (Claude 3 Sonnet)
- ✅ **RDS Data API**: HTTP로 DB 쿼리
- ✅ **VPC Lambda**: Private Subnet에서 실행

### 생성되는 리소스
- Lambda 함수: 1개 (Python 3.11, 512MB, 60초)
- IAM 역할: 1개
- 보안 그룹: 1개
- CloudWatch Log Group: 1개

### Lambda 환경 변수
```
AWS_REGION=us-west-2
BEDROCK_MODEL_ID=anthropic.claude-3-sonnet-20240229-v1:0
DB_CLUSTER_ARN=arn:aws:rds:...:cluster:petclinic-dev
DB_SECRET_ARN=arn:aws:secretsmanager:...:secret:...
```

### 비용
- Lambda: $1.70/월
- Bedrock: $45/월 (사용량 기반)
- **합계**: **$46.70/월**

---

**작성일**: 2025-11-09  
**작성자**: 황영현 
**버전**: 1.0
