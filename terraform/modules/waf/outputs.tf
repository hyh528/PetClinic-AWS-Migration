output "web_acl_arn" {
  description = "The ARN of the WAF Web ACL."
  value       = aws_wafv2_web_acl.this.arn
}