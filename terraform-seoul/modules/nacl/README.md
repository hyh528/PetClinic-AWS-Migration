# Network ACL 모듈

## 🏗️ 클린 아키텍처 & Well-Architected Framework 완전 적용

### **클린 코드 원칙 적용**
- **DRY (Don't Repeat Yourself)**: 데이터 기반 규칙 생성으로 중복 완전 제거
- **Single Responsibility**: 네트워크 수준 보안만 담당
- **Declarative Configuration**: 선언적 설정으로 가독성 극대화
- **Functional Programming**: `flatten()`, `for_each` 활용한 함수형 스타일

### **클린 아키텍처 원칙**
- **의존성 역전**: 외부 설정에 의존, 구체적 구현에 독립적
- **인터페이스 분리**: 각 서브넷 타입별 독립적 인터페이스
- **개방-폐쇄**: 새로운 서브넷 타입 추가 시 기존 코드 수정 없음

### **AWS Well-Architected Framework 6가지 기둥**

#### 1. **Security (보안)**
```hcl
# 계층적 보안 (Defense in Depth)
- NACL (서브넷 수준) + Security Group (인스턴스 수준)
- 최소 권한 원칙 (Least Privilege)
- 명시적 거부 규칙 (Explicit Deny)
- VPC Flow Logs 모니터링
```

#### 2. **Reliability (안정성)**
```hcl
# 예측 가능한 네트워크 동작
- 일관된 규칙 구조
- Multi-AZ 지원
- 장애 격리 (서브넷 타입별 분리)
```

#### 3. **Performance Efficiency (성능 효율성)**
```hcl
# 최적화된 네트워크 설정
- AWS 권장 에페메랄 포트 범위 (32768-65535)
- 최소한의 필요 규칙만 적용
- 효율적인 규칙 구조
```

#### 4. **Cost Optimization (비용 최적화)**
```hcl
# 비용 효율적 설계
- 상세한 리소스 태깅
- 불필요한 규칙 제거
- 자동화된 관리
```

#### 5. **Operational Excellence (운영 우수성)**
```hcl
# 운영 효율성
- Infrastructure as Code
- 자동화된 모니터링
- 자체 문서화 코드
```

#### 6. **Sustainability (지속 가능성)**
```hcl
# 지속 가능한 설계
- 최소한의 리소스 사용
- 자동화된 관리로 운영 오버헤드 감소
```

## 📋 To-Be 아키텍처 준수

### **3계층 네트워크 아키텍처**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Public Tier   │    │ Private App Tier│    │ Private DB Tier │
│     (DMZ)       │    │  (Application)  │    │     (Data)      │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ • ALB           │    │ • ECS Fargate   │    │ • Aurora MySQL  │
│ • NAT Gateway   │    │ • Spring Boot   │    │ • Maximum       │
│ • Internet      │    │ • Admin Server  │    │   Isolation     │
│   Access        │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
        │                       │                       │
        ▼                       ▼                       ▼
   Public NACL            Private App NACL        Private DB NACL
   (Standard)              (Medium Security)      (High Security)
```

### **보안 레벨별 규칙**

#### **Public Subnet (DMZ Layer)**
- **Inbound**: HTTP(80), HTTPS(443), Ephemeral ports
- **Outbound**: HTTP(80), HTTPS(443), ALB→ECS(8080), Ephemeral ports
- **보안 레벨**: Standard

#### **Private App Subnet (Application Layer)**
- **Inbound**: Spring Boot(8080), Admin(9090), Ephemeral ports
- **Outbound**: HTTPS(443), MySQL(3306), VPC endpoints, Ephemeral ports
- **보안 레벨**: Medium

#### **Private DB Subnet (Data Layer)**
- **Inbound**: MySQL(3306) from App tier only
- **Outbound**: MySQL responses to App tier only
- **보안 레벨**: High (Maximum Isolation)

## 🚀 사용 방법

### **기본 사용법**
```hcl
module "nacl" {
  source = "./modules/nacl"

  # 필수 설정
  vpc_id                  = "vpc-12345678"
  vpc_cidr               = "10.0.0.0/16"
  public_subnet_ids      = ["subnet-12345678", "subnet-87654321"]
  private_app_subnet_ids = ["subnet-11111111", "subnet-22222222"]
  private_db_subnet_ids  = ["subnet-33333333", "subnet-44444444"]

  # 기본 설정
  name_prefix = "petclinic-dev"
  environment = "dev"

  # Well-Architected Framework 태그
  cost_center = "training"
  owner       = "platform-team"

  tags = {
    Project = "petclinic"
    Team    = "infrastructure"
  }
}
```

### **보안 강화 설정 (프로덕션)**
```hcl
module "nacl" {
  source = "./modules/nacl"

  # ... 기본 설정 ...

  # 보안 강화
  enable_flow_logs         = true
  enable_security_monitoring = true
  production_hardening     = true
  enable_strict_mode       = true
  
  # 모니터링 설정
  security_alert_threshold = 50
  alarm_actions           = ["arn:aws:sns:ap-northeast-2:123456789012:security-alerts"]
  
  # Flow Logs 설정
  flow_logs_role_arn      = "arn:aws:iam::123456789012:role/flowlogsRole"
  flow_logs_destination   = "arn:aws:logs:ap-northeast-2:123456789012:log-group:VPCFlowLogs"
}
```

### **개발 환경 설정**
```hcl
module "nacl" {
  source = "./modules/nacl"

  # ... 기본 설정 ...

  # 개발 환경 설정
  development_mode    = true
  enable_debug_rules  = true
  enable_flow_logs    = false
  
  # 성능 최적화
  optimize_for_performance = true
}
```

## 📊 출력값 활용

### **NACL ID 참조**
```hcl
# 다른 모듈에서 NACL ID 참조
resource "aws_security_group_rule" "example" {
  # NACL과 연동된 보안 그룹 규칙
  source_security_group_id = module.nacl.nacl_ids["private_app"]
}
```

### **모니터링 정보 활용**
```hcl
# 모니터링 대시보드에서 활용
output "security_dashboard_data" {
  value = {
    nacl_security_levels = module.nacl.security_configuration.security_levels
    rule_counts         = module.nacl.rule_counts
    monitoring_status   = module.nacl.monitoring_resources
  }
}
```

## 🔧 고급 설정

### **커스텀 포트 설정**
```hcl
module "nacl" {
  source = "./modules/nacl"

  # ... 기본 설정 ...

  custom_ports = {
    redis = {
      port        = 6379
      protocol    = "tcp"
      description = "Redis cache access"
    }
    elasticsearch = {
      port        = 9200
      protocol    = "tcp"
      description = "Elasticsearch API"
    }
  }
}
```

### **IPv6 지원**
```hcl
module "nacl" {
  source = "./modules/nacl"

  # ... 기본 설정 ...

  enable_ipv6      = true
  ipv6_cidr_block = "2001:db8::/56"
}
```

### **커스텀 CIDR 블록**
```hcl
module "nacl" {
  source = "./modules/nacl"

  # ... 기본 설정 ...

  allowed_cidr_blocks = {
    corporate_network = ["10.100.0.0/16", "10.200.0.0/16"]
    partner_network   = ["192.168.1.0/24"]
  }
}
```

## 🔍 모니터링 및 알람

### **VPC Flow Logs**
- 모든 NACL 트래픽 로깅
- CloudWatch Logs 또는 S3 저장
- 보안 분석 및 트러블슈팅

### **보안 알람**
- NACL 거부 연결 모니터링
- 임계값 초과 시 SNS 알림
- CloudWatch 메트릭 기반

### **대시보드**
- 실시간 트래픽 모니터링
- 보안 이벤트 시각화
- 성능 메트릭 추적

## 🎯 Best Practices

### **1. 보안 Best Practices**
- 최소 권한 원칙 적용
- 명시적 거부 규칙 사용
- 정기적인 규칙 검토
- Flow Logs 활성화

### **2. 성능 Best Practices**
- AWS 권장 에페메랄 포트 범위 사용
- 불필요한 규칙 제거
- 규칙 번호 체계적 관리

### **3. 운영 Best Practices**
- Infrastructure as Code 사용
- 자동화된 모니터링 설정
- 상세한 태깅 전략
- 정기적인 보안 감사

### **4. 비용 최적화 Best Practices**
- 리소스 태깅으로 비용 추적
- 불필요한 Flow Logs 비활성화
- 환경별 설정 차별화

## 🔄 업그레이드 가이드

### **v1.0 → v2.0**
- 데이터 기반 규칙 구조로 변경
- Well-Architected Framework 완전 적용
- 클린 아키텍처 원칙 적용

### **마이그레이션 단계**
1. 기존 NACL 백업
2. 새 모듈로 점진적 교체
3. 규칙 검증 및 테스트
4. 모니터링 설정 확인

## 📚 참고 자료

- [AWS NACL Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [VPC Flow Logs](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html)
- [Clean Architecture Principles](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)

---

**이 모듈은 클린 코드, 클린 아키텍처, AWS Well-Architected Framework의 모든 원칙을 준수하여 설계되었습니다.** 🚀