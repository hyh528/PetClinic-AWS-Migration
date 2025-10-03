# API Gateway REST API ID 출력
output "rest_api_id" {
  description = "The ID of the API Gateway REST API."
  value       = aws_api_gateway_rest_api.this.id
}

# API Gateway REST API ARN 출력
output "rest_api_arn" {
  description = "The ARN of the API Gateway REST API."
  value       = aws_api_gateway_rest_api.this.arn
}

# API Gateway 스테이지 실행 URL 출력
output "invoke_url" {
  description = "The invoke URL of the API Gateway Stage."
  value       = aws_api_gateway_stage.this.invoke_url
}

# API Gateway VPC 링크 ID 출력
output "vpc_link_id" {
  description = "The ID of the API Gateway VPC Link."
  value       = aws_api_gateway_vpc_link.this.id
}

# API Gateway CloudWatch Logs 그룹 ARN 출력
output "api_gateway_log_group_arn" {
  description = "The ARN of the CloudWatch Log Group for API Gateway access logs."
  value       = aws_cloudwatch_log_group.api_gateway_logs.arn
}