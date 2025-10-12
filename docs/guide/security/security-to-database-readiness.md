# Security → Database 레이어 전환 준비도 분석

## 현재 Security 레이어 완성도

### Database 레이어에 필요한 보안 설정 (완료)

#### 1. **네트워크 보안** ✅
```terraform
# DB 보안 그룹 - Aurora 접근 제어
module "sg_db" {
  # ECS App → Aurora MySQL (3306) 만 허용
  # 외부 인터넷 접근 완전 차단
}

# Private DB Subnet NACL - 네트워크 레벨 보안
module "nacl_private_db" {
  # App 서브넷에서만 MySQL 트래픽 허용
  # 인터넷 접근 제한
}
```

#### 2. **데이터 암호화** ✅
```terraform
# Secrets Manager - DB 비밀번호 안전 저장
module "db_password_secret" {
  secret_name = "petclinic/dev/db-password"
  # KMS 암호화, 자동 로테이션 지원
}
```

#### 3. **접근 제어** ✅
```terraform
# IAM 역할 및 정책 (ECS 태스크용)
# - Secrets Manager 읽기 권한
# - CloudWatch Logs 쓰기 권한
# - Parameter Store 읽기 권한
```

#### 4. **VPC 엔드포인트** ✅
```terraform
# Aurora 관련 AWS 서비스 접근
# - CloudWatch (모니터링)
# - KMS (암호화 키)
# - Secrets Manager (비밀번호)
```

## Database 레이어 구현 시 필요한 것들

### **Database 모듈에서 참조할 Security 출력값들**

```terraform
# Security 레이어에서 제공해야 할 출력값들
output "db_security_group_id" {
  value = module.sg_db.security_group_id
}

output "db_subnet_group_name" {
  # Network 레이어에서 가져와야 함
  value = data.terraform_remote_state.network.outputs.db_subnet_group_name
}

output "db_password_secret_arn" {
  value = module.db_password_secret.secret_arn
}

output "kms_key_id" {
  # Aurora 암호화용 KMS 키
  value = "alias/aws/rds"  # 기본 AWS 관리 키 사용
}
```

### **Database 레이어에서 구현할 보안 설정들**

#### 1. **Aurora 클러스터 보안 설정**
```terraform
resource "aws_rds_cluster" "aurora" {
  # 네트워크 보안
  vpc_security_group_ids = [var.db_security_group_id]
  db_subnet_group_name   = var.db_subnet_group_name
  
  # 데이터 암호화
  storage_encrypted = true
  kms_key_id       = var.kms_key_id
  
  # 접근 제어
  manage_master_user_password = true
  master_user_secret_kms_key_id = var.kms_key_id
  
  # 백업 및 복구
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  
  # 모니터링
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]
  monitoring_interval = 60
}
```

#### 2. **Performance Insights 보안**
```terraform
# 성능 모니터링 데이터 암호화
performance_insights_enabled = true
performance_insights_kms_key_id = var.kms_key_id
```

#### 3. **Enhanced Monitoring IAM 역할**
```terraform
resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "rds-monitoring-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
    }]
  })
}
```

## 🚦 **전환 준비도 평가**

### ✅ **준비 완료된 항목들**
- [x] DB 보안 그룹 (sg_db)
- [x] DB 서브넷 NACL (nacl_private_db)  
- [x] Secrets Manager (db_password_secret)
- [x] VPC 엔드포인트 (CloudWatch, KMS)
- [x] IAM 기본 정책

### ⚠️ **추가 필요한 항목들**

#### 1. **Security 레이어 출력값 추가**
```terraform
# terraform/envs/dev/security/outputs.tf에 추가 필요
output "db_security_group_id" {
  description = "Database 보안 그룹 ID"
  value       = module.sg_db.security_group_id
}

output "db_password_secret_arn" {
  description = "데이터베이스 비밀번호 Secret ARN"
  value       = module.db_password_secret.secret_arn
}
```

#### 2. **Database 모듈 생성**
```bash
# 필요한 디렉토리 구조
terraform/modules/database/
├── main.tf          # Aurora 클러스터 정의
├── variables.tf     # 입력 변수
├── outputs.tf       # 출력값
└── versions.tf      # Provider 버전
```

#### 3. **Database 레이어 환경 설정**
```terraform
# terraform/envs/dev/database/main.tf 생성 필요
module "database" {
  source = "../../../modules/database"
  
  # Security 레이어에서 가져올 값들
  db_security_group_id = data.terraform_remote_state.security.outputs.db_security_group_id
  db_password_secret_arn = data.terraform_remote_state.security.outputs.db_password_secret_arn
  
  # Network 레이어에서 가져올 값들
  db_subnet_group_name = data.terraform_remote_state.network.outputs.db_subnet_group_name
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id
}
```

## **결론 및 권장사항**

### 🟢 **Database 레이어 전환 가능**
현재 Security 레이어는 Database 레이어에 필요한 **핵심 보안 설정들이 모두 완료**되어 있습니다.

### **다음 단계 작업 순서**
1. **Security 레이어 출력값 추가** (5분) - 영현이 구현함
2. **Database 모듈 생성** (30분) - 준제 작업 범위
3. **Database 레이어 환경 설정** (15분) - 준제 작업 범위
4. **통합 테스트** (15분) - 준제 작업 완료 후 예정

### **즉시 진행 가능한 이유**
- ✅ 네트워크 보안: DB 보안 그룹, NACL 완료
- ✅ 데이터 보안: Secrets Manager, KMS 준비
- ✅ 접근 제어: IAM 역할 및 정책 완료
- ✅ 모니터링: CloudWatch, VPC 엔드포인트 완료

**결론: Security 레이어는 Database 레이어 구현에 충분한 보안 기반을 제공하고 있습니다!**