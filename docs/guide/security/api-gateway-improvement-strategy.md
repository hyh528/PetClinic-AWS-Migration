# API Gateway 개선 전략 - 프로페셔널 포트폴리오 구축

## 🎯 **목표: "오, 정말 이 사람 뽑고 싶다!" 느낌의 포트폴리오**

### 프로젝트 퀄리티 향상을 위한 전략적 접근법

---

## **현재 상황 분석**

### 휘권의 버전 vs 영현의 버전 비교

#### 휘권의 접근법 (단순한 프록시)
**장점 ✅**
- 단순성: 이해하기 쉬운 구조
- 빠른 구현: 최소한의 코드로 동작
- 학습 친화적: 초보자가 이해하기 쉬움
- 디버깅 용이: 문제 발생 시 추적 쉬움

**단점 ❌**
- 기본 프록시만 구현 (상세 라우팅 누락)
- 스로틀링 설정 문법 오류
- Lambda 통합 미준비
- CORS 미지원 (보안 취약점)
- 모니터링 알람 없음

#### 영현의 접근법 (완전한 엔터프라이즈급)
**장점 ✅**
- 설계서 5.2절 "ALB로 프록시 통합" 완벽 구현
- AWS Well-Architected Framework 모든 기둥 충족
- 프로덕션 준비 완료
- 상세한 CloudWatch 알람 및 대시보드
- CORS 보안 설정 완비
- Lambda 통합 준비 (GenAI 서비스 마이그레이션 대비)

**단점 ⚠️**
- 복잡성: 초기 학습 곡선 높음
- 오버엔지니어링: Dev 환경에는 과할 수 있음 (Production 환경 적합)
- 팀원들이 이해하기 어려울 수 있음

---

## 🚀 **추천: 전략적 혼합 접근법**

### 왜 혼합이 최선인가?

**1. 팀워크 시연**
- 휘권의 단순한 구조를 기반으로 시작 → "팀원의 아이디어를 존중"
- 영현의 고급 기능을 점진적 추가 → "리더십과 기술력 시연"
- 결과: "협업하면서도 기술적 우수성을 발휘하는 인재"

**2. 실무 현실 반영**
- 실제 회사에서는 기존 코드를 개선하는 경우가 많음
- 처음부터 완벽한 코드보다 점진적 개선이 더 현실적
- 면접관이 "실무 경험이 있구나" 느낄 수 있음

---

## **전략적 구현 계획**

### Phase 1: 휘권 코드 수정 (즉시 적용)

```terraform
# 1. 문법 오류 수정 (필수)
resource "aws_api_gateway_stage" "this" {
  # throttle_settings 제거 → 사용량 계획으로 이동
  # 기존 오류 수정
}

# 2. 기본 CORS 추가 (필수)
resource "aws_api_gateway_method" "proxy_options" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# 3. 로그 그룹 참조 수정 (필수)
resource "aws_api_gateway_stage" "this" {
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
    # 올바른 참조로 수정
  }
}
```

### Phase 2: 점진적 고도화 (선택적 적용)

```terraform
# 4. 사용량 계획 추가 (프로페셔널함 시연)
resource "aws_api_gateway_usage_plan" "this" {
  name        = "${var.project_name}-${var.environment}-usage-plan"
  description = "PetClinic API 사용량 계획"

  api_stages {
    api_id = aws_api_gateway_rest_api.this.id
    stage  = aws_api_gateway_stage.this.stage_name
  }

  # Dev 환경용 관대한 스로틀링
  throttle_settings {
    rate_limit  = 10000  # 높은 한계로 설정
    burst_limit = 20000  # 개발 편의성 우선
  }
}

# 5. 기본 모니터링 추가 (운영 마인드 시연)
resource "aws_cloudwatch_metric_alarm" "api_5xx_error_rate" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name          = "${var.project_name}-${var.environment}-api-5xx-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = 5

  alarm_description = "API Gateway 5XX 에러율이 임계값을 초과했습니다"
  
  dimensions = {
    ApiName = aws_api_gateway_rest_api.this.name
    Stage   = aws_api_gateway_stage.this.stage_name
  }
}
```

### Phase 3: 미래 확장성 준비 (아키텍트 역량 시연)

```terraform
# 6. Lambda 통합 준비 (비활성화 상태)
variable "enable_lambda_integration" {
  description = "Lambda 통합 활성화 (현재 dev에서는 false)"
  type        = bool
  default     = false  # 현재는 false, 나중에 활성화 가능
}

# 7. 조건부 리소스로 확장성 시연
resource "aws_api_gateway_resource" "genai" {
  count       = var.enable_lambda_integration ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "genai"
}

resource "aws_api_gateway_method" "genai_any" {
  count         = var.enable_lambda_integration ? 1 : 0
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.genai[0].id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "genai_integration" {
  count                   = var.enable_lambda_integration ? 1 : 0
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.genai[0].id
  http_method             = aws_api_gateway_method.genai_any[0].http_method
  integration_http_method = "POST"  # Lambda는 항상 POST
  type                    = "AWS_PROXY"  # Lambda 프록시 통합
  uri                     = var.lambda_function_invoke_arn
  timeout_milliseconds    = 30000
}
```

---

## **팀원 이해도 향상 전략**

### 1. 상세한 주석 추가

```terraform
# API Gateway REST API 생성
# 목적: Spring Cloud Gateway를 AWS 관리형 서비스로 대체
# 장점: 서버 관리 불필요, 자동 스케일링, 내장 모니터링
resource "aws_api_gateway_rest_api" "this" {
  name = "${var.project_name}-${var.environment}-api"
  
  # Regional 엔드포인트 선택 이유:
  # - 지연시간 최소화 (서울 리전 내 통신)
  # - 비용 효율성 (Edge 대비 저렴)
  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-api"
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "마이크로서비스 API 라우팅"
    ManagedBy   = "terraform"
  }
}

# 프록시 리소스 생성
# {proxy+}: 모든 하위 경로를 ALB로 전달하는 와일드카드 패턴
# 장점: 단순한 구조, 유지보수 용이
# 단점: 세밀한 라우팅 제어 제한
resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "{proxy+}"
}
```

### 2. README 문서 작성

```markdown
# API Gateway 모듈 설명

## 아키텍처 결정 배경

### 1. 단순한 프록시 구조 선택
- **이유**: 유지보수성과 디버깅 편의성
- **장점**: 팀원 모두가 이해할 수 있는 구조
- **트레이드오프**: 세밀한 라우팅 제어는 ALB에 위임

### 2. 점진적 기능 확장
- **Phase 1**: 기본 프록시 기능 (MVP)
- **Phase 2**: CORS 및 로깅 (웹 지원)
- **Phase 3**: 모니터링 강화 (운영 준비)
- **Phase 4**: Lambda 통합 (서버리스 전환)

### 3. 팀 협업 고려
- 기존 팀원의 구조를 존중하면서 개선
- 단계별 구현으로 리스크 최소화
- 충분한 문서화와 주석 제공

## 구현 단계

- [x] Phase 1: 기본 프록시 기능
- [x] Phase 2: CORS 및 로깅
- [ ] Phase 3: 모니터링 강화
- [ ] Phase 4: Lambda 통합

## 기술적 의사결정

### API Gateway vs ALB 직접 연결
- **선택**: API Gateway → ALB 구조
- **이유**: AWS 네이티브 서비스 활용, 관리형 서비스 장점
- **장점**: 자동 스케일링, 내장 모니터링, 요청/응답 변환

### REST API vs HTTP API
- **선택**: REST API
- **이유**: 더 많은 기능 제공 (사용량 계획, API 키 등)
- **트레이드오프**: HTTP API 대비 약간 높은 비용

### 프록시 통합 vs Lambda 통합
- **현재**: 프록시 통합 (ALB로 직접 전달)
- **미래**: Lambda 통합 준비 (GenAI 서비스용)
- **전략**: 조건부 리소스로 확장성 확보
```

### 3. 팀 교육 자료 준비

```yaml
# 팀 공유용 학습 자료

API Gateway 기본 개념:
  REST API vs HTTP API:
    - REST API: 더 많은 기능, 약간 높은 비용
    - HTTP API: 빠르고 저렴, 기본 기능만
  
  통합 방식:
    - HTTP_PROXY: 요청을 그대로 백엔드로 전달
    - AWS_PROXY: Lambda 전용, 특별한 요청/응답 형식
    - MOCK: 테스트용, 실제 백엔드 없이 응답

  스로틀링과 사용량 계획:
    - 스로틀링: 초당 요청 수 제한
    - 사용량 계획: 일일/월간 할당량 관리
    - API 키: 클라이언트 식별 및 접근 제어

실습 가이드:
  로컬 테스트:
    - curl 명령어로 API Gateway 엔드포인트 테스트
    - Postman을 이용한 API 테스트
    - CORS 동작 확인 방법

  모니터링:
    - CloudWatch에서 API Gateway 메트릭 확인
    - 액세스 로그 분석 방법
    - 에러 발생 시 디버깅 절차

  문제 해결:
    - 502 Bad Gateway: ALB 연결 문제
    - 403 Forbidden: API 키 또는 권한 문제
    - 429 Too Many Requests: 스로틀링 제한
```

---

## **면접관에게 어필할 포인트**

### 1. 기술적 우수성
```
"기존 팀원의 단순한 구조를 기반으로 하되, 
프로덕션 요구사항을 만족하는 기능들을 점진적으로 추가했습니다.

예를 들어, 스로틀링 설정 오류를 수정하고 사용량 계획으로 이동시켜 
DDoS 방지와 비용 제어를 동시에 달성했습니다."
```

### 2. 팀워크 능력
```
"팀원의 코드를 완전히 갈아엎지 않고, 
기존 구조를 존중하면서 개선점을 찾아 적용했습니다.

이 과정에서 팀원들이 이해할 수 있도록 상세한 주석과 
문서화를 통해 지식 공유에도 신경 썼습니다."
```

### 3. 실무 마인드
```
"단계적 구현을 통해 리스크를 최소화하고, 
각 단계별로 테스트와 검증을 거쳤습니다.

특히 dev 환경의 특성을 고려해 개발 편의성을 우선하되, 
프로덕션 전환 시 필요한 기능들을 미리 준비해두었습니다."
```

### 4. 아키텍처 설계 능력
```
"AWS Well-Architected Framework의 5가지 기둥을 모두 고려했습니다:
- 운영 우수성: CloudWatch 모니터링 및 알람
- 보안: CORS 설정, API 키 관리
- 안정성: 에러율 기반 알람 시스템
- 성능 효율성: 지연시간 모니터링
- 비용 최적화: 사용량 기반 스로틀링"
```

---

## **최종 권장사항**

### **혼합 접근법을 선택하는 이유**

1. **차별화**: 단순 복붙이 아닌 "개선" 스토리
2. **현실성**: 실제 업무 환경과 유사한 상황
3. **균형감**: 기술력과 협업 능력 동시 어필
4. **확장성**: 미래 요구사항 대응 능력 시연

### **구체적 실행 계획**

```bash
# 1주차: 기본 기능 안정화
- 휘권 코드 오류 수정
- 기본 CORS 추가
- 문서화 시작

# 2주차: 운영 기능 추가  
- 모니터링 알람 추가
- 사용량 계획 구현
- 팀 교육 자료 작성

# 3주차: 미래 준비
- Lambda 통합 준비
- 성능 최적화
- 최종 문서 정리
```

### **스토리텔링 포인트**

면접에서 활용할 수 있는 스토리:

```
"팀 프로젝트에서 API Gateway 모듈을 담당하게 되었는데, 
팀원이 작성한 기본 구조가 있었습니다.

처음에는 완전히 새로 작성하고 싶었지만, 
팀워크를 고려해 기존 구조를 존중하기로 했습니다.

대신 단계적으로 개선점을 찾아 적용했는데:
1. 먼저 문법 오류와 보안 취약점을 수정
2. 그 다음 운영에 필요한 모니터링 기능 추가
3. 마지막으로 미래 확장성을 위한 준비

결과적으로 팀원들도 이해할 수 있으면서도 
프로덕션 수준의 품질을 갖춘 모듈이 완성되었습니다."
```

---

## **관련 문서**

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [API Gateway 모범 사례](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-basic-concept.html)
- [Terraform AWS Provider 문서](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

---

**작성일**: 2025년 10월 4일  
**작성자**: 영현  
**목적**: 프로페셔널 포트폴리오 구축을 위한 API Gateway 개선 전략