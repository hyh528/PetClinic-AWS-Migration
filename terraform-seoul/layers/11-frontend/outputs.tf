# =============================================================================
# Frontend Layer Outputs - 핵심 정보만 간단하게
# =============================================================================

# 필수 정보
output "s3_bucket_name" {
  description = "S3 버킷 이름"
  value       = module.s3_frontend.bucket_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront 배포 ID"
  value       = module.cloudfront.distribution_id
}

output "frontend_url" {
  description = "프론트엔드 URL (CloudFront)"
  value       = module.cloudfront.distribution_url
}

output "api_gateway_url" {
  description = "API Gateway URL"
  value       = local.api_gateway_domain_name
}

# 파일 업로드용 정보
output "upload_command" {
  description = "파일 업로드 AWS CLI 명령어"
  value       = "aws s3 sync ../../../spring-petclinic-api-gateway/src/main/resources/static/ s3://${module.s3_frontend.bucket_name}/ --delete"
}

output "cache_invalidation_command" {
  description = "CloudFront 캐시 무효화 명령어"
  value       = "aws cloudfront create-invalidation --distribution-id ${module.cloudfront.distribution_id} --paths '/*'"
}

# 배포 완료 메시지
output "deployment_complete" {
  description = "배포 완료 안내"
  value       = <<EOT
✅ Frontend 레이어 배포 완료!

🌐 접속 URL: ${module.cloudfront.distribution_url}
📦 S3 버킷: ${module.s3_frontend.bucket_name}

📁 파일 업로드 방법:
aws s3 sync ../../../spring-petclinic-api-gateway/src/main/resources/static/ s3://${module.s3_frontend.bucket_name}/ --delete

🔄 캐시 무효화:
aws cloudfront create-invalidation --distribution-id ${module.cloudfront.distribution_id} --paths '/*'
EOT
}