# API Gateway 이름 출력
output "name" {
  description = "The name of the API Gateway"
  value       = aws_api_gateway_rest_api.this.name
}

# API Gateway REST API ID 출력
output "rest_api_id" {
  description = "생성된 API Gateway REST API의 ID입니다."
  value       = aws_api_gateway_rest_api.this.id
}

# API Gateway REST API ARN 출력
output "rest_api_arn" {
  description = "생성된 API Gateway REST API의 ARN입니다."
  value       = aws_api_gateway_rest_api.this.arn
}

# API Gateway 실행 URL 출력
output "invoke_url" {
  description = "API Gateway 스테이지의 실행 URL입니다."
  value       = aws_api_gateway_stage.this.invoke_url
}

# API Gateway 스테이지 이름 출력
output "stage_name" {
  description = "생성된 API Gateway 스테이지 이름입니다."
  value       = aws_api_gateway_stage.this.stage_name
}

# CloudWatch Logs 그룹 ARN 출력
output "log_group_arn" {
  description = "API Gateway 액세스 로그용 CloudWatch Logs 그룹의 ARN입니다."
  value       = aws_cloudwatch_log_group.api_gateway_logs.arn
}

# CloudWatch Logs 그룹 이름 출력
output "log_group_name" {
  description = "API Gateway 액세스 로그용 CloudWatch Logs 그룹의 이름입니다."
  value       = aws_cloudwatch_log_group.api_gateway_logs.name
}