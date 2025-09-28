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