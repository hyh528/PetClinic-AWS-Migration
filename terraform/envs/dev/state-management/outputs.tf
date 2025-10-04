# ==========================================
# 개발 환경 상태 관리 출력
# ==========================================

# ==========================================
# 상태 관리 모듈 출력 전달
# ==========================================

output "s3_bucket_id" {
  description = "Terraform 상태 파일 S3 버킷 ID"
  value       = module.state_management.s3_bucket_id
}

output "s3_bucket_arn" {
  description = "Terraform 상태 파일 S3 버킷 ARN"
  value       = module.state_management.s3_bucket_arn
}

output "dynamodb_table_name" {
  description = "Terraform 상태 잠금 DynamoDB 테이블 이름"
  value       = module.state_management.dynamodb_table_name
}

output "kms_key_arn" {
  description = "상태 파일 암호화 KMS 키 ARN"
  value       = module.state_management.kms_key_arn
}

# ==========================================
# 백엔드 설정 정보
# ==========================================

output "terraform_backend_config" {
  description = "Terraform 백엔드 설정 정보"
  value       = module.state_management.terraform_backend_config
}

output "backend_keys" {
  description = "환경별 백엔드 키 매핑"
  value       = local.backend_keys
}

# ==========================================
# 사용 가이드
# ==========================================

output "migration_instructions" {
  description = "원격 상태로 마이그레이션 방법"
  value = <<-EOT
    원격 상태 마이그레이션 단계:
    
    1. 상태 관리 인프라 배포:
       cd terraform/envs/dev/state-management
       terraform init
       terraform plan
       terraform apply
    
    2. 각 레이어별 백엔드 설정 적용:
       - 생성된 backend.tf 파일들이 각 레이어에 자동 생성됨
       - 각 레이어에서 terraform init 실행하여 상태 마이그레이션
    
    3. 마이그레이션 스크립트 실행:
       ./scripts/migrate-to-remote-state.sh
    
    4. 로컬 상태 파일 정리:
       - terraform.tfstate 파일들 삭제
       - .terraform 디렉토리 정리
    
    주요 정보:
    - S3 버킷: ${module.state_management.s3_bucket_id}
    - DynamoDB 테이블: ${module.state_management.dynamodb_table_name}
    - KMS 키: ${module.state_management.kms_key_arn}
  EOT
}

output "backend_template" {
  description = "백엔드 설정 템플릿"
  value = <<-EOT
    terraform {
      backend "s3" {
        bucket         = "${module.state_management.s3_bucket_id}"
        key            = "envs/dev/LAYER_NAME/terraform.tfstate"
        region         = "${var.aws_region}"
        dynamodb_table = "${module.state_management.dynamodb_table_name}"
        encrypt        = true
        kms_key_id     = "${module.state_management.kms_key_arn}"
      }
    }
  EOT
}

# ==========================================
# 보안 및 컴플라이언스 정보
# ==========================================

output "security_features" {
  description = "적용된 보안 기능"
  value = {
    encryption_at_rest    = "KMS 키를 사용한 S3 및 DynamoDB 암호화"
    encryption_in_transit = "HTTPS 전용 액세스 정책"
    access_control        = "퍼블릭 액세스 완전 차단"
    versioning           = "S3 버킷 버전 관리 활성화"
    backup_strategy      = "자동 백업 및 라이프사이클 정책"
    audit_logging        = "CloudTrail을 통한 접근 로그"
  }
}

output "cost_optimization" {
  description = "비용 최적화 기능"
  value = {
    lifecycle_policy     = "자동 스토리지 클래스 전환"
    pay_per_request     = "DynamoDB 온디맨드 과금"
    intelligent_tiering = "S3 Intelligent Tiering 고려 가능"
    monitoring         = "CloudWatch를 통한 비용 모니터링"
  }
}