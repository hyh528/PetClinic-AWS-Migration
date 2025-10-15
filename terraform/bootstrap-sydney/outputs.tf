# ==========================================
# Bootstrap: 출력 값 (outputs)
# - 다른 환경에서 backend 구성 시 참조할 값들
# ==========================================

output "tfstate_bucket_name" {
  description = "Terraform 원격 상태를 위한 S3 버킷 이름"
  value       = aws_s3_bucket.tfstate.bucket
}

output "tf_lock_table_name" {
  description = "Terraform 상태 잠금을 위한 DynamoDB 테이블 이름"
  value       = aws_dynamodb_table.tf_lock.name
}