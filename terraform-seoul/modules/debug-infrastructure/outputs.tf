# =============================================================================
# Bastion Host Module - Outputs
# =============================================================================

output "bastion_instance_id" {
  description = "Bastion Host 인스턴스 ID"
  value       = var.enable_debug_infrastructure ? aws_instance.bastion[0].id : null
}

output "bastion_public_ip" {
  description = "Bastion Host 퍼블릭 IP"
  value       = var.enable_debug_infrastructure ? aws_instance.bastion[0].public_ip : null
}

output "bastion_security_group_id" {
  description = "Bastion Host 보안 그룹 ID"
  value       = var.enable_debug_infrastructure ? aws_security_group.bastion[0].id : null
}



output "debug_infrastructure_enabled" {
  description = "Bastion Host 활성화 상태"
  value       = var.enable_debug_infrastructure
}