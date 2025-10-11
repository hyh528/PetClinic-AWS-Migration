# 08-API Gateway Layer

## 개요

AWS API Gateway를 사용하여 Spring Cloud Gateway를 대체하는 레이어입니다. 단일 책임 원칙(SRP)을 적용하여 API Gateway 관리만 담당하며, AWS 네이티브 서비스의 장점을 활용합니다.

## 아키텍처

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Client        │    │  API Gateway    │    │  ALB + ECS      │
│                 │    │                 │    │                 │
│ - Web Browser   │───▶│ - 라우팅        │───▶│ - 마이크로서비스 │
│ - Mobile App    │    │ - 스로틀링      │    │ - 로드 밸런싱    │
│ - API Client    │    │ - 인증/인가     │    │ - 헬스체크      │
└─────────────────┘    │ - 모니터링      │    └─────────────────┘
                       │ - CORS          │
                       └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │  Lambda GenAI   │
                       │                 │
                       │ - AI 서비스     │
                       │ - Bedrock 통합  │
                       └─────────────────┘
```

## 주요 기능

### Spring Cloud Gateway 대체
- **AWS 네이티브 서비스**: 완전 관리형 API Gateway
- **자동 스케일링**: 트래픽에 따른 자동 확장
- **내장 모니터링**: CloudWatch 통합
- **비용 효율성**: 요청당 과금 모델

### 핵심 기능
1. **라우팅**: 경로 기반 마이크로서비스 라우팅
2. **스로틀링**: 요청 수 제한 및 버스트 제어
3. **CORS**: Cross-Origin Resource Sharing 지원
4. **모니터링**: CloudWatch 알람 및 대시보드
5. **Lambda 통합**: GenAI 서비스 연동

## 의존성

이 레이어는 다음 레이어들에 의존합니다:

1. **01-network**: VPC 정보 (선택적)
2. **02-security**: IAM 역할 (선택적)
3. **07-application**: ALB DNS 이름

## 사용법

### 1. 초기화
```bash
cd terraform/layers/08-api-gateway
terraform init -backend-config="../../envs/dev/backend.hcl"
```

### 2. 계획 확인
```bash
terraform plan -var-file="../../envs/dev/terraform.tfvars"
```

### 3. 배포
```bash
terraform apply -var-file="../../envs/dev/terraform.tfvars"
```

## 주요 변수

| 변수명 | 설명 | 기본값 | 필수 |
|--------|------|--------|------|
| `name_prefix` | 리소스 이름 접두사 | - | ✅ |
| `environment` | 배포 환경 | - | ✅ |
| `stage_name` | API Gateway 스테이지 | `v1` | ❌ |
| `throttle_rate_limit` | 초당 요청 수 제한 | `1000` | ❌ |
| `throttle_burst_limit` | 버스트 요청 수 제한 | `2000` | ❌ |
| `enable_lambda_integration` | Lambda 통합 활성화 | `false` | ❌ |
| `enable_monitoring` | 모니터링 활성화 | `true` | ❌ |
| `enable_cors` | CORS 지원 | `true` | ❌ |

## 라우팅 구성

### 기본 라우팅
```
GET  /api/customers/*  → ALB/customers-service
GET  /api/vets/*       → ALB/vets-service
GET  /api/visits/*     → ALB/visits-service
POST /api/genai/*      → Lambda/bedrock-function
GET  /admin/*          → ALB/admin-server
```

### Lambda 통합 (GenAI)
```
POST /api/genai/chat          → Lambda Function
POST /api/genai/recommendations → Lambda Function
```

## 출력값

### API Gateway 정보
- `api_gateway_id`: API Gateway REST API ID
- `api_gateway_invoke_url`: API 호출 URL
- `api_gateway_stage_name`: 스테이지 이름
- `api_gateway_execution_arn`: 실행 ARN

### 라우팅 정보
- `routing_configuration`: 라우팅 설정 정보
- `service_resources`: 서비스별 리소스 정보

### 모니터링 정보
- `monitoring_info`: 모니터링 설정 및 대시보드 정보

## 개선사항

### ✅ 완료된 개선사항
1. **공유 변수 시스템 적용**: 하드코딩 제거
2. **개인 경로 상태 참조 제거**: 표준화된 상태 참조
3. **단일 책임 원칙 적용**: API Gateway 관리만 담당
4. **AWS 네이티브 서비스**: Spring Cloud Gateway 완전 대체
5. **모니터링 통합**: CloudWatch 알람 및 대시보드

### 🔄 향후 개선 계획
1. **인증/인가**: Cognito 통합
2. **API 키 관리**: 사용량 계획 및 API 키
3. **캐싱**: 응답 캐싱 활성화
4. **WAF 통합**: 보안 강화

## 모니터링

### CloudWatch 메트릭
- API Gateway 요청 수 및 응답 시간
- 4XX/5XX 에러율
- 통합 지연시간
- 스로틀링 발생 횟수

### 알람 설정
```hcl
알람 임계값:
  4XX 에러: 20개/분
  5XX 에러: 10개/분
  지연시간: 2000ms
  통합 지연시간: 1500ms
```

### 대시보드
- API Gateway 성능 메트릭
- 서비스별 요청 분포
- 에러율 및 지연시간 추이

## Spring Cloud Gateway 마이그레이션

### 마이그레이션 완료 항목
- ✅ 라우팅 규칙 이전
- ✅ 스로틀링 설정 이전
- ✅ CORS 설정 이전
- ✅ 모니터링 설정 이전
- ✅ Lambda 통합 (GenAI)

### 마이그레이션 혜택
1. **운영 부담 제거**: 서버 관리 불필요
2. **자동 스케일링**: 트래픽 급증 대응
3. **비용 최적화**: 사용량 기반 과금
4. **보안 강화**: AWS 보안 기능 활용
5. **모니터링 개선**: CloudWatch 네이티브 통합

## 문제 해결

### 일반적인 문제
1. **502 Bad Gateway**: ALB 연결 확인
2. **스로틀링 에러**: 요청 제한 설정 확인
3. **CORS 에러**: CORS 설정 확인
4. **Lambda 타임아웃**: 함수 실행 시간 확인

### 디버깅 명령어
```bash
# API Gateway 상태 확인
aws apigateway get-rest-api --rest-api-id {api_id}

# 배포 상태 확인
aws apigateway get-deployment --rest-api-id {api_id} --deployment-id {deployment_id}

# CloudWatch 로그 확인
aws logs get-log-events --log-group-name "API-Gateway-Execution-Logs_{api_id}/{stage_name}"
```

## 비용 최적화

### 요청당 과금
```
API Gateway 요청: $3.50 per million requests
데이터 전송: $0.09 per GB (첫 10TB)
CloudWatch 로그: $0.50 per GB ingested
```

### 비용 절감 방안
1. **캐싱 활용**: 반복 요청 캐싱
2. **로그 최적화**: 필요한 로그만 활성화
3. **압축 활성화**: 응답 데이터 압축
4. **사용량 모니터링**: 비정상적 사용 패턴 감지

## 태그 전략

모든 리소스에는 다음 태그가 자동으로 적용됩니다:

```hcl
{
  Environment = var.environment
  Layer       = "08-api-gateway"
  Component   = "api-gateway"
  ManagedBy   = "terraform"
  # + 사용자 정의 태그 (var.tags)
}
```