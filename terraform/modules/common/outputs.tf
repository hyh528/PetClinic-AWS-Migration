# ==========================================
# 공통 표준 출력값
# ==========================================
# 인터페이스 분리 원칙: 필요한 표준 정보만 노출

# ==========================================
# 명명 규칙 출력값
# ==========================================
output "naming_convention" {
  description = "표준화된 명명 규칙"
  value       = local.naming_convention
}

output "security_group_names" {
  description = "보안 그룹 표준 이름"
  value       = local.security_group_names
}

output "iam_role_names" {
  description = "IAM 역할 표준 이름"
  value       = local.iam_role_names
}

output "subnet_names" {
  description = "서브넷 표준 이름"
  value       = local.subnet_names
}

output "route_table_names" {
  description = "라우트 테이블 표준 이름"
  value       = local.route_table_names
}

output "log_group_names" {
  description = "CloudWatch 로그 그룹 표준 이름"
  value       = local.log_group_names
}

output "dashboard_names" {
  description = "CloudWatch 대시보드 표준 이름"
  value       = local.dashboard_names
}

# ==========================================
# 태그 출력값
# ==========================================
output "common_tags" {
  description = "모든 리소스에 적용할 공통 태그"
  value       = local.common_tags
}

output "mandatory_tags" {
  description = "필수 태그"
  value       = local.mandatory_tags
}

output "cost_tags" {
  description = "비용 추적 태그"
  value       = local.cost_tags
}

output "operational_tags" {
  description = "운영 관리 태그"
  value       = local.operational_tags
}

output "technical_tags" {
  description = "기술 정보 태그"
  value       = local.technical_tags
}

# ==========================================
# 유틸리티 출력값
# ==========================================
output "resource_prefix" {
  description = "리소스 이름 접두사"
  value       = local.naming_convention.resource_name
}

output "bucket_suffix" {
  description = "S3 버킷 고유성을 위한 접미사"
  value       = random_id.bucket_suffix.hex
}

output "environment_info" {
  description = "환경 정보 요약"
  value = {
    project     = var.project_name
    environment = var.environment
    region      = var.aws_region
    layer       = var.layer
    component   = var.component
  }
}