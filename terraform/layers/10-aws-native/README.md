# 10-AWS Native Services Layer

## 개요

AWS 네이티브 서비스들 간의 기본 통합만 제공하는 대폭 단순화된 레이어입니다. 불필요한 고급 기능(WAF, Route53, 통합 대시보드)을 제거하고 핵심적인 Lambda-API Gateway 통합만 유지합니다.

## 아키텍처

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   API Gateway   │    │   Lambda        │    │   Integration   │
│                 │    │                 │    │                 │
│ - REST API      │───▶│ - GenAI 함수    │───▶│ - 권한 설정     │
│ - 라우팅        │    │ - Bedrock 통합  │    │ - 기본 연결     │
│ - 엔드포인트    │    │ - 서버리스      │    │ - 단순화됨      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 주요 기능

### 기본 통합만 유지
- **Lambda 권한 설정**: API Gateway에서 Lambda 호출 허용
- **기본 연결**: 최소한의 서비스 간 통합
- **단순화된 구조**: 복잡한 기능 제거

### 제거된 복잡성
- ❌ WAF 보호 기능
- ❌ Route53 헬스체크
- ❌ 통합 대시보드
- ❌ 복잡한 모니터링 알람
- ❌ 고급 보안 기능
- ❌ 커스텀 도메인 설정

## 의존성

이 레이어는 다음 레이어들에 의존합니다:

1. **06-lambda-genai**: Lambda 함수 정보
2. **08-api-gateway**: API Gateway 정보

## 사용법

### 1. 초기화
```bash
cd terraform/layers/10-aws-native
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
| `enable_lambda_integration` | Lambda 통합 활성화 | `true` | ❌ |

## 출력값

### 통합 상태
- `integration_status`: Lambda-API Gateway 통합 상태
- `service_endpoints`: 서비스 엔드포인트 정보
- `integration_summary`: 통합 설정 요약

## 개선사항

### ✅ 완료된 개선사항
1. **대폭 단순화**: 불필요한 고급 기능 모두 제거
2. **공유 변수 시스템 적용**: 하드코딩 제거
3. **개인 경로 상태 참조 제거**: 표준화된 상태 참조
4. **기본 통합만 유지**: Lambda-API Gateway 권한 설정만
5. **복잡성 제거**: WAF, Route53, 대시보드 등 제거

### 🔄 향후 개선 계획
1. **선택적 기능 추가**: 필요시 고급 기능 선택적 활성화
2. **모니터링 통합**: 기본 모니터링 기능 추가
3. **보안 강화**: 필요시 보안 기능 추가

## 통합 기능

### Lambda 권한 설정
```hcl
리소스: aws_lambda_permission
목적: API Gateway에서 Lambda 함수 호출 허용
조건: enable_lambda_integration = true
```

### 기본 연결
- API Gateway와 Lambda GenAI 함수 간 기본 연결
- 최소 권한 원칙 적용
- 단순한 권한 설정만

## 제거된 기능

### 고급 기능들
- **WAF 보호**: 웹 애플리케이션 방화벽
- **Route53 헬스체크**: DNS 기반 헬스체크
- **통합 대시보드**: CloudWatch 대시보드
- **복잡한 알람**: 다양한 메트릭 알람
- **보안 강화**: 고급 보안 설정
- **커스텀 도메인**: 사용자 정의 도메인

### 복잡한 설정들
- **다중 통합**: 여러 서비스 간 복잡한 통합
- **고급 모니터링**: 상세한 메트릭 및 알람
- **비용 최적화**: 복잡한 비용 추적
- **컴플라이언스**: 규정 준수 설정

## 문제 해결

### 일반적인 문제
1. **Lambda 호출 실패**: 권한 설정 확인
2. **통합 상태 확인**: 출력값 확인
3. **상태 참조 오류**: 의존성 레이어 배포 확인

### 디버깅 명령어
```bash
# Lambda 권한 확인
aws lambda get-policy --function-name {function_name}

# API Gateway 상태 확인
aws apigateway get-rest-api --rest-api-id {api_id}

# 통합 상태 확인
terraform output integration_status
```

## 비용 최적화

### 예상 월간 비용
```
Lambda 권한: $0 (무료)
기본 통합: $0 (무료)
총계: $0 per month
```

### 비용 절감 효과
- **고급 기능 제거**: WAF, Route53 등 비용 절약
- **단순화**: 복잡한 리소스 제거로 비용 절감
- **최소 권한**: 필요한 권한만 설정

## 태그 전략

모든 리소스에는 다음 태그가 자동으로 적용됩니다:

```hcl
{
  Environment = var.environment
  Layer       = "10-aws-native"
  Component   = "aws-native-integration"
  ManagedBy   = "terraform"
  # + 사용자 정의 태그 (var.tags)
}
```

## 마이그레이션 가이드

### 기존 복잡한 설정에서 단순화된 설정으로
1. **기존 리소스 백업**: 중요한 설정 백업
2. **단계적 제거**: 불필요한 리소스 단계적 제거
3. **기본 통합 유지**: 핵심 Lambda-API Gateway 통합만 유지
4. **검증**: 기본 기능 정상 작동 확인