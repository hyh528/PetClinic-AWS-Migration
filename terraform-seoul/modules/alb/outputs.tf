output "alb_arn" {
  description = "애플리케이션 로드 밸런서 ARN"
  value       = aws_lb.this.arn
}

output "alb_id" {
  description = "애플리케이션 로드 밸런서 ID"
  value       = aws_lb.this.id
}

output "alb_dns_name" {
  description = "ALB DNS 이름"
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "ALB 호스팅 영역 ID (Route53 별칭용)"
  value       = aws_lb.this.zone_id
}

output "alb_arn_suffix" {
  description = "ALB ARN suffix (CloudWatch 메트릭용)"
  value       = aws_lb.this.arn_suffix
}

output "alb_security_group_id" {
  description = "ALB에 연결된 보안 그룹 ID"
  value       = aws_security_group.alb.id
}

output "default_target_group_arn" {
  description = "기본 대상 그룹 ARN"
  value       = aws_lb_target_group.default.arn
}

output "listener_http_arn" {
  description = "HTTP 리스너 ARN (HTTPS가 아직 구성되지 않은 경우 존재)"
  value       = try(aws_lb_listener.http_forward[0].arn, try(aws_lb_listener.http_redirect[0].arn, null))
}

output "listener_https_arn" {
  description = "HTTPS 리스너 ARN (certificate_arn이 비어 있으면 null)"
  value       = try(aws_lb_listener.https[0].arn, null)
}

# WAF 관련 출력
output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN (Rate Limiting 활성화 시)"
  value       = var.enable_waf_rate_limiting ? aws_wafv2_web_acl.alb_rate_limit[0].arn : null
}

output "waf_web_acl_id" {
  description = "WAF Web ACL ID (Rate Limiting 활성화 시)"
  value       = var.enable_waf_rate_limiting ? aws_wafv2_web_acl.alb_rate_limit[0].id : null
}

# WAF 로그 그룹 출력 (비활성화 - WAFv2는 CloudWatch Logs 직접 지원 안 함)
# output "waf_log_group_name" {
#   description = "WAF CloudWatch 로그 그룹 이름"
#   value       = var.enable_waf_rate_limiting ? aws_cloudwatch_log_group.waf_logs[0].name : null
# }

output "waf_log_group_name" {
  description = "WAF CloudWatch 로그 그룹 이름 (비활성화)"
  value       = null
}

output "rate_limiting_enabled" {
  description = "Rate Limiting 활성화 여부"
  value       = var.enable_waf_rate_limiting
}

output "rate_limit_settings" {
  description = "Rate Limiting 설정 정보"
  value = var.enable_waf_rate_limiting ? {
    general_limit  = var.rate_limit_per_ip
    burst_limit    = var.rate_limit_burst_per_ip
    geo_blocking   = var.enable_geo_blocking
    security_rules = var.enable_security_rules
  } : null
}