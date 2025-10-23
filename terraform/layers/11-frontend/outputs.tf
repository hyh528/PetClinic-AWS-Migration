# Frontend Hosting Layer Outputs

output "s3_bucket_id" {
  description = "프론트엔드 S3 버킷 ID"
  value       = module.s3_frontend.bucket_id
}

output "s3_bucket_name" {
  description = "프론트엔드 S3 버킷 이름"
  value       = module.s3_frontend.bucket_name
}

output "s3_bucket_arn" {
  description = "프론트엔드 S3 버킷 ARN"
  value       = module.s3_frontend.bucket_arn
}

output "s3_bucket_domain_name" {
  description = "프론트엔드 S3 버킷 도메인 이름"
  value       = module.s3_frontend.bucket_domain_name
}

output "s3_bucket_website_endpoint" {
  description = "프론트엔드 S3 정적 웹사이트 엔드포인트"
  value       = module.s3_frontend.bucket_website_endpoint
}

output "cloudfront_distribution_id" {
  description = "CloudFront 배포 ID"
  value       = module.cloudfront.distribution_id
}

output "cloudfront_distribution_domain_name" {
  description = "CloudFront 배포 도메인 이름"
  value       = module.cloudfront.distribution_domain_name
}

output "cloudfront_distribution_url" {
  description = "CloudFront 배포 URL"
  value       = module.cloudfront.distribution_url
}

output "cloudfront_distribution_hosted_zone_id" {
  description = "CloudFront 배포 호스팅 영역 ID (Route 53용)"
  value       = module.cloudfront.distribution_hosted_zone_id
}

output "api_gateway_url" {
  description = "통합된 API Gateway URL"
  value       = local.api_gateway_domain_name
}

output "frontend_url" {
  description = "프론트엔드 애플리케이션 URL (CloudFront)"
  value       = module.cloudfront.distribution_url
}

output "cloudfront_oai_iam_arn" {
  description = "CloudFront Origin Access Identity IAM ARN"
  value       = module.s3_frontend.cloudfront_oai_iam_arn
}

output "tags" {
  description = "레이어에 적용된 태그"
  value       = local.layer_common_tags
}

output "configuration_summary" {
  description = "프론트엔드 호스팅 설정 요약"
  value = {
    s3_bucket_name         = module.s3_frontend.bucket_name
    cloudfront_domain      = module.cloudfront.distribution_domain_name
    api_gateway_url        = local.api_gateway_domain_name
    frontend_url           = module.cloudfront.distribution_url
    spa_routing_enabled    = var.enable_spa_routing
    cors_headers_enabled   = var.enable_cors_headers
    monitoring_enabled     = var.enable_monitoring
    versioning_enabled     = var.enable_versioning
    access_logging_enabled = var.enable_access_logging
  }
}

output "deployment_instructions" {
  description = "프론트엔드 배포 후 확인사항"
  value = <<EOT
🎉 프론트엔드 호스팅 레이어 배포 완료!

📋 다음 단계:
1. 프론트엔드 URL: ${module.cloudfront.distribution_url}
2. API Gateway URL: ${local.api_gateway_domain_name}
3. S3 버킷: ${module.s3_frontend.bucket_name}

🔍 확인사항:
- 프론트엔드 페이지가 정상 로드되는지 확인
- 챗봇 기능이 Lambda GenAI로 작동하는지 확인
- 데이터베이스 CRUD 작업이 가능한지 확인

⚠️  주의사항:
- 프론트엔드 파일들은 Terraform apply 시 자동으로 S3에 업로드됩니다
- 파일 변경 시 Terraform apply를 재실행하여 업데이트하세요
- CloudFront 캐시로 인해 변경사항이 즉시 반영되지 않을 수 있습니다
EOT
}