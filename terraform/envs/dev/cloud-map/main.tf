# Cloud Map 레이어 - Netflix Eureka 대체
# 단일 책임: DNS 기반 서비스 디스커버리만 담당

# 기존 레이어들의 원격 상태 참조
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket  = var.tfstate_bucket_name
    key     = "dev/yeonghyeon/network/terraform.tfstate"
    region  = var.aws_region
    profile = var.network_state_profile
  }
}

# Cloud Map 모듈 (Netflix Eureka 대체)
module "cloud_map" {
  source = "../../../modules/cloud-map"

  name_prefix = var.name_prefix
  environment = var.environment

  # VPC 설정
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id

  # 네임스페이스 설정
  namespace_name        = var.namespace_name
  namespace_description = var.namespace_description

  # 마이크로서비스 목록
  microservices = var.microservices

  # DNS 설정
  dns_ttl           = var.dns_ttl
  dns_record_type   = var.dns_record_type
  routing_policy    = var.routing_policy

  # 헬스체크 설정
  health_check_grace_period     = var.health_check_grace_period
  enable_custom_health_check    = var.enable_custom_health_check
  health_check_failure_threshold = var.health_check_failure_threshold

  # 모니터링 설정
  enable_logging      = var.enable_logging
  enable_metrics      = var.enable_metrics
  enable_health_alarms = var.enable_health_alarms
  log_retention_days  = var.log_retention_days
  healthy_instance_threshold = var.healthy_instance_threshold
  alarm_actions       = var.alarm_actions

  # 고급 설정
  force_destroy = var.force_destroy

  tags = var.tags
}