# 08-api-gateway 레이어 🚪

## 목차
- [개요](#개요)
- [AWS API Gateway 기초 개념](#aws-api-gateway-기초-개념)
- [우리가 만드는 API Gateway 구조](#우리가-만드는-api-gateway-구조)
- [요청 흐름 및 라우팅](#요청-흐름-및-라우팅)
- [보안 및 Rate Limiting](#보안-및-rate-limiting)
- [코드 구조](#코드-구조)
- [배포 방법](#배포-방법)
- [문제 해결](#문제-해결)

---

## 개요

**08-api-gateway 레이어**는 Spring Cloud Gateway를 **AWS API Gateway로 대체**하는 레이어입니다.

### 이 레이어가 하는 일
- ✅ **Spring Cloud Gateway 제거**: ECS 기반 Gateway 서비스 불필요
- ✅ AWS API Gateway REST API 생성
- ✅ ALB 통합 (customers, vets, visits, admin 서비스)
- ✅ Lambda 통합 (GenAI 챗봇 서비스)
- ✅ WAF 통합 (DDoS 방어, Rate Limiting)
- ✅ CloudWatch 모니터링 및 알람
- ✅ CORS 설정

### 다른 레이어와의 관계
```
06-lambda-genai (Lambda 함수)
    ↓
07-application (ALB + ECS 서비스)
    ↓
08-api-gateway (이 레이어) 🚪
    ↓
    ├─→ /api/customers/* → ALB → customers-service (8080)
    ├─→ /api/vets/*      → ALB → vets-service (8080)
    ├─→ /api/visits/*    → ALB → visits-service (8080)
    ├─→ /admin/*         → ALB → admin-server (9090)
    └─→ /api/genai/*     → Lambda (GenAI)
```

### 왜 Spring Cloud Gateway를 제거했나요?

**기존 아키텍처 (Spring Cloud Gateway 사용)**:
```
Client → ALB → Spring Cloud Gateway (ECS)
                    ↓
                    ├─→ customers-service
                    ├─→ vets-service
                    └─→ visits-service
```

**문제점**:
- ❌ Gateway 서비스 자체가 ECS에서 실행 (비용, 관리 부담)
- ❌ Gateway 장애 시 전체 서비스 중단
- ❌ Auto Scaling 별도 설정 필요
- ❌ 모니터링, 로깅 직접 구현 필요

**새 아키텍처 (AWS API Gateway 사용)**:
```
Client → API Gateway → ALB → Microservices
                    └─→ Lambda (GenAI)
```

**장점**:
- ✅ **서버리스**: ECS 비용 절감
- ✅ **고가용성**: AWS 관리형 서비스 (99.95% SLA)
- ✅ **Auto Scaling**: 자동 처리
- ✅ **WAF 통합**: 보안 강화
- ✅ **CloudWatch 자동 통합**: 모니터링 간편

---

## AWS API Gateway 기초 개념

### 1. API Gateway란? 🌐

**쉽게 설명**: API Gateway는 **백엔드 서비스 앞단의 문지기**입니다.

```
클라이언트 → API Gateway → 백엔드 서비스
              (문지기)      (실제 작업자)
```

**API Gateway 역할**:
1. **라우팅**: 요청을 올바른 서비스로 전달
2. **인증/인가**: API Key, JWT 검증
3. **Rate Limiting**: 과도한 요청 차단
4. **캐싱**: 자주 요청되는 데이터 캐시
5. **모니터링**: 요청 수, 지연시간 추적

---

### 2. REST API vs HTTP API 🔍

AWS API Gateway는 2가지 타입 제공:

| 구분 | REST API | HTTP API |
|------|----------|----------|
| **기능** | 풍부 (WAF, Usage Plan 등) | 단순 (라우팅만) |
| **비용** | $3.50/백만 요청 | $1.00/백만 요청 |
| **지연시간** | 약간 높음 | 낮음 |
| **WAF 통합** | ✅ 지원 | ❌ 미지원 |
| **사용량 계획** | ✅ 지원 | ❌ 미지원 |
| **캐싱** | ✅ 지원 | ❌ 미지원 |

**우리 프로젝트**: **REST API** 사용 (WAF 보안 필요)

---

### 3. API Gateway 구성 요소 🧱

#### a) REST API
```
API Gateway REST API
    └─ Stage (v1, v2, prod 등)
        └─ Resource (/api/customers, /api/vets 등)
            └─ Method (GET, POST, PUT, DELETE)
                └─ Integration (ALB, Lambda 등)
```

#### b) Stage (스테이지)
**용도**: 배포 환경 분리 (개발, 스테이징, 프로덕션)

```
API Gateway
    ├─ Stage: dev   → https://api-id.execute-api.us-west-2.amazonaws.com/dev
    ├─ Stage: stage → https://api-id.execute-api.us-west-2.amazonaws.com/stage
    └─ Stage: prod  → https://api-id.execute-api.us-west-2.amazonaws.com/prod
```

**우리 프로젝트**: `v1` 스테이지 사용

#### c) Resource (리소스)
**용도**: URL 경로 정의

```
/api
  /customers
    /{id}
  /vets
    /{id}
  /visits
    /{id}
  /genai
    /chat
/admin
```

#### d) Method (HTTP 메서드)
```
GET    /api/customers      # 목록 조회
POST   /api/customers      # 생성
GET    /api/customers/{id} # 단일 조회
PUT    /api/customers/{id} # 수정
DELETE /api/customers/{id} # 삭제
```

#### e) Integration (통합)
**용도**: 백엔드 서비스 연결

| 통합 타입 | 설명 | 사용 예시 |
|----------|------|----------|
| **HTTP/HTTP_PROXY** | HTTP 엔드포인트 (ALB 등) | ALB → ECS 서비스 |
| **AWS_PROXY** | Lambda 프록시 통합 | Lambda 함수 |
| **MOCK** | 테스트용 Mock 응답 | 개발 중 |

**우리 프로젝트**:
- HTTP_PROXY: ALB 연결 (customers, vets, visits, admin)
- AWS_PROXY: Lambda 연결 (GenAI)

---

### 4. API Gateway 스로틀링 ⚡

**스로틀링 (Throttling)**: 과도한 요청 제한

```hcl
throttle_rate_limit  = 1000  # 초당 1000 요청
throttle_burst_limit = 2000  # 버스트 2000 요청
```

**동작 원리**:
```
1초 동안:
- 평균: 1000 요청 허용
- 순간: 2000 요청까지 버스트 허용
- 초과: 429 Too Many Requests 응답
```

**Token Bucket 알고리즘**:
```
Bucket: [1000 tokens]
↓
요청 1개 = 토큰 1개 소비
↓
1초마다 1000개 토큰 충전
↓
토큰 부족 시 → 429 에러
```

---

### 5. WAF (Web Application Firewall) 🛡️

**WAF**: 웹 공격 방어 서비스

**주요 기능**:
1. **SQL Injection 방어**: `' OR 1=1--` 같은 공격 차단
2. **XSS 방어**: `<script>alert(1)</script>` 차단
3. **Rate Limiting**: IP당 요청 제한
4. **지역 차단**: 특정 국가 차단

**우리 프로젝트 WAF 규칙**:

```hcl
waf_rate_limit_rules = [
  {
    name     = "GeneralRateLimit"
    priority = 1
    limit    = 1000       # 5분간 1000 요청
    window   = 300        # 5분 (초)
    action   = "BLOCK"
  },
  {
    name     = "StrictRateLimit"
    priority = 2
    limit    = 100        # 1분간 100 요청
    window   = 60         # 1분 (초)
    action   = "BLOCK"
  }
]
```

**WAF 동작**:
```
Client (IP: 1.2.3.4)
    ↓
    5분간 1001번째 요청
    ↓
WAF: "이 IP는 5분간 1000 요청 초과!"
    ↓
403 Forbidden 응답
```

---

## 우리가 만드는 API Gateway 구조

### 전체 아키텍처 다이어그램

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Internet                                    │
│                                                                     │
│  ┌──────────────┐                                                  │
│  │  Client      │  (브라우저, 모바일 앱)                             │
│  └──────┬───────┘                                                  │
│         │                                                           │
└─────────┼───────────────────────────────────────────────────────────┘
          │
          │ HTTPS
          ↓
┌─────────────────────────────────────────────────────────────────────┐
│  ╔═══════════════════════════════════════════════════════════════╗  │
│  ║  AWS WAF                                                      ║  │
│  ║  - DDoS 방어                                                   ║  │
│  ║  - Rate Limiting (5분간 1000 요청)                             ║  │
│  ║  - SQL Injection/XSS 차단                                      ║  │
│  ╚═══════════════════════╤═══════════════════════════════════════╝  │
│                          │                                           │
│                          ↓                                           │
│  ╔═══════════════════════════════════════════════════════════════╗  │
│  ║  API Gateway REST API                                         ║  │
│  ║  https://abc123.execute-api.us-west-2.amazonaws.com/v1       ║  │
│  ║                                                               ║  │
│  ║  ┌──────────────────────────────────────────────────────┐    ║  │
│  ║  │  라우팅 규칙                                          │    ║  │
│  ║  │  /api/customers/* → HTTP_PROXY → ALB                 │    ║  │
│  ║  │  /api/vets/*      → HTTP_PROXY → ALB                 │    ║  │
│  ║  │  /api/visits/*    → HTTP_PROXY → ALB                 │    ║  │
│  ║  │  /admin/*         → HTTP_PROXY → ALB                 │    ║  │
│  ║  │  /api/genai/*     → AWS_PROXY  → Lambda              │    ║  │
│  ║  └──────────────────────────────────────────────────────┘    ║  │
│  ╚═══════════════════════╤═══════════════════════════════════════╝  │
│                          │                                           │
│         ┌────────────────┴────────────────┐                         │
│         │                                 │                         │
│         ↓                                 ↓                         │
│  ╔═════════════════════╗         ╔═══════════════════╗             │
│  ║  ALB                ║         ║  Lambda Function  ║             │
│  ║  (Application LB)   ║         ║  (GenAI 챗봇)      ║             │
│  ║                     ║         ║  - Bedrock        ║             │
│  ║  Target Groups:     ║         ║  - Python 3.11    ║             │
│  ║  - customers (8080) ║         ╚═══════════════════╝             │
│  ║  - vets (8080)      ║                                           │
│  ║  - visits (8080)    ║                                           │
│  ║  - admin (9090)     ║                                           │
│  ╚═════════╤═══════════╝                                           │
│            │                                                        │
│            ↓                                                        │
│  ╔═════════════════════════════════════════════════════════════╗  │
│  ║  ECS Fargate (Private Subnet)                               ║  │
│  ║  - customers-service:8080                                   ║  │
│  ║  - vets-service:8080                                        ║  │
│  ║  - visits-service:8080                                      ║  │
│  ║  - admin-server:9090                                        ║  │
│  ╚═════════════════════════════════════════════════════════════╝  │
└─────────────────────────────────────────────────────────────────────┘

모니터링:
┌────────────────────────────┐
│  CloudWatch                │
│  - API 호출 수              │
│  - 4XX/5XX 에러             │
│  - 지연시간                 │
│  - WAF 차단 요청            │
└────────────────────────────┘
```

---

### 라우팅 상세 설정

#### 1. Microservices 라우팅 (ALB 통합)

```
┌─────────────────────────────────────────────────────────────┐
│  API Gateway → ALB → ECS Target Group                       │
├─────────────────────────────────────────────────────────────┤
│  /api/customers/*  → ALB → customers-service:8080           │
│  /api/vets/*       → ALB → vets-service:8080                │
│  /api/visits/*     → ALB → visits-service:8080              │
│  /admin/*          → ALB → admin-server:9090                │
└─────────────────────────────────────────────────────────────┘
```

**통합 설정**:
```hcl
integration_type    = "HTTP_PROXY"
integration_uri     = "http://${alb_dns_name}:80/{proxy}"
integration_timeout = 29000  # 29초 (API Gateway 최대 29초)
```

**예시 요청 흐름**:
```
1. Client 요청
   GET https://api-gateway-url/v1/api/customers/1
   
2. API Gateway 라우팅
   Resource: /api/customers/{id}
   Method: GET
   
3. ALB 전달
   GET http://alb-dns-name/api/customers/1
   
4. ALB 라우팅
   Target Group: customers-service
   Health Check: /actuator/health
   
5. ECS 응답
   customers-service:8080 → ALB → API Gateway → Client
```

---

#### 2. GenAI 라우팅 (Lambda 통합)

```
┌─────────────────────────────────────────────────────────────┐
│  API Gateway → Lambda → Bedrock                             │
├─────────────────────────────────────────────────────────────┤
│  POST /api/genai/chat  → Lambda Function → Bedrock API      │
└─────────────────────────────────────────────────────────────┘
```

**통합 설정**:
```hcl
integration_type    = "AWS_PROXY"
integration_uri     = lambda_function_invoke_arn
integration_timeout = 29000  # 29초
```

**요청 예시**:
```bash
curl -X POST https://api-gateway-url/v1/api/genai/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "What are the symptoms of a cat with fever?",
    "history": []
  }'
```

**응답**:
```json
{
  "response": "Common symptoms include...",
  "confidence": 0.95,
  "model": "anthropic.claude-3-sonnet-20240229-v1:0"
}
```

---

## 요청 흐름 및 라우팅

### 시나리오 1: 고객 목록 조회

```
1. Client 요청
   GET https://abc123.execute-api.us-west-2.amazonaws.com/v1/api/customers
   
2. WAF 검증
   - IP 확인: 1.2.3.4
   - Rate Limit: 5분간 234번째 요청 (1000 이하, 통과)
   - SQL Injection 패턴: 없음 (통과)
   ✅ WAF 통과
   
3. API Gateway 라우팅
   - Resource: /api/customers
   - Method: GET
   - Integration: HTTP_PROXY → ALB
   - Throttling: 초당 567번째 요청 (1000 이하, 통과)
   ✅ 라우팅 성공
   
4. ALB 전달
   GET http://petclinic-dev-alb-123456.us-west-2.elb.amazonaws.com/api/customers
   
5. ALB Health Check
   - Target Group: customers-service
   - Health Status: Healthy (2/2 targets)
   ✅ 타겟 선택
   
6. ECS 컨테이너 처리
   - Service: customers-service
   - Port: 8080
   - 처리 시간: 145ms
   
7. 응답 경로
   ECS (145ms) → ALB (10ms) → API Gateway (5ms) → Client
   총 응답 시간: 160ms
   
8. CloudWatch 로깅
   - Method: GET
   - Resource: /api/customers
   - Status: 200
   - Latency: 160ms
   - Integration Latency: 155ms
```

---

### 시나리오 2: GenAI 챗봇 호출

```
1. Client 요청
   POST https://abc123.execute-api.us-west-2.amazonaws.com/v1/api/genai/chat
   Body: {"message": "고양이가 아파요"}
   
2. WAF 검증
   ✅ 통과
   
3. API Gateway 라우팅
   - Resource: /api/genai/chat
   - Method: POST
   - Integration: AWS_PROXY → Lambda
   
4. Lambda 함수 호출
   - Function: petclinic-dev-genai
   - Runtime: Python 3.11
   - Memory: 512MB
   
5. Lambda 처리
   - Bedrock API 호출 (Claude 3 Sonnet)
   - 처리 시간: 2.3초
   
6. 응답
   Lambda → API Gateway → Client
   총 응답 시간: 2.35초
   
7. CloudWatch 로깅
   - Lambda Duration: 2300ms
   - Lambda Billed Duration: 2400ms
   - API Gateway Latency: 2350ms
```

---

### 시나리오 3: Rate Limit 초과

```
1. Client 요청 (공격자: IP 1.2.3.4)
   GET /api/customers (5분간 1001번째 요청)
   
2. WAF 차단
   Rule: GeneralRateLimit
   - Limit: 1000 requests / 5 minutes
   - Current: 1001 requests
   - Action: BLOCK
   ❌ 차단됨
   
3. 응답
   HTTP/1.1 403 Forbidden
   {
     "message": "Forbidden"
   }
   
4. CloudWatch 알람
   - Metric: WAFBlockedRequests
   - Threshold: 50 (5분간)
   - Current: 1
   ⚠️ 알람 전송 (임계값 미달)
```

---

## 보안 및 Rate Limiting

### 1. 스로틀링 (API Gateway 자체) ⚡

```hcl
# API Gateway 전역 스로틀링
throttle_rate_limit  = 1000  # 초당 1000 요청
throttle_burst_limit = 2000  # 버스트 2000 요청
```

**동작**:
- 모든 요청에 적용
- 초과 시 `429 Too Many Requests`
- CloudWatch에 `ThrottleCount` 메트릭 기록

---

### 2. WAF Rate Limiting (IP별) 🛡️

```hcl
# WAF 규칙 1: 일반 Rate Limiting
{
  name     = "GeneralRateLimit"
  priority = 1
  limit    = 1000    # 5분간 1000 요청
  window   = 300     # 5분
  action   = "BLOCK"
}

# WAF 규칙 2: 엄격한 Rate Limiting
{
  name     = "StrictRateLimit"
  priority = 2
  limit    = 100     # 1분간 100 요청
  window   = 60      # 1분
  action   = "BLOCK"
}
```

**비교**:
| 구분 | API Gateway 스로틀링 | WAF Rate Limiting |
|------|---------------------|-------------------|
| **범위** | 전역 (모든 IP) | IP별 |
| **기준** | 초당 | 분당 또는 5분당 |
| **응답** | 429 Too Many Requests | 403 Forbidden |
| **비용** | 무료 | WAF 사용료 ($5/월) |

---

### 3. CORS 설정 🌍

**CORS (Cross-Origin Resource Sharing)**: 다른 도메인에서의 API 호출 허용

```
Frontend: https://petclinic.example.com
API: https://api.petclinic.example.com

← 다른 도메인이므로 CORS 설정 필요!
```

**우리 설정**:
```hcl
enable_cors = true

# 모듈에서 자동 설정:
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET,POST,PUT,DELETE,OPTIONS
Access-Control-Allow-Headers: Content-Type,X-Amz-Date,Authorization,X-Api-Key
```

**CORS 요청 흐름**:
```
1. Preflight Request (OPTIONS)
   OPTIONS /api/customers
   Origin: https://petclinic.example.com
   
2. API Gateway 응답
   200 OK
   Access-Control-Allow-Origin: *
   Access-Control-Allow-Methods: GET,POST,PUT,DELETE,OPTIONS
   
3. 실제 요청 (GET)
   GET /api/customers
   Origin: https://petclinic.example.com
   
4. 응답
   200 OK
   Access-Control-Allow-Origin: *
   [customers data]
```

---

## 코드 구조

### 파일 구성

```
08-api-gateway/
├── main.tf              # API Gateway 모듈 호출
├── data.tf              # Remote State 참조 (ALB, Lambda)
├── locals.tf            # 로컬 변수 및 의존성 검증
├── variables.tf         # 변수 정의
├── outputs.tf           # 출력값
├── backend.tf           # Terraform 상태 저장
├── backend.config       # 백엔드 키 설정
├── ../../envs/dev.tfvars     # 실제 값 입력
└── README.md            # 이 문서
```

---

### main.tf 주요 구성

```hcl
module "api_gateway" {
  source = "../../modules/api-gateway"

  # 기본 설정
  name_prefix = "petclinic"
  environment = "dev"
  stage_name  = "v1"

  # ALB 통합 설정 (application 레이어에서 참조)
  alb_dns_name = local.alb_dns_name

  # Lambda 통합 설정 (GenAI 서비스용)
  enable_lambda_integration     = true
  lambda_function_invoke_arn    = local.lambda_function_invoke_arn
  lambda_integration_timeout_ms = 29000

  # 스로틀링 설정
  throttle_rate_limit  = 1000
  throttle_burst_limit = 2000

  # 통합 설정
  integration_timeout_ms = 29000

  # 로깅 및 추적 (임시로 로깅 비활성화)
  log_retention_days  = 14
  enable_xray_tracing = false # X-Ray 추적도 임시 비활성화

  # CORS 설정
  enable_cors = true

  # 사용량 계획
  create_usage_plan = false

  # 모니터링 설정
  enable_monitoring = true
  create_dashboard  = true
  alarm_actions     = ["arn:aws:sns:us-west-2:123456789012:petclinic-dev-alerts"]

  # 임계값 설정
  error_4xx_threshold           = 20
  error_5xx_threshold           = 10
  latency_threshold             = 2000
  integration_latency_threshold = 1500

  # Rate Limiting 설정 (보안 강화)
  enable_rate_limiting         = true
  rate_limit_per_ip            = 1000
  rate_limit_burst_per_ip      = 2000
  rate_limit_window_minutes    = 1
  enable_waf_integration       = true
  rate_limit_alarm_threshold   = 50
  enable_rate_limit_monitoring = true

  tags = local.layer_common_tags
}
```

---

## 배포 방법

### 사전 요구사항

1. **06-lambda-genai 레이어 배포 완료**
```bash
cd ../06-lambda-genai
terraform output lambda_function_invoke_arn
```

2. **07-application 레이어 배포 완료**
```bash
cd ../07-application
terraform output alb_dns_name
# 출력: petclinic-dev-alb-123456.us-west-2.elb.amazonaws.com
```

---

### 배포 순서

#### 1단계: 작업 디렉토리 이동
```bash
cd terraform/layers/08-api-gateway
```

#### 2단계: 변수 파일 확인
```bash
cat ../../envs/dev.tfvars
```

예시:
```hcl
# 공통 설정
name_prefix = "petclinic"
environment = "dev"
aws_region  = "us-west-2"
aws_profile = "default"

# API Gateway 설정
stage_name               = "v1"
throttle_rate_limit      = 1000
throttle_burst_limit     = 2000
integration_timeout_ms   = 29000

# Lambda 통합
enable_lambda_integration     = true
lambda_integration_timeout_ms = 29000

# 로깅
log_retention_days  = 14
enable_xray_tracing = false  # X-Ray 비활성화 (비용 절감)

# CORS
enable_cors = true

# WAF Rate Limiting
enable_waf_integration = true
waf_rate_limit_rules = [
  {
    name        = "GeneralRateLimit"
    priority    = 1
    limit       = 1000
    window      = 300
    action      = "BLOCK"
    description = "5분간 1000 요청 제한"
  }
]

# 모니터링
enable_monitoring = true
create_dashboard  = true

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
terraform plan -var-file=../../envs/dev.tfvars
```

**확인사항**:
- API Gateway REST API 1개
- WAF Web ACL 1개 (Rate Limiting 활성화 시)
- CloudWatch Log Group 1개
- CloudWatch Dashboard 1개

#### 5단계: 배포 실행
```bash
terraform apply -var-file=../../envs/dev.tfvars
```

**소요 시간**: 약 2-3분

#### 6단계: 배포 확인
```bash
# API Gateway URL 확인
terraform output api_gateway_invoke_url
# https://abc123.execute-api.us-west-2.amazonaws.com/v1

# 라우팅 설정 확인
terraform output routing_configuration
```

---

### 배포 후 테스트

#### 1. Health Check (Admin 서비스)
```bash
API_URL=$(terraform output -raw api_gateway_invoke_url)

curl -X GET "${API_URL}/admin/actuator/health"
```

**예상 응답**:
```json
{
  "status": "UP"
}
```

---

#### 2. Customers 서비스 테스트
```bash
# 고객 목록 조회
curl -X GET "${API_URL}/api/customers"

# 고객 생성
curl -X POST "${API_URL}/api/customers" \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "Jane",
    "lastName": "Doe",
    "address": "123 Main St",
    "city": "Seattle",
    "telephone": "2065551234"
  }'
```

---

#### 3. GenAI 챗봇 테스트
```bash
curl -X POST "${API_URL}/api/genai/chat" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "What are the symptoms of a sick cat?",
    "history": []
  }'
```

**예상 응답**:
```json
{
  "response": "Common symptoms of a sick cat include...",
  "model": "anthropic.claude-3-sonnet-20240229-v1:0"
}
```

---

#### 4. Rate Limiting 테스트
```bash
# 1000번 요청 (5분 내)
for i in {1..1001}; do
  curl -s -o /dev/null -w "%{http_code}\n" "${API_URL}/api/customers"
done

# 마지막 요청은 403 Forbidden 응답 예상
```

---

## 문제 해결

### 문제 1: ALB 통합 실패
```
Error: Error creating API Gateway Integration: BadRequestException
```

**원인**: ALB DNS 이름이 올바르지 않음

**해결**:
```bash
# ALB 상태 확인
cd ../07-application
terraform output alb_dns_name

# ALB가 Active 상태인지 확인
aws elbv2 describe-load-balancers \
  --names petclinic-dev-alb \
  --query 'LoadBalancers[0].State.Code'
# "active" 응답 필요
```

---

### 문제 2: Lambda 권한 오류
```
Error: Lambda function cannot be invoked
```

**원인**: API Gateway가 Lambda를 호출할 권한 없음

**해결**:
```bash
# Lambda 함수 확인
cd ../06-lambda-genai
terraform output lambda_function_invoke_arn

# Lambda 권한 확인
aws lambda get-policy \
  --function-name petclinic-dev-genai \
  --query 'Policy' --output text | jq '.'

# API Gateway 권한이 있는지 확인
# Principal: apigateway.amazonaws.com
```

---

### 문제 3: 502 Bad Gateway
```
{
  "message": "Internal server error"
}
```

**디버깅**:

1. **CloudWatch Logs 확인**
```bash
# API Gateway 로그
aws logs tail /aws/apigateway/petclinic-dev --follow

# 에러 패턴:
# "Endpoint request timed out"  → ALB 응답 없음
# "Internal server error"       → ALB 5XX 에러
```

2. **ALB Target Health 확인**
```bash
# Target Group 상태
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:...

# 출력:
# State: healthy   → 정상
# State: unhealthy → ECS 서비스 문제
```

3. **Integration 타임아웃 조정**
```hcl
integration_timeout_ms = 29000  # 최대 29초
```

---

### 문제 4: WAF 차단 (403 Forbidden)
```
HTTP/1.1 403 Forbidden
{
  "message": "Forbidden"
}
```

**원인**: WAF Rate Limiting 규칙에 걸림

**해결**:

1. **WAF 메트릭 확인**
```bash
# 차단된 요청 수
aws cloudwatch get-metric-statistics \
  --namespace AWS/WAFV2 \
  --metric-name BlockedRequests \
  --dimensions Name=Rule,Value=GeneralRateLimit \
  --start-time 2025-11-09T00:00:00Z \
  --end-time 2025-11-09T23:59:59Z \
  --period 300 \
  --statistics Sum
```

2. **Rate Limit 완화** (임시)
```hcl
waf_rate_limit_rules = [
  {
    name     = "GeneralRateLimit"
    limit    = 5000   # 1000 → 5000으로 증가
    window   = 300
    action   = "BLOCK"
  }
]
```

3. **특정 IP 화이트리스트**
```hcl
# WAF IP Set 추가
resource "aws_wafv2_ip_set" "whitelist" {
  name  = "petclinic-whitelist"
  scope = "REGIONAL"
  ip_address_version = "IPV4"
  addresses = ["1.2.3.4/32"]  # 화이트리스트 IP
}
```

---

### 디버깅 명령어

```bash
# API Gateway 상태 확인
aws apigateway get-rest-apis \
  --query 'items[?name==`petclinic-dev-api`]'

# Stage 설정 확인
aws apigateway get-stage \
  --rest-api-id abc123 \
  --stage-name v1

# Integration 확인
aws apigateway get-integration \
  --rest-api-id abc123 \
  --resource-id xyz789 \
  --http-method GET

# WAF 규칙 확인
aws wafv2 list-web-acls --scope REGIONAL

# CloudWatch 메트릭
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApiGateway \
  --metric-name Count \
  --dimensions Name=ApiName,Value=petclinic-dev-api \
  --start-time 2025-11-09T00:00:00Z \
  --end-time 2025-11-09T23:59:59Z \
  --period 3600 \
  --statistics Sum
```

---

## 비용 예상

### API Gateway 비용

| 구성 요소 | 사양 | 월 비용 (USD) |
|----------|------|---------------|
| **REST API 호출** | 1백만 요청 | $3.50 |
| **데이터 전송 (out)** | 1GB | $0.09 |
| **CloudWatch Logs** | 5GB | $2.50 ($0.50/GB) |
| **WAF Web ACL** | 1개 | $5.00 |
| **WAF Rules** | 2개 | $2.00 ($1.00/개) |
| **합계 (월 1백만 요청)** | - | **$13.09** |

### 예상 트래픽별 비용

| 월 요청 수 | API Gateway | WAF | 합계 |
|-----------|-------------|-----|------|
| **1백만** | $3.50 | $7.00 | **$10.50** |
| **10백만** | $35.00 | $7.00 | **$42.00** |
| **100백만** | $350.00 | $7.00 | **$357.00** |

**비용 최적화 팁**:
- HTTP API 사용: $1.00/백만 요청 (WAF 불필요 시)
- 캐싱 활성화: 중복 요청 감소
- WAF 비활성화: 개발 환경 (프로덕션은 필수)

---

## 다음 단계

API Gateway 레이어 배포가 완료되면:

1. **09-aws-native**: S3, CloudFront, Route53
2. **10-monitoring**: CloudWatch, X-Ray, SNS 통합
3. **11-frontend**: 프론트엔드 배포

```bash
cd ../09-aws-native
terraform init -backend-config=../../backend.hcl -backend-config=backend.config
terraform plan -var-file=../../envs/dev.tfvars
```

---

## 요약

### 핵심 개념 정리
- ✅ **API Gateway**: Spring Cloud Gateway 대체 (서버리스)
- ✅ **HTTP_PROXY**: ALB 통합 (Microservices)
- ✅ **AWS_PROXY**: Lambda 통합 (GenAI)
- ✅ **WAF**: Rate Limiting, DDoS 방어
- ✅ **스로틀링**: 초당 1000 요청, 버스트 2000

### 생성되는 주요 리소스
- API Gateway REST API 1개
- Stage: v1
- Resources: /api/customers, /api/vets, /api/visits, /admin, /api/genai
- WAF Web ACL 1개 (Rate Limiting 규칙 2개)
- CloudWatch Dashboard 1개

### 라우팅 경로
```bash
# Microservices
/api/customers/*  → ALB → ECS (customers-service:8080)
/api/vets/*       → ALB → ECS (vets-service:8080)
/api/visits/*     → ALB → ECS (visits-service:8080)
/admin/*          → ALB → ECS (admin-server:9090)

# GenAI
/api/genai/*      → Lambda → Bedrock
```

### 보안 설정
```
✅ WAF 통합 (Rate Limiting, DDoS 방어)
✅ API Gateway 스로틀링 (초당 1000 요청)
✅ CORS 지원
✅ CloudWatch 모니터링
```

---

**작성일**: 2025-11-09  
**작성자**: 황영현 
**버전**: 1.0
