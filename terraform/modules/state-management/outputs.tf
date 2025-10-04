# ==========================================
# Terraform 상태 관리 모듈 출력
# ==========================================

# ==========================================
# S3 버킷 정보
# ==========================================

output "s3_bucket_id" {
  description = "Terraform 상태 파일 S3 버킷 ID"
  value       = aws_s3_bucket.tfstate.id
}

output "s3_bucket_arn" {
  description = "Terraform 상태 파일 S3 버킷 ARN"
  value       = aws_s3_bucket.tfstate.arn
}

output "s3_bucket_domain_name" {
  description = "S3 버킷 도메인 이름"
  value       = aws_s3_bucket.tfstate.bucket_domain_name
}

output "s3_bucket_regional_domain_name" {
  description = "S3 버킷 리전별 도메인 이름"
  value       = aws_s3_bucket.tfstate.bucket_regional_domain_name
}

# ==========================================
# KMS 키 정보
# ==========================================

output "kms_key_id" {
  description = "Terraform 상태 파일 암호화용 KMS 키 ID"
  value       = aws_kms_key.tfstate.key_id
}

output "kms_key_arn" {
  description = "Terraform 상태 파일 암호화용 KMS 키 ARN"
  value       = aws_kms_key.tfstate.arn
}

output "kms_alias_name" {
  description = "KMS 키 별칭 이름"
  value       = aws_kms_alias.tfstate.name
}

# ==========================================
# DynamoDB 테이블 정보
# ==========================================

output "dynamodb_table_name" {
  description = "Terraform 상태 잠금용 DynamoDB 테이블 이름"
  value       = aws_dynamodb_table.tflock.name
}

output "dynamodb_table_arn" {
  description = "DynamoDB 테이블 ARN"
  value       = aws_dynamodb_table.tflock.arn
}

# ==========================================
# 백엔드 설정 정보
# ==========================================

output "terraform_backend_config" {
  description = "Terraform 백엔드 설정 정보"
  value = {
    bucket         = aws_s3_bucket.tfstate.id
    key            = "terraform.tfstate"
    region         = data.aws_region.current.name
    dynamodb_table = aws_dynamodb_table.tflock.name
    encrypt        = true
    kms_key_id     = aws_kms_key.tfstate.arn
  }
}

# ==========================================
# 복제 정보 (활성화된 경우)
# ==========================================

output "replica_bucket_id" {
  description = "복제본 S3 버킷 ID (활성화된 경우)"
  value       = var.enable_cross_region_replication ? aws_s3_bucket.tfstate_replica[0].id : null
}

output "replica_bucket_arn" {
  description = "복제본 S3 버킷 ARN (활성화된 경우)"
  value       = var.enable_cross_region_replication ? aws_s3_bucket.tfstate_replica[0].arn : null
}

output "replica_kms_key_arn" {
  description = "복제본 암호화용 KMS 키 ARN (활성화된 경우)"
  value       = var.enable_cross_region_replication ? aws_kms_key.tfstate_replica[0].arn : null
}

# ==========================================
# 보안 및 컴플라이언스 정보
# ==========================================

output "bucket_encryption_status" {
  description = "S3 버킷 암호화 상태"
  value = {
    sse_algorithm     = "aws:kms"
    kms_master_key_id = aws_kms_key.tfstate.arn
    bucket_key_enabled = true
  }
}

output "versioning_status" {
  description = "S3 버킷 버전 관리 상태"
  value = aws_s3_bucket_versioning.tfstate.versioning_configuration[0].status
}

output "public_access_block_status" {
  description = "S3 버킷 퍼블릭 액세스 차단 상태"
  value = {
    block_public_acls       = aws_s3_bucket_public_access_block.tfstate.block_public_acls
    block_public_policy     = aws_s3_bucket_public_access_block.tfstate.block_public_policy
    ignore_public_acls      = aws_s3_bucket_public_access_block.tfstate.ignore_public_acls
    restrict_public_buckets = aws_s3_bucket_public_access_block.tfstate.restrict_public_buckets
  }
}

# ==========================================
# 사용 가이드
# ==========================================

output "usage_instructions" {
  description = "Terraform 백엔드 사용 방법"
  value = <<-EOT
    Terraform 백엔드 설정 방법:
    
    1. 각 환경의 main.tf에 다음 백엔드 설정 추가:
    
    terraform {
      backend "s3" {
        bucket         = "${aws_s3_bucket.tfstate.id}"
        key            = "envs/dev/terraform.tfstate"  # 환경별로 변경
        region         = "${data.aws_region.current.name}"
        dynamodb_table = "${aws_dynamodb_table.tflock.name}"
        encrypt        = true
        kms_key_id     = "${aws_kms_key.tfstate.arn}"
      }
    }
    
    2. terraform init 실행하여 백엔드 초기화
    3. terraform plan/apply로 인프라 관리
    
    주의사항:
    - 상태 파일은 자동으로 암호화되어 저장됩니다
    - DynamoDB를 통해 동시 실행이 방지됩니다
    - 버전 관리가 활성화되어 있어 이전 상태로 복원 가능합니다
  EOT
}

# 현재 AWS 리전 정보
data "aws_region" "current" {}