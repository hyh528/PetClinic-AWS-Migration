# ==========================================
# AWS Native Services 레이어 출력값
# ==========================================
# 인터페이스 분리 원칙: 필요한 정보만 노출

# ==========================================
# API Gateway 출력값
# ==========================================
output "api_gateway_id" {
  description = "API Gateway REST API ID"
  value       = module.api_gateway.api_id
}

output "api_gateway_name" {
  description = "API Gateway 이름"
  value       = module.api_gateway.api_name
}

output "api_gateway_url" {
  description = "API Gateway 호출 URL"
  value       = module.api_gateway.invoke_url
}

output "api_gateway_stage" {
  description = "API Gateway 스테이지"
  value       = module.api_gateway.stage_name
}

# ==========================================
# Parameter Store 출력값
# ==========================================
output "parameter_store_parameters" {
  description = "생성된 Parameter Store 파라미터 목록"
  value       = module.parameter_store.parameter_names
  sensitive   = false
}

output "parameter_store_kms_key_id" {
  description = "Parameter Store KMS 키 ID"
  value       = module.parameter_store.kms_key_id
}

# ==========================================
# Cloud Map 출력값
# ==========================================
output "cloud_map_namespace_id" {
  description = "Cloud Map 네임스페이스 ID"
  value       = module.cloud_map.namespace_id
}

output "cloud_map_namespace_name" {
  description = "Cloud Map 네임스페이스 이름"
  value       = module.cloud_map.namespace_name
}

output "cloud_map_services" {
  description = "Cloud Map 서비스 목록"
  value       = module.cloud_map.service_ids
}

# ==========================================
# Lambda GenAI 출력값
# ==========================================
output "lambda_function_name" {
  description = "Lambda 함수 이름"
  value       = module.lambda_genai.function_name
}

output "lambda_function_arn" {
  description = "Lambda 함수 ARN"
  value       = module.lambda_genai.function_arn
}

output "lambda_invoke_arn" {
  description = "Lambda 함수 호출 ARN (API Gateway 통합용)"
  value       = module.lambda_genai.invoke_arn
}

# ==========================================
# VPC Link 출력값
# ==========================================
output "vpc_link_id" {
  description = "API Gateway VPC Link ID"
  value       = aws_api_gateway_vpc_link.main.id
}

# ==========================================
# 통합 정보 출력값
# ==========================================
output "aws_native_services_summary" {
  description = "AWS 네이티브 서비스 통합 요약"
  value = {
    api_gateway = {
      id   = module.api_gateway.api_id
      url  = module.api_gateway.invoke_url
      name = module.api_gateway.api_name
    }
    parameter_store = {
      parameter_count = length(module.parameter_store.parameter_names)
      kms_key_id     = module.parameter_store.kms_key_id
    }
    cloud_map = {
      namespace = module.cloud_map.namespace_name
      services  = keys(module.cloud_map.service_ids)
    }
    lambda_genai = {
      function_name = module.lambda_genai.function_name
      runtime      = "python3.11"
      memory_size  = var.lambda_memory_size
    }
  }
}