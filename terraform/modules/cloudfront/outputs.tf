# CloudFront Distribution Module Outputs

output "distribution_id" {
  description = "CloudFront 배포 ID"
  value       = aws_cloudfront_distribution.frontend.id
}

output "distribution_arn" {
  description = "CloudFront 배포 ARN"
  value       = aws_cloudfront_distribution.frontend.arn
}

output "distribution_domain_name" {
  description = "CloudFront 배포 도메인 이름"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "distribution_hosted_zone_id" {
  description = "CloudFront 배포 호스팅 영역 ID (Route 53용)"
  value       = aws_cloudfront_distribution.frontend.hosted_zone_id
}

output "distribution_url" {
  description = "CloudFront 배포 URL"
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

output "spa_routing_function_arn" {
  description = "SPA 라우팅 CloudFront 함수 ARN"
  value       = var.enable_spa_routing ? aws_cloudfront_function.spa_routing[0].arn : null
}

output "cors_lambda_qualified_arn" {
  description = "CORS 헤더 Lambda@Edge 함수 ARN"
  value       = var.enable_cors_headers ? aws_lambda_function.cors_headers[0].qualified_arn : null
}

output "cloudwatch_alarms" {
  description = "생성된 CloudWatch 알람 정보"
  value = var.enable_monitoring ? {
    "4xx-errors" = {
      alarm_name = aws_cloudwatch_metric_alarm.cloudfront_4xx[0].alarm_name
      alarm_arn  = aws_cloudwatch_metric_alarm.cloudfront_4xx[0].arn
    }
    "5xx-errors" = {
      alarm_name = aws_cloudwatch_metric_alarm.cloudfront_5xx[0].alarm_name
      alarm_arn  = aws_cloudwatch_metric_alarm.cloudfront_5xx[0].arn
    }
  } : {}
}

output "tags" {
  description = "CloudFront 배포에 적용된 태그"
  value       = aws_cloudfront_distribution.frontend.tags
}

output "configuration_summary" {
  description = "CloudFront 설정 요약"
  value = {
    distribution_id      = aws_cloudfront_distribution.frontend.id
    domain_name          = aws_cloudfront_distribution.frontend.domain_name
    price_class          = aws_cloudfront_distribution.frontend.price_class
    enabled              = aws_cloudfront_distribution.frontend.enabled
    ipv6_enabled         = aws_cloudfront_distribution.frontend.is_ipv6_enabled
    s3_origin_enabled    = true
    api_gateway_enabled  = var.enable_api_gateway_integration
    spa_routing_enabled  = var.enable_spa_routing
    cors_headers_enabled = var.enable_cors_headers
    monitoring_enabled   = var.enable_monitoring
    logging_enabled      = var.enable_logging
    waf_enabled          = var.web_acl_arn != null
    ssl_certificate      = var.use_default_certificate ? "default" : "custom"
  }
}