# 🗄️ Database 레이어 구현 가이드 (준제용)

## 개요
Security 레이어가 완료되어 Database 레이어 작업을 시작할 수 있습니다. 
이 문서는 준제가 Aurora MySQL 클러스터를 구현하는데 필요한 모든 정보를 제공합니다.

## 구현 목표
- Aurora MySQL Serverless v2 클러스터 구축
- Multi-AZ 고가용성 설정
- 보안 강화 (암호화, 접근 제어)
- 모니터링 및 백업 설정

## 디렉토리 구조

### 생성해야 할 파일들
```
terraform/modules/database/
├── main.tf          # Aurora 클러스터 정의
├── variables.tf     # 입력 변수
└── outputs.tf       # 출력값


terraform/envs/dev/database/
├── main.tf          # Database 레이어 메인 설정
├── variables.tf     # 환경별 변수
├── dev.tfvars      # 개발 환경 값
├── backend.tf      # S3 백엔드 설정
└── providers.tf    # AWS Provider 설정
```

## Security 레이어에서 제공되는 리소스들

### 사용 가능한 출력값들
```terraform
# Security 레이어에서 가져올 수 있는 값들
data "terraform_remote_state" "security" {
  backend = "s3"
  config = {
    bucket = "petclinic-terraform-state-dev"
    key    = "dev/hwigwon/security/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# 사용 가능한 출력값들:
# - data.terraform_remote_state.security.outputs.db_security_group_id
# - data.terraform_remote_state.security.outputs.db_password_secret_arn
# - data.terraform_remote_state.security.outputs.db_password_secret_name
# - data.terraform_remote_state.security.outputs.vpc_endpoint_security_group_id
```

### Network 레이어에서 가져올 값들
```terraform
# Network 레이어에서 가져올 수 있는 값들
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "petclinic-terraform-state-dev"
    key    = "dev/yeonghyeon/network/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# 사용 가능한 출력값들:
# - data.terraform_remote_state.network.outputs.private_db_subnet_ids
# - data.terraform_remote_state.network.outputs.vpc_id
# - data.terraform_remote_state.network.outputs.vpc_cidr
```

## Database 모듈 구현 예시

### 1. terraform/modules/database/main.tf
```terraform
# Aurora MySQL 서브넷 그룹
resource "aws_db_subnet_group" "aurora" {
  name       = "${var.project_name}-${var.environment}-aurora-subnet-group"
  subnet_ids = var.private_db_subnet_ids

  tags = {
    Name        = "${var.project_name}-${var.environment}-aurora-subnet-group"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Aurora MySQL 클러스터
resource "aws_rds_cluster" "aurora" {
  cluster_identifier = "${var.project_name}-${var.environment}-aurora-cluster"
  engine             = "aurora-mysql"
  engine_version     = "8.0.mysql_aurora.3.04.0"
  engine_mode        = "provisioned"

  # 네트워크 설정
  vpc_security_group_ids = [var.db_security_group_id]
  db_subnet_group_name   = aws_db_subnet_group.aurora.name
  availability_zones     = var.availability_zones

  # 데이터베이스 설정
  database_name   = var.database_name
  master_username = var.master_username

  # 비밀번호 관리 (Secrets Manager 통합)
  manage_master_user_password = true
  master_user_secret_kms_key_id = var.kms_key_id

  # 보안 설정
  storage_encrypted = true
  kms_key_id       = var.kms_key_id

  # 백업 설정
  backup_retention_period = var.backup_retention_period
  backup_window          = var.backup_window
  maintenance_window     = var.maintenance_window

  # 모니터링
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]
  monitoring_interval            = 60
  monitoring_role_arn           = aws_iam_role.rds_enhanced_monitoring.arn

  # Performance Insights
  performance_insights_enabled    = true
  performance_insights_kms_key_id = var.kms_key_id

  # Serverless v2 설정
  serverlessv2_scaling_configuration {
    max_capacity = var.max_capacity
    min_capacity = var.min_capacity
  }

  # 삭제 방지
  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot

  tags = {
    Name        = "${var.project_name}-${var.environment}-aurora-cluster"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Aurora 클러스터 인스턴스 (Writer)
resource "aws_rds_cluster_instance" "aurora_writer" {
  identifier         = "${var.project_name}-${var.environment}-aurora-writer"
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.aurora.engine
  engine_version     = aws_rds_cluster.aurora.engine_version

  # 모니터링
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_enhanced_monitoring.arn

  # Performance Insights
  performance_insights_enabled    = true
  performance_insights_kms_key_id = var.kms_key_id

  tags = {
    Name        = "${var.project_name}-${var.environment}-aurora-writer"
    Project     = var.project_name
    Environment = var.environment
    Role        = "writer"
    ManagedBy   = "terraform"
  }
}

# Aurora 클러스터 인스턴스 (Reader)
resource "aws_rds_cluster_instance" "aurora_reader" {
  identifier         = "${var.project_name}-${var.environment}-aurora-reader"
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.aurora.engine
  engine_version     = aws_rds_cluster.aurora.engine_version

  # 모니터링
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_enhanced_monitoring.arn

  # Performance Insights
  performance_insights_enabled    = true
  performance_insights_kms_key_id = var.kms_key_id

  tags = {
    Name        = "${var.project_name}-${var.environment}-aurora-reader"
    Project     = var.project_name
    Environment = var.environment
    Role        = "reader"
    ManagedBy   = "terraform"
  }
}

# Enhanced Monitoring IAM 역할
resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "${var.project_name}-${var.environment}-rds-monitoring-role"

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

  tags = {
    Name        = "${var.project_name}-${var.environment}-rds-monitoring-role"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Enhanced Monitoring IAM 정책 연결
resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
```

### 2. terraform/modules/database/variables.tf
```terraform
# 기본 변수들
variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "environment" {
  description = "환경 (dev, staging, prod)"
  type        = string
}

# 네트워크 설정
variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_db_subnet_ids" {
  description = "Private DB 서브넷 ID 목록"
  type        = list(string)
}

variable "db_security_group_id" {
  description = "데이터베이스 보안 그룹 ID"
  type        = string
}

variable "availability_zones" {
  description = "가용 영역 목록"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}

# 데이터베이스 설정
variable "database_name" {
  description = "초기 데이터베이스 이름"
  type        = string
  default     = "petclinic"
}

variable "master_username" {
  description = "마스터 사용자 이름"
  type        = string
  default     = "admin"
}

# 보안 설정
variable "kms_key_id" {
  description = "KMS 키 ID (암호화용)"
  type        = string
  default     = "alias/aws/rds"
}

# Serverless v2 설정
variable "min_capacity" {
  description = "최소 ACU (Aurora Capacity Unit)"
  type        = number
  default     = 0.5
}

variable "max_capacity" {
  description = "최대 ACU (Aurora Capacity Unit)"
  type        = number
  default     = 1.0
}

# 백업 설정
variable "backup_retention_period" {
  description = "백업 보존 기간 (일)"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "백업 윈도우 (UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "유지보수 윈도우 (UTC)"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

# 보호 설정
variable "deletion_protection" {
  description = "삭제 방지 활성화"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "최종 스냅샷 건너뛰기 (개발 환경용)"
  type        = bool
  default     = false
}
```

### 3. terraform/modules/database/outputs.tf
```terraform
# Aurora 클러스터 정보
output "aurora_cluster_id" {
  description = "Aurora 클러스터 ID"
  value       = aws_rds_cluster.aurora.id
}

output "aurora_cluster_arn" {
  description = "Aurora 클러스터 ARN"
  value       = aws_rds_cluster.aurora.arn
}

# 엔드포인트 정보
output "aurora_cluster_endpoint" {
  description = "Aurora 클러스터 엔드포인트 (Writer)"
  value       = aws_rds_cluster.aurora.endpoint
}

output "aurora_reader_endpoint" {
  description = "Aurora 리더 엔드포인트"
  value       = aws_rds_cluster.aurora.reader_endpoint
}

# 데이터베이스 정보
output "database_name" {
  description = "데이터베이스 이름"
  value       = aws_rds_cluster.aurora.database_name
}

output "master_username" {
  description = "마스터 사용자 이름"
  value       = aws_rds_cluster.aurora.master_username
}

# 비밀번호 정보
output "master_user_secret_arn" {
  description = "마스터 사용자 비밀번호 Secret ARN"
  value       = aws_rds_cluster.aurora.master_user_secret[0].secret_arn
  sensitive   = true
}

# 포트 정보
output "aurora_port" {
  description = "Aurora 포트"
  value       = aws_rds_cluster.aurora.port
}

# 서브넷 그룹 정보
output "db_subnet_group_name" {
  description = "DB 서브넷 그룹 이름"
  value       = aws_db_subnet_group.aurora.name
}
```

## 시작 단계

### 1. 브랜치 확인 및 최신 코드 가져오기
```bash
git checkout dev
git pull origin dev
```

### 2. Database 모듈 디렉토리 생성
```bash
mkdir -p terraform/modules/database
mkdir -p terraform/envs/dev/database
```

### 3. 파일 생성 순서
1. `terraform/modules/database/versions.tf` (Provider 버전)
2. `terraform/modules/database/variables.tf` (변수 정의)
3. `terraform/modules/database/main.tf` (메인 리소스)
4. `terraform/modules/database/outputs.tf` (출력값)
5. `terraform/envs/dev/database/` 환경 파일들

### 4. 테스트 및 검증
```bash
cd terraform/envs/dev/database
terraform init
terraform validate
terraform plan
```

## 도움이 필요할 때
- Security 레이어 출력값 관련: 휘권에게 문의
- Network 레이어 연동 관련: 영현에게 문의
- Aurora 설정 관련: 아키텍처 문서 참조

## 🎯 완료 기준
- [ ] Aurora MySQL Serverless v2 클러스터 생성
- [ ] Writer + Reader 인스턴스 구성
- [ ] 보안 그룹 및 서브넷 연동
- [ ] Secrets Manager 통합
- [ ] 모니터링 설정 (CloudWatch, Performance Insights)
- [ ] 백업 및 유지보수 설정
- [ ] Terraform 검증 통과

**화이팅 준제!**