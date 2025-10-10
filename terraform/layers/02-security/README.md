# Security Layer (02-security)

## 개요

AWS Well-Architected 보안 원칙에 따른 네트워크 및 접근 제어 레이어입니다.

## 의존성

### 필수 의존성
- **01-network**: VPC, 서브넷 정보 필요

### 선택적 의존성
- **07-application**: ALB 보안 그룹 통합 시 필요 (Phase 2)

## 배포 단계

### Phase 1: 기본 보안 설정
```bash
# dev.tfvars 설정
enable_alb_integration = false
enable_role_based_policies = false

# 배포
terraform apply -var-file=../../../envs/dev.tfvars
```

### Phase 2: ALB 통합 (application 레이어 배포 후)
```bash
# dev.tfvars 업데이트
enable_alb_integration = true

# 재배포
terraform apply -var-file=../../../envs/dev.tfvars
```

## 생성 리소스

### 보안 그룹
- ECS Fargate 태스크용 보안 그룹 (security 모듈)
- Aurora MySQL 클러스터용 보안 그룹 (security 모듈)
- ALB용 보안 그룹 (security 모듈)
- VPC 엔드포인트용 보안 그룹 (endpoints 모듈)

### IAM 역할 및 정책
- ECS 태스크 실행 역할 (iam 모듈)
- ECS 태스크 역할 (iam 모듈)
- RDS 시크릿 접근 정책
- Parameter Store 접근 정책
- CloudWatch Logs 접근 정책

### VPC 엔드포인트
- S3 게이트웨이 엔드포인트 (endpoints 모듈)
- 인터페이스 엔드포인트: ECR, CloudWatch, SSM, Secrets Manager 등 (endpoints 모듈)

## Cross-Layer 참조

### 참조하는 레이어
```hcl
# Network 레이어 (필수)
data "terraform_remote_state" "network" {
  # VPC ID, VPC CIDR 참조
}

# Application 레이어 (선택적)
data "terraform_remote_state" "application" {
  # ALB 보안 그룹 ID 참조 (enable_alb_integration = true 시)
}
```

### 제공하는 출력값
```hcl
# 다른 레이어에서 참조 가능한 출력값
outputs = {
  ecs_security_group_id    = "sg-xxxxxxxxx"
  aurora_security_group_id = "sg-yyyyyyyyy"
  alb_security_group_id    = "sg-zzzzzzzzz"
  vpce_security_group_id   = "sg-aaaaaaaaa"
  
  ecs_task_execution_role_arn = "arn:aws:iam::..."
  ecs_task_role_arn          = "arn:aws:iam::..."
  
  rds_secret_access_policy_arn      = "arn:aws:iam::..."
  parameter_store_access_policy_arn = "arn:aws:iam::..."
  cloudwatch_logs_access_policy_arn = "arn:aws:iam::..."
}
```

## 주의사항

1. **배포 순서**: 반드시 01-network 레이어 이후에 배포
2. **ALB 통합**: application 레이어 배포 후 `enable_alb_integration = true`로 설정
3. **IAM 정책**: Phase 2에서 `enable_role_based_policies = true`로 세분화된 권한 적용
4. **변수 일관성**: 모든 레이어에서 `name_prefix`, `environment` 값 일치 필요

## 검증 방법

```bash
# 보안 그룹 확인
aws ec2 describe-security-groups --filters "Name=tag:Layer,Values=02-security"

# IAM 역할 확인
aws iam list-roles --query "Roles[?contains(RoleName, 'petclinic-dev')]"

# 정책 확인
aws iam list-policies --scope Local --query "Policies[?contains(PolicyName, 'petclinic-dev')]"
```