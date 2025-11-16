# ==========================================
# CloudTrail 모듈 출력값
# ==========================================

output "cloudtrail_arn" {
  description = "CloudTrail ARN"
  value       = aws_cloudtrail.main.arn
}

output "cloudtrail_name" {
  description = "CloudTrail 이름"
  value       = aws_cloudtrail.main.name
}

output "s3_bucket_name" {
  description = "CloudTrail 로그 S3 버킷 이름"
  value       = aws_s3_bucket.cloudtrail.id
}

output "s3_bucket_arn" {
  description = "CloudTrail 로그 S3 버킷 ARN"
  value       = aws_s3_bucket.cloudtrail.arn
}

output "kms_key_id" {
  description = "CloudTrail 암호화 KMS 키 ID"
  value       = aws_kms_key.cloudtrail.key_id
}

output "kms_key_arn" {
  description = "CloudTrail 암호화 KMS 키 ARN"
  value       = aws_kms_key.cloudtrail.arn
}

output "cloudwatch_log_group_name" {
  description = "CloudTrail CloudWatch 로그 그룹 이름"
  value       = aws_cloudwatch_log_group.cloudtrail.name
}

output "cloudwatch_log_group_arn" {
  description = "CloudTrail CloudWatch 로그 그룹 ARN"
  value       = aws_cloudwatch_log_group.cloudtrail.arn
}