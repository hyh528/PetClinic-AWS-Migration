# API Gateway 레이어 (08-api-gateway)

## 개요

API Gateway는 마이크로서비스 아키텍처에서 **중앙 라우팅 허브** 역할을 하는 중요한 컴포넌트입니다. Spring Cloud Gateway를 대체하여 AWS 네이티브 서비스로 구현되었습니다.

## API Gateway의 역할

### 🏗️ 아키텍처 관점
```
인터넷 ← API Gateway ← 마이크로서비스들
```

API Gateway는 **단일 진입점**을 제공하여 클라이언트가 여러 마이크로서비스를 일관된 방식으로 접근할 수 있게 합니다.

### 🔄 주요 기능

#### 1. 라우팅 (Routing)
- **URL 경로 기반 라우팅**: `/api/customers` → 고객 서비스
- **헤더 기반 라우팅**: 요청 헤더에 따라 다른 서비스로 라우팅
- **메서드 기반 라우팅**: GET, POST, PUT, DELETE 등 HTTP 메서드별 처리

#### 2. 로드 밸런싱 (Load Balancing)
- **ALB 통합**: Application Load Balancer와 연동하여 트래픽 분산
- **헬스 체크**: 서비스 상태 모니터링 및 장애 자동 우회
- **다중 AZ 지원**: 고가용성을 위한 Multi-AZ 배포

#### 3. 보안 (Security)

##### CORS (Cross-Origin Resource Sharing)
웹 브라우저의 동일 출처 정책을 우회하기 위한 메커니즘입니다.

**왜 필요한가?**
- 웹 애플리케이션이 다른 도메인의 API를 호출할 때 발생하는 보안 제한 해결
- 프론트엔드 (React, Vue 등)가 백엔드 API를 안전하게 호출할 수 있게 함

**동작 방식:**
```javascript
// 브라우저가 OPTIONS 요청을 먼저 보냄
OPTIONS /api/customers
// 서버가 허용된 출처, 메서드, 헤더를 응답
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, PUT, DELETE
Access-Control-Allow-Headers: Content-Type, Authorization
```

##### WAF (Web Application Firewall)
웹 애플리케이션을 보호하는 방화벽입니다.

**주요 기능:**
- **SQL Injection 방지**: 악의적인 SQL 쿼리 차단
- **XSS 방지**: 크로스 사이트 스크립팅 공격 차단
- **Rate Limiting**: 과도한 요청 제한

##### Rate Limiting (요청 제한)
짧은 시간에 너무 많은 요청이 오는 것을 방지합니다.

**예시:**
- IP 주소당 1분에 1000개 요청 제한
- API 키당 시간당 10000개 요청 제한

#### 4. 모니터링 및 로깅

##### CloudWatch 메트릭
- **요청 수**: 총 API 호출 횟수
- **에러율**: 4XX, 5XX 에러 비율
- **지연시간**: API 응답 시간
- **스로틀링**: 제한된 요청 수

##### CloudWatch 알람
- 에러율 임계값 초과 시 알람
- 지연시간 임계값 초과 시 알람
- 스로틀링 발생 시 알람

## 아키텍처 구성

### 서비스 매핑
```yaml
# REST API 경로 매핑
/api/customers/* → 고객 서비스 (ALB)
/api/vets/*     → 수의사 서비스 (ALB)
/api/visits/*   → 예약 서비스 (ALB)
/admin/*        → 관리 서비스 (ALB)
/api/genai/*    → AI 서비스 (Lambda)
```

### 통합 방식

#### HTTP 통합 (ALB)
```hcl
resource "aws_api_gateway_integration" "alb_service" {
  type = "HTTP_PROXY"
  uri  = "http://${alb_dns_name}/api/customers"
}
```

#### Lambda 통합
```hcl
resource "aws_api_gateway_integration" "lambda_service" {
  type = "AWS_PROXY"
  uri  = lambda_function_invoke_arn
}
```

## 보안 계층

### 1. 네트워크 레벨
- VPC 내 프라이빗 서브넷 배치
- 보안 그룹을 통한 접근 제어

### 2. 애플리케이션 레벨
- WAF를 통한 웹 공격 방지
- Rate Limiting을 통한 DDoS 방어
- CORS를 통한 크로스 오리진 제어

### 3. 모니터링 레벨
- CloudWatch를 통한 실시간 모니터링
- CloudTrail을 통한 감사 로그

## 배포 및 관리

### Terraform 구조
```
terraform/layers/08-api-gateway/
├── main.tf           # 레이어 메인 설정
├── variables.tf      # 입력 변수
├── outputs.tf        # 출력 값
└── provider.tf       # 프로바이더 설정

terraform/modules/api-gateway/
├── main.tf           # API Gateway 핵심 리소스
├── cors.tf           # CORS 설정
├── monitoring.tf     # 모니터링 설정
├── waf.tf            # 보안 설정
├── variables.tf      # 모듈 변수
└── outputs.tf        # 모듈 출력
```

### 배포 순서
1. VPC 및 네트워크 인프라 배포
2. ALB 및 ECS 서비스 배포
3. API Gateway 배포
4. WAF 및 모니터링 설정

## 모니터링 대시보드

### 주요 메트릭
- **총 요청 수**: API Gateway 사용량 파악
- **에러율**: 서비스 건강 상태 모니터링
- **지연시간**: 성능 이슈 감지
- **스로틀링**: Rate Limiting 효과 모니터링

### 알람 설정
- 4XX 에러율 > 5% → 경고
- 5XX 에러율 > 1% → 긴급
- 평균 지연시간 > 2초 → 경고
- 스로틀링 발생 → 알림

## 문제 해결

### 일반적인 이슈

#### CORS 에러
```
Access to XMLHttpRequest blocked by CORS policy
```
**해결:** CORS 설정 확인 및 OPTIONS 메서드 지원

#### Rate Limiting
```
Too Many Requests (429)
```
**해결:** Rate Limiting 규칙 조정 또는 API 키 사용

#### 라우팅 실패
```
Resource not found (404)
```
**해결:** API Gateway 리소스 및 메서드 설정 확인

## 확장성 고려사항

### 수평 확장
- API Gateway는 AWS에서 자동 확장
- ALB와의 통합으로 백엔드 서비스 확장 지원

### 수직 확장
- Rate Limiting 규칙 조정
- 캐싱 전략 적용
- CDN (CloudFront) 연동

### 다중 리전 배포
- Route 53을 통한 글로벌 라우팅
- CloudFront를 통한 엣지 로케이션 활용

## 결론

API Gateway는 마이크로서비스 아키텍처의 핵심 컴포넌트로, 다음과 같은 이점을 제공합니다:

### 장점
- **단일 진입점**: 클라이언트와 서비스 간 추상화
- **보안 강화**: 중앙 집중식 보안 정책 적용
- **모니터링 용이**: 모든 API 호출에 대한 통합 모니터링
- **확장성**: AWS의 자동 확장 기능 활용

### 운영 효율성
- **표준화**: 일관된 API 인터페이스 제공
- **유지보수성**: 중앙 집중식 설정 관리
- **신뢰성**: 고가용성 및 장애 대응 메커니즘

이 문서를 통해 API Gateway의 역할과 중요성을 이해하고, 효과적인 운영 전략을 수립할 수 있습니다.