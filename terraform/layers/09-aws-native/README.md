# 09-aws-native 레이어 🔗

## 목차
- [개요](#개요)
- [AWS 네이티브 통합이란](#aws-네이티브-통합이란)
- [우리가 만드는 통합 구조](#우리가-만드는-통합-구조)
- [통합 요소 상세](#통합-요소-상세)
- [Well-Architected Framework 적용](#well-architected-framework-적용)
- [코드 구조](#코드-구조)
- [배포 방법](#배포-방법)
- [문제 해결](#문제-해결)

---

## 개요

**09-aws-native 레이어**는 AWS 네이티브 서비스들을 **통합하고 오케스트레이션**하는 레이어입니다.

### 이 레이어가 하는 일
- ✅ **API Gateway + Lambda GenAI 통합**: GenAI API 엔드포인트 생성
- ✅ **Lambda 권한 관리**: API Gateway가 Lambda 호출 허용
- ✅ **CloudWatch 통합 모니터링**: API Gateway + Lambda 알람
- ✅ **WAF 보호**: API Gateway에 WAF 연결 (선택)
- ✅ **Route 53 Health Check**: API 가용성 모니터링 (선택)
- ✅ **통합 대시보드**: 전체 서비스 상태 한눈에 보기

### 다른 레이어와의 관계
```
06-lambda-genai (Lambda 함수)
    ↓
08-api-gateway (API Gateway REST API)
    ↓
09-aws-native (이 레이어) 🔗
    ↓
    ├─→ API Gateway Resource 생성 (/genai)
    ├─→ Lambda 통합 (AWS_PROXY)
    ├─→ CloudWatch 알람 (4XX/5XX, Lambda 에러)
    ├─→ WAF 연결 (DDoS 방어)
    └─→ Route 53 Health Check
```

### 왜 별도 레이어로 분리했나요?

**이유**:
1. **단일 책임 원칙**: 각 레이어가 명확한 역할 담당
2. **의존성 관리**: 08-api-gateway와 06-lambda-genai를 연결
3. **Well-Architected Framework 적용**: 보안, 신뢰성, 성능 최적화 중앙 관리
4. **재사용성**: 다른 프로젝트에서도 통합 패턴 재사용 가능

**레이어 비교**:
| 레이어 | 역할 | 생성 리소스 |
|--------|------|------------|
| **06-lambda-genai** | Lambda 함수 생성 | Lambda, IAM Role |
| **08-api-gateway** | API Gateway 생성 | REST API, Stage, ALB 통합 |
| **09-aws-native** | 서비스 통합 | GenAI 엔드포인트, 알람, WAF |

---

## AWS 네이티브 통합이란

### 1. 서비스 통합 (Integration) 🔌

**쉽게 설명**: 여러 AWS 서비스를 **연결하여 하나의 완전한 기능**을 만드는 것

```
API Gateway (문지기)
    ↓
    통합 (Integration)
    ↓
Lambda (실제 작업자)
```

**통합 없이는**:
```
❌ API Gateway: "Lambda 어떻게 호출하지?"
❌ Lambda: "API Gateway가 호출해도 되나?"
❌ CloudWatch: "어떤 메트릭을 봐야 하지?"
```

**통합 후에는**:
```
✅ API Gateway → Lambda 권한 설정 완료
✅ Lambda ← API Gateway 호출 허용
✅ CloudWatch → 자동 메트릭 수집
✅ WAF → API Gateway 보호
```

---

### 2. 오케스트레이션 (Orchestration) 🎼

**쉽게 설명**: 여러 서비스가 **조화롭게 동작**하도록 조정

```
지휘자 (09-aws-native)
    ↓
    ├─→ 바이올린 (API Gateway)
    ├─→ 첼로 (Lambda)
    ├─→ 피아노 (CloudWatch)
    └─→ 드럼 (WAF)
    
→ 아름다운 하모니 (완전한 API 서비스)
```

---

### 3. AWS_PROXY 통합 타입 🚀

**AWS_PROXY**: Lambda를 API Gateway에 **가장 쉽게 연결**하는 방법

```hcl
integration_type = "AWS_PROXY"
uri              = lambda_function_invoke_arn
```

**동작 원리**:
```
1. Client 요청
   POST /genai
   Body: {"message": "고양이가 아파요"}

2. API Gateway (AWS_PROXY)
   → Lambda에게 전체 요청 그대로 전달
   {
     "httpMethod": "POST",
     "path": "/genai",
     "body": "{\"message\":\"고양이가 아파요\"}",
     "headers": {...}
   }

3. Lambda 처리
   → Bedrock 호출
   → 응답 생성

4. Lambda 응답 (JSON)
   {
     "statusCode": 200,
     "body": "{\"response\":\"증상을 알려주세요...\"}"
   }

5. API Gateway
   → Lambda 응답을 그대로 Client에 전달
```

**장점**:
- ✅ **간단한 설정**: Lambda 함수만 작성하면 됨
- ✅ **유연성**: Lambda에서 모든 HTTP 속성 제어
- ✅ **자동 변환**: JSON 자동 파싱

**단점**:
- ❌ Lambda에서 HTTP 응답 형식 직접 관리 필요

---

### 4. Lambda 권한 관리 🔑

**문제**: API Gateway가 Lambda를 호출하려면 **명시적 권한** 필요

```
API Gateway: "Lambda를 호출하고 싶어"
Lambda: "누구세요? 권한이 있나요?"
API Gateway: "권한 없음..."
Lambda: "거부!"
```

**해결**: `aws_lambda_permission` 리소스

```hcl
resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "petclinic-dev-genai"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${api_gateway_execution_arn}/*/*"
}
```

**의미**:
- `principal`: "apigateway.amazonaws.com이"
- `action`: "lambda:InvokeFunction 권한으로"
- `function_name`: "petclinic-dev-genai 함수를"
- `source_arn`: "이 API Gateway에서만 호출 가능"

**권한 후**:
```
API Gateway: "Lambda를 호출하고 싶어 (권한 제시)"
Lambda: "확인! API Gateway는 호출 가능해요"
API Gateway: "호출 성공!"
```

---

## 우리가 만드는 통합 구조

### 전체 아키텍처 다이어그램

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Internet                                    │
│  ┌──────────────┐                                                   │
│  │  Client      │                                                   │
│  └──────┬───────┘                                                   │
└─────────┼───────────────────────────────────────────────────────────┘
          │
          │ HTTPS
          ↓
┌─────────────────────────────────────────────────────────────────────┐
│  ╔═══════════════════════════════════════════════════════════════╗  │
│  ║  API Gateway (08-api-gateway 레이어에서 생성)                  ║  │
│  ║  https://abc123.execute-api.us-west-2.amazonaws.com/v1       ║  │
│  ╚═══════════════════════════════════════════════════════════════╝  │
│                          │                                           │
│                          ↓                                           │
│  ╔═══════════════════════════════════════════════════════════════╗  │
│  ║  09-aws-native 레이어 (이 레이어)                             ║  │
│  ║                                                                ║  │
│  ║  ┌──────────────────────────────────────────────────────┐    ║  │
│  ║  │  1. GenAI 리소스 생성                                 │    ║  │
│  ║  │     Resource: /api/genai                             │    ║  │
│  ║  │     Method: POST                                     │    ║  │
│  ║  │     Integration: AWS_PROXY → Lambda                  │    ║  │
│  ║  └──────────────────────────────────────────────────────┘    ║  │
│  ║                                                                ║  │
│  ║  ┌──────────────────────────────────────────────────────┐    ║  │
│  ║  │  2. Lambda 권한 부여                                  │    ║  │
│  ║  │     Principal: apigateway.amazonaws.com              │    ║  │
│  ║  │     Action: lambda:InvokeFunction                    │    ║  │
│  ║  └──────────────────────────────────────────────────────┘    ║  │
│  ║                                                                ║  │
│  ║  ┌──────────────────────────────────────────────────────┐    ║  │
│  ║  │  3. CloudWatch 알람                                   │    ║  │
│  ║  │     - API Gateway 4XX 에러 (임계값: 10)               │    ║  │
│  ║  │     - Lambda 에러 (임계값: 5)                         │    ║  │
│  ║  └──────────────────────────────────────────────────────┘    ║  │
│  ║                                                                ║  │
│  ║  ┌──────────────────────────────────────────────────────┐    ║  │
│  ║  │  4. WAF 연결 (선택)                                   │    ║  │
│  ║  │     - Rate Limiting: 5분간 2000 요청                  │    ║  │
│  ║  │     - DDoS 방어                                       │    ║  │
│  ║  └──────────────────────────────────────────────────────┘    ║  │
│  ║                                                                ║  │
│  ║  ┌──────────────────────────────────────────────────────┐    ║  │
│  ║  │  5. 통합 대시보드                                      │    ║  │
│  ║  │     - API Gateway 메트릭                              │    ║  │
│  ║  │     - Lambda 메트릭                                   │    ║  │
│  ║  │     - WAF 메트릭                                      │    ║  │
│  ║  └──────────────────────────────────────────────────────┘    ║  │
│  ╚═══════════════════════════════════════════════════════════════╝  │
│                          │                                           │
│                          ↓                                           │
│  ╔═══════════════════════════════════════════════════════════════╗  │
│  ║  Lambda Function (06-lambda-genai 레이어에서 생성)             ║  │
│  ║  - Function: petclinic-dev-genai                              ║  │
│  ║  - Runtime: Python 3.11                                       ║  │
│  ║  - Bedrock 통합                                                ║  │
│  ╚═══════════════════════════════════════════════════════════════╝  │
└─────────────────────────────────────────────────────────────────────┘

모니터링:
┌────────────────────────────┐
│  CloudWatch                │
│  - API Gateway 4XX         │
│  - Lambda Errors           │
│  - Integration Latency     │
│  - WAF Blocked Requests    │
└────────────────────────────┘
```

---

## 통합 요소 상세

### 1. GenAI API 리소스 생성 📝

**목적**: API Gateway에 `/api/genai` 엔드포인트 추가

```hcl
resource "aws_api_gateway_resource" "genai_resource" {
  rest_api_id = var.api_gateway_rest_api_id  # 08-api-gateway에서 생성된 API
  parent_id   = var.api_gateway_root_resource_id
  path_part   = "genai"
}
```

**결과**:
```
API Gateway
    ↓
    /api  (부모 리소스)
        ↓
        /genai  (이 레이어에서 생성)
```

**최종 경로**:
```
https://abc123.execute-api.us-west-2.amazonaws.com/v1/api/genai
```

---

### 2. POST 메서드 생성 🔨

```hcl
resource "aws_api_gateway_method" "genai_method" {
  rest_api_id   = var.api_gateway_rest_api_id
  resource_id   = aws_api_gateway_resource.genai_resource.id
  http_method   = "POST"
  authorization = "NONE"  # 인증 없음 (개발 환경)
  
  api_key_required = false  # API 키 불필요
}
```

**결과**:
```
POST /api/genai
Authorization: None
API Key: Not Required
```

---

### 3. Lambda 통합 설정 🔗

```hcl
resource "aws_api_gateway_integration" "genai_integration" {
  rest_api_id = var.api_gateway_rest_api_id
  resource_id = aws_api_gateway_resource.genai_resource.id
  http_method = "POST"
  
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_genai_invoke_arn
  
  timeout_milliseconds = 29000  # 29초 (최대)
}
```

**통합 타입 비교**:
| 타입 | 설명 | 사용 예시 |
|------|------|----------|
| **AWS_PROXY** | Lambda 프록시 통합 (권장) | GenAI, 간단한 API |
| **AWS** | Lambda 비프록시 통합 | 복잡한 요청/응답 변환 |
| **HTTP_PROXY** | HTTP 엔드포인트 프록시 | ALB, ECS 서비스 |
| **MOCK** | Mock 응답 | 테스트, 개발 |

---

### 4. Lambda 권한 부여 🔑

```hcl
resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "petclinic-dev-genai"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${api_gateway_execution_arn}/*/*"
}
```

**IAM 정책 효과**:
```json
{
  "Statement": [
    {
      "Sid": "AllowExecutionFromAPIGateway",
      "Effect": "Allow",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
      },
      "Action": "lambda:InvokeFunction",
      "Resource": "arn:aws:lambda:us-west-2:123456789012:function:petclinic-dev-genai",
      "Condition": {
        "ArnLike": {
          "AWS:SourceArn": "arn:aws:execute-api:us-west-2:123456789012:abc123/*/*/*"
        }
      }
    }
  ]
}
```

**보안 원칙** (Least Privilege):
- ✅ 특정 API Gateway만 허용 (`source_arn`)
- ✅ 특정 Lambda 함수만 호출 허용
- ❌ 모든 Lambda 함수 호출 불가
- ❌ 다른 API Gateway 호출 불가

---

### 5. CloudWatch 알람 📊

#### a) API Gateway 4XX 에러 알람
```hcl
resource "aws_cloudwatch_metric_alarm" "api_gateway_4xx_errors" {
  alarm_name          = "petclinic-api-gateway-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = 300  # 5분
  statistic           = "Sum"
  threshold           = 10   # 5분간 10개 이상
  
  dimensions = {
    ApiName = "petclinic-api"
    Stage   = "v1"
  }
}
```

**알람 발생 시나리오**:
```
1. 5분간 API Gateway 4XX 에러 발생
   - 400 Bad Request: 7개
   - 404 Not Found: 4개
   - 합계: 11개

2. 임계값 초과
   Threshold: 10
   Current: 11
   ✅ 알람 발생

3. SNS 알림 (설정 시)
   → Email, SMS, Slack 등
```

---

#### b) Lambda 에러 알람
```hcl
resource "aws_cloudwatch_metric_alarm" "lambda_genai_errors" {
  alarm_name          = "petclinic-lambda-genai-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5  # 5분간 5개 이상
  
  dimensions = {
    FunctionName = "petclinic-dev-genai"
  }
}
```

**Lambda 에러 종류**:
- `Timeout`: 실행 시간 초과 (60초)
- `OutOfMemory`: 메모리 부족 (512MB 초과)
- `Unhandled Exception`: 코드 예외 (Python error)

---

### 6. 통합 대시보드 📈

**목적**: 모든 서비스 메트릭을 한 화면에 표시

**대시보드 위젯**:
```
┌─────────────────────────────────────────────────────────┐
│  PetClinic AWS Native Integration Dashboard            │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────────────┐  ┌──────────────────┐           │
│  │ API Gateway      │  │ Lambda GenAI     │           │
│  │ - Requests: 1.2K │  │ - Invocations: 450│          │
│  │ - 4XX: 12        │  │ - Errors: 2       │          │
│  │ - 5XX: 1         │  │ - Duration: 2.3s  │          │
│  │ - Latency: 150ms │  │ - Memory: 380MB   │          │
│  └──────────────────┘  └──────────────────┘           │
│                                                         │
│  ┌──────────────────┐  ┌──────────────────┐           │
│  │ WAF              │  │ Integration      │           │
│  │ - Allowed: 2.8K  │  │ - Success: 99.5% │           │
│  │ - Blocked: 15    │  │ - Latency: 2.4s  │           │
│  └──────────────────┘  └──────────────────┘           │
└─────────────────────────────────────────────────────────┘
```

---

## Well-Architected Framework 적용

### 1. Operational Excellence (운영 우수성) 🎯

**적용**:
- ✅ **자동화된 배포**: Terraform으로 인프라 코드화
- ✅ **모니터링**: CloudWatch 알람 자동 설정
- ✅ **대시보드**: 통합 모니터링 대시보드

**예시**:
```hcl
# 모니터링 자동 활성화
enable_monitoring = true
create_integration_dashboard = true
```

---

### 2. Security (보안) 🔒

**적용**:
- ✅ **최소 권한**: Lambda 권한 제한 (`source_arn`)
- ✅ **API Key**: 프로덕션 환경에서 활성화 가능
- ✅ **WAF**: DDoS 방어 (선택)

**예시**:
```hcl
# 프로덕션 환경: API Key 필수
require_api_key = true

# WAF Rate Limiting
enable_waf_protection = true
waf_rate_limit = 2000  # 5분간 2000 요청
```

---

### 3. Reliability (신뢰성) 🛡️

**적용**:
- ✅ **Health Check**: Route 53 헬스 체크 (선택)
- ✅ **알람**: 4XX, 5XX, Lambda 에러 모니터링
- ✅ **Timeout 설정**: 29초 (API Gateway 최대)

**예시**:
```hcl
enable_health_checks = true

# 알람 임계값
api_gateway_4xx_threshold = 10
lambda_error_threshold = 5
```

---

### 4. Performance Efficiency (성능 효율성) ⚡

**적용**:
- ✅ **AWS_PROXY**: 최소 지연 시간
- ✅ **Lambda 메모리**: 512MB (Bedrock API 호출)
- ✅ **Timeout 최적화**: 29초

**예시**:
```hcl
genai_integration_timeout_ms = 29000
```

---

### 5. Cost Optimization (비용 최적화) 💰

**적용**:
- ✅ **서버리스**: Lambda는 사용한 만큼만 과금
- ✅ **자동 종료**: 개발 환경 야간 종료 (선택)
- ✅ **로그 보관 기간**: 14일 (비용 절감)

**예시**:
```hcl
auto_shutdown_enabled = true  # 개발 환경
log_retention_days = 14
```

---

### 6. Sustainability (지속 가능성) 🌱

**적용**:
- ✅ **서버리스**: 유휴 리소스 최소화
- ✅ **효율적인 코드**: Lambda Python 최적화

---

## 코드 구조

### 파일 구성

```
09-aws-native/
├── main.tf              # 통합 모듈 호출
├── data.tf              # Remote State 참조 (API Gateway, Lambda)
├── variables.tf         # 변수 정의
├── outputs.tf           # 출력값
├── backend.tf           # Terraform 상태 저장
├── backend.config       # 백엔드 키 설정
└── README.md            # 이 문서
```

---

### main.tf 주요 구성

```hcl
module "aws_native_integration" {
  source = "../../modules/aws-native-integration"
  
  # 기본 설정
  name_prefix = "petclinic"
  aws_region  = "us-west-2"
  
  # API Gateway 설정 (08-api-gateway에서 참조)
  api_gateway_rest_api_id = data.terraform_remote_state.api_gateway.outputs.api_gateway_id
  api_gateway_stage_name  = data.terraform_remote_state.api_gateway.outputs.api_gateway_stage_name
  
  # Lambda 설정 (06-lambda-genai에서 참조)
  lambda_genai_invoke_arn    = data.terraform_remote_state.lambda_genai.outputs.lambda_function_invoke_arn
  lambda_genai_function_name = data.terraform_remote_state.lambda_genai.outputs.lambda_function_name
  
  # 기능 활성화
  enable_genai_integration     = true
  enable_monitoring            = true
  create_integration_dashboard = true
  enable_waf_protection        = false  # 선택
  
  # 알람 임계값
  api_gateway_4xx_threshold = 10
  lambda_error_threshold    = 5
}
```

---

## 배포 방법

### 사전 요구사항

1. **06-lambda-genai 레이어 배포 완료**
```bash
cd ../06-lambda-genai
terraform output lambda_function_invoke_arn
# arn:aws:lambda:us-west-2:123456789012:function:petclinic-dev-genai
```

2. **08-api-gateway 레이어 배포 완료**
```bash
cd ../08-api-gateway
terraform output api_gateway_id
# abc123xyz
```

---

### 배포 순서

#### 1단계: 작업 디렉토리 이동
```bash
cd terraform/layers/09-aws-native
```

#### 2단계: 변수 파일 확인
```bash
cat terraform.tfvars
```

예시:
```hcl
# 공통 설정
name_prefix = "petclinic"
environment = "dev"
aws_region  = "us-west-2"
aws_profile = "default"

# 기능 활성화
enable_genai_integration     = true
enable_monitoring            = true
create_integration_dashboard = true
enable_health_checks         = false  # 선택
enable_waf_protection        = false  # 선택

# 보안 설정
require_api_key = false  # 개발 환경

# 성능 설정
genai_integration_timeout_ms = 29000

# 알람 임계값
api_gateway_4xx_threshold = 10
lambda_error_threshold    = 5

# WAF 설정 (enable_waf_protection = true 시)
waf_rate_limit = 2000

# 로깅
log_retention_days = 14

# 백엔드
tfstate_bucket_name = "petclinic-tfstate-oregon-dev"

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
- API Gateway Resource 1개 (/genai)
- API Gateway Method 1개 (POST)
- API Gateway Integration 1개 (AWS_PROXY)
- Lambda Permission 1개
- CloudWatch Alarm 2개 (4XX, Lambda 에러)
- CloudWatch Dashboard 1개

#### 5단계: 배포 실행
```bash
terraform apply -var-file=terraform.tfvars
```

**소요 시간**: 약 1-2분

#### 6단계: 배포 확인
```bash
# GenAI 리소스 ID 확인
terraform output genai_resource_id

# 통합 상태 확인
terraform output integration_status
```

---

### 배포 후 테스트

#### 1. GenAI API 테스트
```bash
API_URL=$(cd ../08-api-gateway && terraform output -raw api_gateway_invoke_url)

curl -X POST "${API_URL}/api/genai" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "What are the symptoms of a sick dog?",
    "history": []
  }'
```

**예상 응답**:
```json
{
  "response": "Common symptoms of a sick dog include...",
  "model": "anthropic.claude-3-sonnet-20240229-v1:0"
}
```

---

#### 2. 알람 확인
```bash
# API Gateway 4XX 알람
aws cloudwatch describe-alarms \
  --alarm-names petclinic-api-gateway-4xx-errors

# Lambda 에러 알람
aws cloudwatch describe-alarms \
  --alarm-names petclinic-lambda-genai-errors
```

---

#### 3. 대시보드 확인
```bash
# 대시보드 URL
echo "https://us-west-2.console.aws.amazon.com/cloudwatch/home?region=us-west-2#dashboards:name=petclinic-integration"
```

---

## 문제 해결

### 문제 1: Lambda 권한 오류
```
Error: API Gateway cannot invoke Lambda function
```

**원인**: Lambda 권한 설정 누락

**해결**:
```bash
# Lambda 권한 확인
aws lambda get-policy \
  --function-name petclinic-dev-genai \
  --query 'Policy' --output text | jq '.'

# Principal에 "apigateway.amazonaws.com" 있는지 확인
```

---

### 문제 2: 502 Bad Gateway
```
{
  "message": "Internal server error"
}
```

**디버깅**:

1. **Lambda 로그 확인**
```bash
aws logs tail /aws/lambda/petclinic-dev-genai --follow
```

2. **Lambda 테스트**
```bash
aws lambda invoke \
  --function-name petclinic-dev-genai \
  --payload '{"message":"test"}' \
  response.json

cat response.json
```

3. **API Gateway 로그 확인**
```bash
aws logs tail /aws/apigateway/petclinic-dev-api --follow
```

---

### 문제 3: 알람 미발생
```
CloudWatch 알람이 트리거되지 않음
```

**확인사항**:

1. **메트릭 확인**
```bash
# API Gateway 4XX 메트릭
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApiGateway \
  --metric-name 4XXError \
  --dimensions Name=ApiName,Value=petclinic-api Name=Stage,Value=v1 \
  --start-time 2025-11-09T00:00:00Z \
  --end-time 2025-11-09T23:59:59Z \
  --period 300 \
  --statistics Sum
```

2. **알람 상태**
```bash
aws cloudwatch describe-alarms \
  --alarm-names petclinic-api-gateway-4xx-errors \
  --query 'MetricAlarms[0].StateValue'
# OK, ALARM, INSUFFICIENT_DATA
```

3. **임계값 조정**
```hcl
api_gateway_4xx_threshold = 1  # 테스트용
```

---

### 디버깅 명령어

```bash
# API Gateway 리소스 확인
aws apigateway get-resources \
  --rest-api-id abc123 \
  --query 'items[?path==`/api/genai`]'

# Lambda 권한 확인
aws lambda get-policy \
  --function-name petclinic-dev-genai

# CloudWatch 알람 히스토리
aws cloudwatch describe-alarm-history \
  --alarm-name petclinic-api-gateway-4xx-errors \
  --max-records 10

# CloudWatch 대시보드 확인
aws cloudwatch list-dashboards \
  --query 'DashboardEntries[?DashboardName==`petclinic-integration`]'
```

---

## 비용 예상

### 주요 비용 요소

| 구성 요소 | 사양 | 월 비용 (USD) |
|----------|------|---------------|
| **API Gateway 호출** | 1백만 요청 (GenAI) | $3.50 |
| **Lambda 호출** | 450K 호출 (GenAI) | $0.10 |
| **Lambda 실행 시간** | 1GB-초당 $0.0000166667 | $0.50 |
| **CloudWatch 알람** | 2개 | $0.20 ($0.10/개) |
| **CloudWatch Dashboard** | 1개 | $3.00 |
| **CloudWatch Logs** | 1GB | $0.50 |
| **WAF (선택)** | Web ACL + Rules | $7.00 |
| **합계 (WAF 제외)** | - | **$7.80** |
| **합계 (WAF 포함)** | - | **$14.80** |

**비용 최적화 팁**:
- CloudWatch Dashboard 비활성화 (개발 환경): $3.00 절감
- WAF 비활성화 (개발 환경): $7.00 절감
- 로그 보관 기간 단축: 14일 → 7일

---

## 다음 단계

AWS Native Integration 레이어 배포가 완료되면:

1. **10-monitoring**: CloudWatch, X-Ray 통합
2. **11-frontend**: 프론트엔드 배포 (S3, CloudFront)
3. **12-notification**: EventBridge, SNS, SQS

```bash
cd ../10-monitoring
terraform init -backend-config=../../backend.hcl -backend-config=backend.config
terraform plan -var-file=terraform.tfvars
```

---

## 요약

### 핵심 개념 정리
- ✅ **통합 (Integration)**: API Gateway + Lambda 연결
- ✅ **AWS_PROXY**: Lambda 프록시 통합 (간편)
- ✅ **Lambda 권한**: API Gateway 호출 허용
- ✅ **CloudWatch 알람**: 4XX, Lambda 에러 모니터링
- ✅ **Well-Architected**: 보안, 신뢰성, 성능 최적화

### 생성되는 주요 리소스
- API Gateway Resource 1개 (/api/genai)
- API Gateway Method 1개 (POST)
- API Gateway Integration 1개 (AWS_PROXY)
- Lambda Permission 1개
- CloudWatch Alarm 2개
- CloudWatch Dashboard 1개 (선택)
- WAF Web ACL 1개 (선택)

### 통합 경로
```bash
POST /api/genai
    ↓
API Gateway (09-aws-native 통합)
    ↓
Lambda (petclinic-dev-genai)
    ↓
Bedrock (Claude 3 Sonnet)
```

### Well-Architected 원칙
```
✅ Operational Excellence: 자동화, 모니터링
✅ Security: 최소 권한, API Key, WAF
✅ Reliability: Health Check, 알람
✅ Performance: AWS_PROXY, Timeout 최적화
✅ Cost: 서버리스, 자동 종료
✅ Sustainability: 효율적 리소스 사용
```

---

**작성일**: 2025-11-09  
**작성자**: DevOps Team  
**버전**: 1.0
