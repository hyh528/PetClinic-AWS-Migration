output "cloudtrail_arn" {
  description = "CloudTrail 트레일의 ARN입니다."
  value       = aws_cloudtrail.this.arn
}

output "s3_bucket_id" {
  description = "CloudTrail 로그를 저장하는 S3 버킷의 ID입니다."
  value       = aws_s3_bucket.this.id
}