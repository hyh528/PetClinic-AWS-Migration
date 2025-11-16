# CloudMap 전환 후 불필요한 코드 분석

## 🔍 분석 요약

CloudMap(AWS Cloud Map) 기반 서비스 디스커버리로 전환했지만, **현재 아키텍처에서는 대부분의 코드가 여전히 필요합니다.**

## 📊 현재 아키텍처 이해

### 통신 방식

```
┌─────────────────────────────────────────────────────────┐
│                  외부 트래픽                             │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
            ┌────────────────┐
            │  CloudFront    │
            │  + API Gateway │
            └────────┬───────┘
                     │
                     ▼
            ┌────────────────┐
            │   WAF (ALB)    │ ◄─── 필요! (외부 공격 차단)
            └────────┬───────┘
                     │
                     ▼
            ┌────────────────┐
            │      ALB       │ ◄─── 필요! (외부 → 내부 진입점)
            └────────┬───────┘
                     │
        ┌────────────┴────────────┐
        │                         │
        ▼                         ▼
┌───────────────┐         ┌───────────────┐
│ Admin Server  │         │  Customers    │
│  (9090)       │         │  (8080)       │
└───────┬───────┘         └───────┬───────┘
        │                         │
        │  ①ALB 통한 Actuator     │  ②CloudMap 통한
        │    Health Check         │    서비스간 통신
        │                         │
        ▼                         ▼
┌───────────────────────────────────────────┐
│          CloudMap Namespace               │
│  petclinic.local                          │
│                                           │
│  - customers.petclinic.local:8080         │
│  - vets.petclinic.local:8080              │
│  - visits.petclinic.local:8080            │
└───────────────────────────────────────────┘
```

### 두 가지 통신 경로

#### 1️⃣ **외부 → 내부 (ALB 경유)**
```
사용자 → CloudFront → API Gateway → ALB → ECS 서비스
```
- **목적**: 외부 트래픽 수신
- **필요 리소스**: ALB, WAF, 보안 그룹 규칙
- **제거 불가**: 외부 접근을 위한 필수 구성

#### 2️⃣ **내부 ↔ 내부 (CloudMap 직접)**
```
ECS Service A → CloudMap DNS → ECS Service B
```
- **목적**: 마이크로서비스 간 통신
- **장점**: ALB 우회, 지연 시간 감소, 비용 절감
- **사용 중**: customers ↔ visits ↔ vets

#### 3️⃣ **Admin → Services (ALB 경유)**
```
Admin Server → ALB Public DNS → ECS Services (Actuator)
```
- **목적**: Spring Boot Admin의 헬스 체크 및 모니터링
- **이유**: Admin은 각 서비스의 `/actuator` 엔드포인트에 접근 필요
- **현재 구현**: `ALB_DNS_NAME` 환경 변수 사용

---

## ❌ 제거할 수 없는 항목

### 1. ALB 관련 코드
**위치**: `terraform/layers/07-application/main.tf`

```hcl
# ❌ 제거 불가
module "alb" {
  source = "../../modules/alb"
  
  enable_waf_rate_limiting = var.enable_alb_rate_limiting
  # ...
}
```

**이유**:
- 외부 트래픽 진입점으로 필수
- CloudFront/API Gateway가 ALB를 백엔드로 사용
- Admin 서버가 서비스 모니터링을 위해 ALB 사용

### 2. ALB WAF 설정
**위치**: `terraform/modules/alb/main.tf`

```hcl
# ❌ 제거 불가
resource "aws_wafv2_web_acl" "alb_rate_limit" {
  name  = "${var.name_prefix}-alb-waf"
  scope = "REGIONAL"
  
  # Rate Limiting
  # SQL Injection 차단
  # XSS 차단
}
```

**이유**:
- 외부 공격으로부터 보호 (DDoS, SQL Injection, XSS)
- Rate Limiting으로 악의적 트래픽 차단
- 프로덕션 환경의 필수 보안 계층

### 3. 보안 그룹 규칙 - ALB → ECS
**위치**: `terraform/layers/07-application/main.tf`

```hcl
# ❌ 제거 불가
resource "aws_security_group_rule" "alb_to_ecs" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = local.ecs_security_group_id
  source_security_group_id = module.alb.alb_security_group_id
  description              = "Allow ALB to access ECS tasks on port 8080"
}
```

**이유**:
- ALB가 ECS 타겟에 도달하려면 필수
- 외부 트래픽이 서비스에 도달하는 유일한 경로

### 4. Admin 포트 9090 규칙
**위치**: `terraform/layers/07-application/main.tf`

```hcl
# ❌ 제거 불가
resource "aws_security_group_rule" "alb_to_ecs_admin" {
  type                     = "ingress"
  from_port                = 9090
  to_port                  = 9090
  protocol                 = "tcp"
  security_group_id        = local.ecs_security_group_id
  source_security_group_id = module.alb.alb_security_group_id
  description              = "Allow ALB to access Admin service on port 9090"
}
```

**이유**:
- Admin 서비스의 외부 접근용
- Admin UI 접근 경로: CloudFront → ALB:9090 → Admin Service

---

## ✅ 제거 가능한 항목

### 1. ~~Admin → ALB 간접 Actuator 접근 (선택적)~~

**현재 구현**:
```hcl
# terraform/layers/07-application/locals.tf (line 76-78)
{
  name  = "ALB_DNS_NAME"
  value = module.alb.alb_dns_name  # Admin이 ALB를 통해 actuator 접근
}
```

**현재 방식**:
```
Admin → Internet (NAT) → ALB Public DNS → ECS Services (/actuator)
```

**개선 가능 방식** (선택적):
```
Admin → CloudMap DNS → ECS Services (/actuator)
```

#### 변경 시 장점
- ✅ NAT Gateway 비용 절감
- ✅ 지연 시간 감소
- ✅ 내부 네트워크만 사용

#### 변경 시 단점
- ⚠️ Admin 애플리케이션 코드 수정 필요
- ⚠️ CloudMap 기반 서비스 디스커버리 로직 추가 필요
- ⚠️ 테스트 및 검증 필요

#### 변경 방법
```yaml
# Admin application.yml
spring:
  boot:
    admin:
      discovery:
        enabled: true
        services:
          - name: customers
            url: http://customers.petclinic.local:8080/api/customers
          - name: vets
            url: http://vets.petclinic.local:8080/api/vets
          - name: visits
            url: http://visits.petclinic.local:8080/api/visits
```

```hcl
# Terraform 변경
locals {
  admin_environment = [
    {
      name  = "SPRING_PROFILES_ACTIVE"
      value = "aws,cloudmap"  # cloudmap 프로파일 추가
    },
    {
      name  = "CLOUDMAP_NAMESPACE"
      value = local.cloudmap_namespace_name  # ALB_DNS_NAME 대신
    }
  ]
}
```

### 2. ~~HTTP Egress 규칙 (Admin → Internet)~~

**위치**: `terraform/layers/07-application/main.tf` (line 97-108)

```hcl
# ⚠️ 조건부 제거 가능 (Admin이 CloudMap 사용하는 경우)
resource "aws_security_group_rule" "ecs_to_internet_http" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = local.ecs_security_group_id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow ECS to access internet on port 80 (for Admin to access ALB public DNS)"
}
```

**제거 조건**:
- Admin 서버가 CloudMap을 통해 다른 서비스에 직접 접근하도록 변경한 경우
- 다른 서비스가 외부 API 호출이 없는 경우

**주의**:
- 만약 서비스가 외부 API(예: AWS API, 써드파티 API)를 호출한다면 **제거 불가**

---

## 🔄 현재 사용 중인 CloudMap

### CloudMap 활용 현황

```hcl
# ECS 서비스 정의
resource "aws_ecs_service" "services" {
  for_each = local.services
  
  # CloudMap 서비스 디스커버리 등록
  service_registries {
    registry_arn = local.cloudmap_service_arns[each.key]
  }
}
```

**효과**:
- ✅ Customers → Visits 호출: `http://visits.petclinic.local:8080`
- ✅ Visits → Vets 호출: `http://vets.petclinic.local:8080`
- ✅ ALB 우회로 지연 시간 감소
- ✅ ALB 데이터 전송 비용 절감

---

## 📋 제거 권장 사항

### 즉시 제거 가능: 없음

**결론**: CloudMap을 도입했지만, ALB는 여전히 외부 트래픽 진입점으로 필수입니다.

### 향후 최적화 고려사항

#### Option 1: Admin CloudMap 전환 (중간 난이도)
```
예상 절감: NAT Gateway 데이터 전송 비용 ~$5-10/월
작업량: 애플리케이션 코드 수정 + Terraform 변경
리스크: 중간 (테스트 필요)
```

**변경 파일**:
1. `spring-petclinic-admin-server/src/main/resources/application.yml`
2. `terraform/layers/07-application/locals.tf` (admin_environment)
3. `terraform/layers/07-application/main.tf` (HTTP egress 규칙)

#### Option 2: ALB 제거 (고난이도, 비권장)
```
예상 절감: ALB 비용 ~$20-30/월
작업량: API Gateway VPC Link + NLB 구성
리스크: 높음 (아키텍처 대규모 변경)
```

**필요 작업**:
1. Network Load Balancer 생성
2. API Gateway VPC Link 구성
3. CloudFront → API Gateway → VPC Link → NLB → ECS
4. WAF를 API Gateway 레벨로 이동

**비권장 이유**:
- ALB는 Layer 7 라우팅 기능 제공 (경로 기반 라우팅)
- WAF와 긴밀한 통합
- 헬스 체크 및 모니터링 편의성
- 비용 절감 대비 복잡도 증가

---

## 💡 최종 권장사항

### 현재 상태 유지 (권장)

**이유**:
1. **ALB는 필수**: 외부 트래픽 진입점
2. **WAF는 필수**: 프로덕션 보안
3. **보안 그룹 규칙 필수**: ALB ↔ ECS 통신
4. **CloudMap 이미 작동 중**: 마이크로서비스 간 통신 최적화

**현재 아키텍처의 장점**:
- ✅ 외부/내부 트래픽 분리
- ✅ 보안 계층 명확
- ✅ 서비스 간 통신 최적화
- ✅ 관리 용이성

### 향후 고려사항

**Phase 1 (선택적)**: Admin CloudMap 전환
- 난이도: 중
- 효과: 작은 비용 절감
- 시기: 애플리케이션 안정화 후

**Phase 2 (장기)**: API Gateway VPC Link
- 난이도: 높
- 효과: 중간 비용 절감
- 시기: 트래픽 증가 시 검토

---

## 📊 비용 분석

### 현재 아키텍처 월 비용 (예상)

| 항목 | 비용 | 필수 여부 |
|------|------|----------|
| **ALB** | $20-30 | ✅ 필수 (외부 진입점) |
| **WAF (ALB)** | $5-10 | ✅ 필수 (보안) |
| **CloudMap** | $1-2 | ✅ 사용 중 (내부 통신) |
| **NAT Gateway** | $30-50 | ⚠️ 부분 필수 (외부 API 호출) |
| **총계** | $56-92 | - |

### 최적화 후 예상 비용 (Admin CloudMap 전환 시)

| 항목 | 비용 | 변화 |
|------|------|------|
| **ALB** | $20-30 | 동일 |
| **WAF (ALB)** | $5-10 | 동일 |
| **CloudMap** | $1-2 | 동일 |
| **NAT Gateway** | $25-40 | ⬇️ $5-10 절감 (Admin 트래픽 감소) |
| **총계** | $51-82 | ⬇️ $5-10 절감 (9-11%) |

---

## 🎯 결론

**CloudMap 전환은 이미 완료되었고 효과적으로 작동 중입니다.**

현재 제거 가능한 불필요한 코드는 **없습니다**. 모든 ALB, WAF, 보안 그룹 규칙은 외부 트래픽 처리와 보안을 위해 필요합니다.

유일한 최적화 포인트는 **Admin 서버의 Actuator 접근 방식**을 ALB 경유에서 CloudMap 직접 접근으로 변경하는 것이며, 이는 선택적이고 애플리케이션 코드 수정이 필요합니다.

---

**작성일**: 2024-11-08  
**분석 대상**: PetClinic CloudMap 아키텍처  
**결론**: 현재 구성 유지 권장
