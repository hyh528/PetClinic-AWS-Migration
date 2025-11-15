# ==========================================
# Bootstrap: 출력 값 (Singapore 리전)
# ==========================================

output "tfstate_bucket_name" {
  description = "생성된 Terraform 상태 S3 버킷 이름"
  value       = aws_s3_bucket.tfstate.bucket
}

output "s3_native_locking_enabled" {
  description = "S3 네이티브 잠금 기능 활성화 여부"
  value       = true
}

output "tfstate_bucket_arn" {
  description = "Terraform 상태 S3 버킷 ARN"
  value       = aws_s3_bucket.tfstate.arn
}