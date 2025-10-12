# VPC 엔드포인트 모듈의 출력 값들을 정의합니다.

# ECR API VPC 엔드포인트 ID 출력
output "ecr_api_vpce_id" {
  description = "생성된 ECR API VPC 엔드포인트의 ID입니다."
  value       = aws_vpc_endpoint.ecr_api.id
}

# ECR DKR VPC 엔드포인트 ID 출력
output "ecr_dkr_vpce_id" {
  description = "생성된 ECR DKR VPC 엔드포인트의 ID입니다."
  value       = aws_vpc_endpoint.ecr_dkr.id
}

# CloudWatch Logs VPC 엔드포인트 ID 출력
output "cloudwatch_logs_vpce_id" {
  description = "생성된 CloudWatch Logs VPC 엔드포인트의 ID입니다."
  value       = aws_vpc_endpoint.cloudwatch_logs.id
}

# X-Ray VPC 엔드포인트 ID 출력
output "xray_vpce_id" {
  description = "생성된 X-Ray VPC 엔드포인트의 ID입니다."
  value       = aws_vpc_endpoint.xray.id
}

# Systems Manager (SSM) VPC 엔드포인트 ID 출력
output "ssm_vpce_id" {
  description = "생성된 Systems Manager (SSM) VPC 엔드포인트의 ID입니다."
  value       = aws_vpc_endpoint.ssm.id
}

# Secrets Manager VPC 엔드포인트 ID 출력
output "secretsmanager_vpce_id" {
  description = "생성된 Secrets Manager VPC 엔드포인트의 ID입니다."
  value       = aws_vpc_endpoint.secretsmanager.id
}

# KMS VPC 엔드포인트 ID 출력
output "kms_vpce_id" {
  description = "생성된 KMS VPC 엔드포인트의 ID입니다."
  value       = aws_vpc_endpoint.kms.id
}

# S3 Gateway VPC 엔드포인트 ID 출력
output "s3_gateway_vpce_id" {
  description = "생성된 S3 Gateway VPC 엔드포인트의 ID입니다."
  value       = aws_vpc_endpoint.s3.id
}

# CloudWatch Monitoring VPC 엔드포인트 ID 출력
output "cloudwatch_monitoring_vpce_id" {
  description = "생성된 CloudWatch Monitoring VPC 엔드포인트의 ID입니다."
  value       = aws_vpc_endpoint.cloudwatch_monitoring.id
}