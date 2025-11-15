# S3 Frontend Hosting Module Outputs

output "bucket_id" {
  description = "S3 버킷 ID"
  value       = aws_s3_bucket.frontend.id
}

output "bucket_arn" {
  description = "S3 버킷 ARN"
  value       = aws_s3_bucket.frontend.arn
}

output "bucket_name" {
  description = "S3 버킷 이름"
  value       = aws_s3_bucket.frontend.bucket
}

output "bucket_domain_name" {
  description = "S3 버킷 도메인 이름"
  value       = aws_s3_bucket.frontend.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "S3 버킷 리전 도메인 이름"
  value       = aws_s3_bucket.frontend.bucket_regional_domain_name
}

output "bucket_website_endpoint" {
  description = "S3 정적 웹사이트 엔드포인트"
  value       = aws_s3_bucket_website_configuration.frontend.website_endpoint
}

output "cloudfront_oai_iam_arn" {
  description = "CloudFront Origin Access Identity IAM ARN"
  value       = aws_cloudfront_origin_access_identity.frontend.iam_arn
}

output "cloudfront_oai_id" {
  description = "CloudFront Origin Access Identity ID"
  value       = aws_cloudfront_origin_access_identity.frontend.id
}

output "cloudfront_oai_path" {
  description = "CloudFront Origin Access Identity 경로"
  value       = aws_cloudfront_origin_access_identity.frontend.cloudfront_access_identity_path
}

output "tags" {
  description = "S3 버킷에 적용된 태그"
  value       = aws_s3_bucket.frontend.tags
}