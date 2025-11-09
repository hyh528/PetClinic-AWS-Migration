# 🧹 Terraform 코드 클린업 계획

> 포트폴리오 품질로 업그레이드: 하드코딩 제거, 베스트 프랙티스 적용, 주석 정리

## 📋 목차
1. [현재 상태 분석](#현재-상태-분석)
2. [클린업 체크리스트](#클린업-체크리스트)
3. [레이어별 개선 사항](#레이어별-개선-사항)
4. [베스트 프랙티스 적용](#베스트-프랙티스-적용)
5. [주석 가이드라인](#주석-가이드라인)

---

## 현재 상태 분석

### ✅ 잘 되어 있는 부분
- ✅ **레이어 구조**: 명확한 책임 분리
- ✅ **모듈화**: 재사용 가능한 모듈 구조
- ✅ **Remote State**: S3 백엔드 + DynamoDB 잠금
- ✅ **변수 관리**: tfvars 파일로 환경 분리
- ✅ **태깅 전략**: 일관된 태그 적용

### ⚠️ 개선 필요 부분

#### 1. 하드코딩 (소량 발견)
```hcl
# terraform/layers/07-application/github-actions.tf:164
Resource = "arn:aws:dynamodb:ap-southeast-2:897722691159:table/petclinic-tf-locks-sydney-dev"
```

#### 2. 장황한 주석
```hcl
# 백엔드 유형만 선언합니다. 구체적인 백엔드 구성 값(버킷, key, region, dynamodb_table 등)은
# init 시점에 -backend-config 파일들로 주입합니다(부분 구성, partial configuration).
# 이렇게 하면 환경별 state key를 소스에 하드코딩하지 않으면서도 중앙 스테이트를 사용합니다.
```
→ **간결화 필요**

#### 3. 일관성 없는 주석 스타일
- 일부 파일: 상세한 설명
- 일부 파일: 주석 없음
- 일부 파일: 중복 설명

---

## 클린업 체크리스트

### Phase 1: 하드코딩 제거 ✅
- [ ] GitHub Actions ARN에서 계정 ID 제거
- [ ] 모든 리전 하드코딩 검토
- [ ] IP 주소 하드코딩 검토 (10.0.x.x)
- [ ] 리소스 이름 하드코딩 검토

### Phase 2: 주석 정리 📝
- [ ] Backend 파일 주석 간소화
- [ ] 불필요한 설명 주석 제거
- [ ] 중요한 비즈니스 로직만 주석 유지
- [ ] 주석 스타일 통일

### Phase 3: 베스트 프랙티스 적용 🏆
- [ ] 변수 검증 규칙 추가
- [ ] 민감 정보 마킹 (sensitive = true)
- [ ] 출력 값 설명 추가
- [ ] 리소스 명명 규칙 통일
- [ ] depends_on 명시적 의존성 정리

### Phase 4: 문서화 📚
- [ ] 각 레이어에 간결한 README.md
- [ ] 변수 설명 개선
- [ ] 출력 값 용도 명시
- [ ] 예제 tfvars 제공

---

## 레이어별 개선 사항

### Layer 01: Network
**현재 상태**: ⭐⭐⭐⭐ (4/5)

**개선 사항**:
```hcl
# ❌ Before: 장황한 주석
# VPC 생성
# 이 VPC는 PetClinic 애플리케이션의 모든 리소스를 포함합니다
# CIDR 블록은 10.0.0.0/16으로 설정되어 있으며
# 최대 65,536개의 IP 주소를 사용할 수 있습니다

# ✅ After: 간결한 주석
# VPC: PetClinic 애플리케이션 네트워크 (10.0.0.0/16)
```

**체크리스트**:
- [ ] CIDR 블록 변수화 확인
- [ ] 서브넷 개수 동적 계산 확인
- [ ] 주석 간소화

### Layer 02: Security
**현재 상태**: ⭐⭐⭐⭐ (4/5)

**개선 사항**:
```hcl
# ✅ Good: 보안 그룹 규칙 명확
resource "aws_security_group_rule" "ecs_to_rds" {
  description = "ECS to RDS MySQL access"
  # ...
}

# ⚠️ Improve: IAM 정책 주석 추가
resource "aws_iam_role_policy" "ecs_task_policy" {
  # 추가: 정책 목적 및 권한 범위 설명
}
```

**체크리스트**:
- [ ] 보안 그룹 규칙 description 확인
- [ ] IAM 정책 목적 주석 추가
- [ ] 최소 권한 원칙 검토

### Layer 03: Database
**현재 상태**: ⭐⭐⭐⭐⭐ (5/5)

**우수 사례**:
```hcl
# RDS Data API 활성화 로직
resource "null_resource" "enable_data_api" {
  # Aurora Serverless v2는 enable_http_endpoint 속성 미지원
  # AWS CLI로 수동 활성화 필요
  provisioner "local-exec" {
    command = "aws rds enable-http-endpoint ..."
  }
}
```

**체크리스트**:
- [x] 백업 설정 변수화
- [x] 암호화 설정 변수화
- [x] Data API 활성화 로직 명확

### Layer 04: Parameter Store
**현재 상태**: ⭐⭐⭐⭐ (4/5)

**개선 사항**:
```hcl
# ❌ Before
resource "aws_ssm_parameter" "db_url" {
  name  = "/petclinic/${var.environment}/db/url"
  value = "..."
}

# ✅ After: 주석 추가
resource "aws_ssm_parameter" "db_url" {
  name  = "/petclinic/${var.environment}/db/url"
  value = "..."
  
  # 용도: ECS 태스크가 DB 연결 시 사용
  # 참조: Layer 07 (Application)
}
```

### Layer 05: CloudMap
**현재 상태**: ⭐⭐⭐⭐⭐ (5/5)

**우수 사례**:
- 명확한 서비스 디스커버리 설정
- 네임스페이스 구조 명확
- TTL 설정 적절

### Layer 06: Lambda GenAI
**현재 상태**: ⭐⭐⭐⭐ (4/5)

**개선 사항**:
```python
# lambda_function.py 내 하드코딩 리전
bedrock_client = boto3.client('bedrock-runtime', region_name='us-west-2')
```
→ **환경 변수로 변경**

### Layer 07: Application
**현재 상태**: ⭐⭐⭐⭐ (4/5)

**개선 사항**:
1. **GitHub Actions ARN 하드코딩**
```hcl
# ❌ Before
Resource = "arn:aws:dynamodb:ap-southeast-2:897722691159:table/..."

# ✅ After
Resource = "arn:aws:dynamodb:${var.backend_region}:${data.aws_caller_identity.current.account_id}:table/${var.backend_dynamodb_table}"
```

2. **보안 그룹 규칙 주석 개선**
```hcl
# ✅ Good
resource "aws_security_group_rule" "alb_to_ecs" {
  description = "ALB to ECS tasks on port 8080"
  # ...
}

# ⚠️ Improve: 왜 필요한지 추가
resource "aws_security_group_rule" "ecs_to_internet_http" {
  description = "ECS egress for NAT Gateway"
  # Admin 서버가 ALB 공개 DNS를 통해 다른 서비스 actuator 접근 시 사용
}
```

### Layer 08: API Gateway
**현재 상태**: ⭐⭐⭐⭐⭐ (5/5)

**우수 사례**:
- WAF 통합 명확
- Rate Limiting 설정 잘 구성
- Lambda 통합 깔끔

### Layer 09: AWS Native
**현재 상태**: ⭐⭐⭐⭐ (4/5)

### Layer 10: Monitoring
**현재 상태**: ⭐⭐⭐⭐ (4/5)

**개선 사항**:
```hcl
# ✅ After: 알람 임계값에 비즈니스 의미 추가
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "ecs-cpu-high"
  threshold           = 80  # CPU 80% 초과 시 스케일링 고려
  evaluation_periods  = 2    # 10분간(5분×2) 지속 시 알람
}
```

### Layer 11: Frontend (CloudFront)
**현재 상태**: ⭐⭐⭐⭐⭐ (5/5)

### Layer 12: Notification
**현재 상태**: ⭐⭐⭐⭐⭐ (5/5)

---

## 베스트 프랙티스 적용

### 1. 변수 검증
```hcl
# ✅ 변수 제약 조건 추가
variable "environment" {
  type        = string
  description = "Environment name (dev, staging, prod)"
  
  validation {
    condition     = can(regex("^(dev|staging|prod)$", var.environment))
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "instance_class" {
  type        = string
  description = "RDS instance class"
  
  validation {
    condition     = can(regex("^db\\.", var.instance_class))
    error_message = "Instance class must start with 'db.'."
  }
}
```

### 2. 민감 정보 보호
```hcl
# ✅ 민감 정보 마킹
variable "db_password" {
  type        = string
  description = "Database master password"
  sensitive   = true
}

output "db_endpoint" {
  value       = aws_rds_cluster.this.endpoint
  description = "Database cluster endpoint"
  sensitive   = false  # 엔드포인트는 민감하지 않음
}

output "db_password_secret_arn" {
  value       = aws_rds_cluster.this.master_user_secret[0].secret_arn
  description = "ARN of Secrets Manager secret containing DB password"
  sensitive   = true  # 시크릿 ARN은 민감
}
```

### 3. 명명 규칙 통일
```hcl
# ✅ 일관된 명명 규칙
resource "aws_ecs_service" "services" {
  name = "${var.name_prefix}-${each.key}-service"
  # petclinic-dev-customers-service
}

resource "aws_cloudwatch_log_group" "services" {
  name = "/ecs/${var.name_prefix}-${each.key}"
  # /ecs/petclinic-dev-customers
}

resource "aws_lb_target_group" "services" {
  name = "${var.name_prefix}-${each.key}-tg"
  # petclinic-dev-customers-tg (최대 32자 제한 고려)
}
```

### 4. 태그 전략
```hcl
# ✅ 계층적 태그 구조
locals {
  common_tags = {
    Project     = "PetClinic"
    ManagedBy   = "Terraform"
    Environment = var.environment
    Repository  = "github.com/your-org/petclinic"
  }
  
  layer_tags = merge(local.common_tags, {
    Layer     = "07-application"
    Component = "ecs-services"
  })
  
  service_tags = merge(local.layer_tags, {
    Service = "customers"
    Port    = "8080"
  })
}
```

### 5. 출력 값 구조화
```hcl
# ✅ 명확한 출력 값
output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "VPC ID for resource association"
}

output "private_subnet_ids" {
  value       = module.vpc.private_subnet_ids
  description = "Private subnet IDs for ECS tasks and RDS"
}

output "public_subnet_ids" {
  value       = module.vpc.public_subnet_ids
  description = "Public subnet IDs for ALB and NAT Gateway"
}

# ✅ 복잡한 출력은 객체로 그룹화
output "database" {
  value = {
    cluster_arn      = module.aurora.cluster_arn
    endpoint         = module.aurora.endpoint
    reader_endpoint  = module.aurora.reader_endpoint
    port             = module.aurora.port
    secret_arn       = module.aurora.master_user_secret_arn
  }
  description = "Database cluster information"
}
```

### 6. depends_on 사용 최소화
```hcl
# ❌ Avoid: 불필요한 명시적 의존성
resource "aws_ecs_service" "app" {
  depends_on = [
    aws_lb.alb,
    aws_lb_listener.http,
    aws_lb_target_group.app
  ]
}

# ✅ Prefer: Terraform이 자동으로 의존성 파악
resource "aws_ecs_service" "app" {
  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn  # 암묵적 의존성
  }
  # depends_on 생략 - Terraform이 자동 처리
}

# ✅ Acceptable: 실제 필요한 경우만 사용
resource "null_resource" "enable_data_api" {
  depends_on = [
    aws_rds_cluster.this,
    aws_rds_cluster_instance.writer  # 인스턴스 생성 후 실행 보장
  ]
}
```

---

## 주석 가이드라인

### 주석 원칙
1. **코드가 무엇을 하는지 설명하지 말 것** (코드 자체가 설명)
2. **왜 이렇게 했는지 설명할 것** (비즈니스 로직, 제약사항)
3. **간결하게** (한 줄로 충분하면 한 줄로)
4. **중요한 것만** (trivial한 내용은 생략)

### 주석 스타일 가이드

#### ✅ Good Examples

```hcl
# VPC: 10.0.0.0/16 CIDR, 3 AZs
module "vpc" {
  source = "..."
}

# Aurora Serverless v2는 enable_http_endpoint 미지원
# AWS CLI로 수동 활성화 필요
resource "null_resource" "enable_data_api" {
  provisioner "local-exec" {
    command = "aws rds enable-http-endpoint ..."
  }
}

# Admin 서버가 ALB를 통해 다른 서비스 actuator 접근
resource "aws_security_group_rule" "ecs_to_internet_http" {
  description = "ECS egress for ALB access"
  # ...
}
```

#### ❌ Bad Examples

```hcl
# VPC 생성
# 이 VPC는 PetClinic 애플리케이션의 모든 리소스를 포함합니다
# CIDR 블록은 10.0.0.0/16으로 설정되어 있으며...
# (너무 장황)

# 보안 그룹 규칙
resource "aws_security_group_rule" "example" {
  # (무의미한 주석)
}

# 이 리소스는 ECS 서비스를 생성합니다
resource "aws_ecs_service" "app" {
  # (코드가 이미 설명하고 있음)
}
```

### Backend 파일 표준 주석

```hcl
# ✅ 간결한 Backend 주석
terraform {
  backend "s3" {
    # 설정은 terraform init -backend-config=../../backend.hcl로 주입
  }
}
```

### 파일 헤더 표준

```hcl
# =============================================================================
# Layer 07: Application Infrastructure
# =============================================================================
# Purpose: ECS services, ALB, ECR repositories for PetClinic microservices
# Dependencies: layers/01-network, layers/02-security, layers/03-database
# Outputs: Service endpoints, ALB DNS, ECR URLs
```

---

## 실행 계획

### Phase 1: Quick Wins (1-2 hours)
1. ✅ Backend 주석 간소화 (모든 레이어)
2. ✅ 하드코딩된 ARN 수정 (Layer 07)
3. ✅ Lambda 리전 하드코딩 수정 (Layer 06)

### Phase 2: 주석 정리 (2-3 hours)
1. ✅ 장황한 주석 간소화
2. ✅ 중복 주석 제거
3. ✅ 비즈니스 로직 주석 추가
4. ✅ 파일 헤더 통일

### Phase 3: 베스트 프랙티스 (3-4 hours)
1. ✅ 변수 검증 규칙 추가
2. ✅ 민감 정보 마킹
3. ✅ 출력 값 설명 개선
4. ✅ 명명 규칙 검토

### Phase 4: 문서화 (2-3 hours)
1. ✅ 레이어별 README.md
2. ✅ 변수 예제 tfvars
3. ✅ 아키텍처 다이어그램 업데이트

---

## 검증 체크리스트

### 코드 품질
- [ ] `terraform fmt` 통과 (모든 레이어)
- [ ] `terraform validate` 통과 (모든 레이어)
- [ ] `tflint` 검사 통과
- [ ] 하드코딩 없음 (grep 검증)
- [ ] TODO/FIXME 주석 없음

### 문서화
- [ ] 모든 변수에 description
- [ ] 모든 출력에 description
- [ ] 레이어별 README.md
- [ ] 주석 스타일 일관성

### 보안
- [ ] 민감 정보 sensitive = true
- [ ] IAM 최소 권한 원칙
- [ ] 보안 그룹 규칙 description

### 포트폴리오 준비
- [ ] 코드 가독성 우수
- [ ] 베스트 프랙티스 준수
- [ ] 명확한 구조와 설명
- [ ] 재사용 가능한 모듈

---

## 참고 자료

- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [Terraform Style Guide](https://www.terraform.io/docs/language/syntax/style.html)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Terraform Module Best Practices](https://www.terraform.io/docs/language/modules/develop/index.html)

---

**작성일**: 2024-11-08  
**목표**: 포트폴리오 수준의 Terraform 코드 품질  
**예상 소요 시간**: 8-12 시간
