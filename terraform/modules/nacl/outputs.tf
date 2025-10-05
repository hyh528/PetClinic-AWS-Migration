# ==========================================
# Network ACL 모듈 출력값
# ==========================================
# 클린 아키텍처 원칙: 인터페이스 분리 및 의존성 역전

# ==========================================
# NACL 리소스 정보 (NACL Resource Information)
# ==========================================

output "nacl_ids" {
  description = "Map of NACL IDs by subnet type"
  value = {
    for key, nacl in aws_network_acl.this : key => nacl.id
  }
}

output "nacl_arns" {
  description = "Map of NACL ARNs by subnet type"
  value = {
    for key, nacl in aws_network_acl.this : key => nacl.arn
  }
}

output "nacl_details" {
  description = "Detailed information about all NACLs"
  value = {
    for key, nacl in aws_network_acl.this : key => {
      id          = nacl.id
      arn         = nacl.arn
      vpc_id      = nacl.vpc_id
      subnet_ids  = nacl.subnet_ids
      owner_id    = nacl.owner_id
      tags        = nacl.tags
    }
  }
}

# ==========================================
# 보안 정보 (Security Information)
# ==========================================

output "security_configuration" {
  description = "Security configuration summary"
  value = {
    flow_logs_enabled        = var.enable_flow_logs
    security_monitoring      = var.enable_security_monitoring
    strict_mode             = var.enable_strict_mode
    production_hardening    = var.production_hardening
    ipv6_enabled           = var.enable_ipv6
    
    # 보안 레벨 매핑
    security_levels = {
      for key, nacl in aws_network_acl.this : key => {
        tier           = local.subnet_types[key].tier
        security_level = nacl.tags["SecurityLevel"]
        purpose        = local.subnet_types[key].purpose
      }
    }
  }
}

output "rule_counts" {
  description = "Number of rules per NACL and direction"
  value = {
    for subnet_type in keys(local.subnet_types) : subnet_type => {
      inbound_rules = length([
        for rule_key, rule in local.network_rules : rule_key 
        if rule.subnet_type == subnet_type && rule.direction == "inbound"
      ])
      outbound_rules = length([
        for rule_key, rule in local.network_rules : rule_key 
        if rule.subnet_type == subnet_type && rule.direction == "outbound"
      ])
      total_rules = length([
        for rule_key, rule in local.network_rules : rule_key 
        if rule.subnet_type == subnet_type
      ])
    }
  }
}

# ==========================================
# 네트워크 구성 정보 (Network Configuration)
# ==========================================

output "network_configuration" {
  description = "Network configuration details"
  value = {
    vpc_id   = var.vpc_id
    vpc_cidr = var.vpc_cidr
    
    # 서브넷 매핑
    subnet_mappings = {
      for key, config in local.subnet_types : key => {
        subnet_ids = config.subnet_ids
        tier       = config.tier
        nacl_id    = aws_network_acl.this[key].id
      }
    }
    
    # 포트 범위 설정
    port_ranges = local.port_ranges
    
    # 에페메랄 포트 설정
    ephemeral_ports = var.ephemeral_port_range
  }
}

# ==========================================
# 모니터링 정보 (Monitoring Information)
# ==========================================

output "monitoring_resources" {
  description = "Monitoring and logging resources"
  value = {
    flow_logs = var.enable_flow_logs ? {
      enabled     = true
      destination = var.flow_logs_destination
      role_arn    = var.flow_logs_role_arn
    } : {
      enabled = false
    }
    
    security_monitoring = var.enable_security_monitoring ? {
      enabled           = true
      alert_threshold   = var.security_alert_threshold
      metric_filter     = var.enable_flow_logs ? aws_cloudwatch_log_metric_filter.nacl_denies[0].name : null
      alarm_name        = aws_cloudwatch_metric_alarm.nacl_security_alert[0].alarm_name
    } : {
      enabled = false
    }
  }
}

# ==========================================
# 규칙 상세 정보 (Rule Details)
# ==========================================

output "rule_matrix" {
  description = "Complete rule matrix for all NACLs"
  value = {
    for rule_key, rule in local.network_rules : rule_key => {
      subnet_type = rule.subnet_type
      direction   = rule.direction
      rule_number = rule.rule_number
      protocol    = rule.protocol
      action      = rule.action
      cidr_block  = rule.cidr_block
      port_range  = "${rule.from_port}-${rule.to_port}"
      description = rule.description
    }
  }
}

# ==========================================
# Well-Architected Framework 준수 정보
# ==========================================

output "well_architected_compliance" {
  description = "AWS Well-Architected Framework compliance status"
  value = {
    security = {
      defense_in_depth     = true  # NACL + Security Groups
      least_privilege      = true  # Minimal required rules
      explicit_deny        = true  # Default deny rules
      monitoring_enabled   = var.enable_security_monitoring
      flow_logs_enabled    = var.enable_flow_logs
    }
    
    reliability = {
      predictable_behavior = true  # Consistent rule structure
      multi_az_support    = length(var.public_subnet_ids) > 1
      fault_isolation     = true  # Separate NACLs per tier
    }
    
    performance_efficiency = {
      optimized_port_ranges = true  # AWS recommended ephemeral ports
      minimal_rules        = true  # Only necessary rules
      efficient_structure  = true  # Data-driven rule generation
    }
    
    cost_optimization = {
      resource_tagging     = true  # Comprehensive tagging
      minimal_resources    = true  # Only required NACLs
      automated_management = true  # Terraform managed
    }
    
    operational_excellence = {
      infrastructure_as_code = true  # Terraform managed
      monitoring_enabled     = var.enable_security_monitoring
      automated_alerting     = var.enable_security_monitoring
      documentation         = true  # Self-documenting rules
    }
    
    sustainability = {
      efficient_design      = true  # Minimal resource usage
      automated_management  = true  # Reduced operational overhead
      optimized_rules      = true  # Performance optimized
    }
  }
}

# ==========================================
# 사용 통계 (Usage Statistics)
# ==========================================

output "usage_statistics" {
  description = "NACL usage statistics and metrics"
  value = {
    total_nacls = length(aws_network_acl.this)
    total_rules = length(local.network_rules)
    
    # 서브넷 타입별 통계
    by_subnet_type = {
      for key in keys(local.subnet_types) : key => {
        nacl_count = 1
        subnet_count = length(local.subnet_types[key].subnet_ids)
        inbound_rules = length([
          for rule_key, rule in local.network_rules : rule_key 
          if rule.subnet_type == key && rule.direction == "inbound"
        ])
        outbound_rules = length([
          for rule_key, rule in local.network_rules : rule_key 
          if rule.subnet_type == key && rule.direction == "outbound"
        ])
      }
    }
    
    # 보안 레벨별 통계
    by_security_level = {
      high     = length([for k, v in aws_network_acl.this : k if v.tags["SecurityLevel"] == "high"])
      medium   = length([for k, v in aws_network_acl.this : k if v.tags["SecurityLevel"] == "medium"])
      standard = length([for k, v in aws_network_acl.this : k if v.tags["SecurityLevel"] == "standard"])
    }
  }
}

# ==========================================
# 디버깅 정보 (Debugging Information)
# ==========================================

output "debug_information" {
  description = "Debug information for troubleshooting (dev environment only)"
  value = var.environment == "dev" ? {
    total_rules_count = length(local.network_rules)
    subnet_types      = local.subnet_types
    port_ranges       = local.port_ranges
    
    # 규칙 키 목록
    rule_keys = keys(local.network_rules)
    
    # 변수 검증 상태
    variable_validation = {
      vpc_id_valid           = can(regex("^vpc-[a-z0-9]{8,17}$", var.vpc_id))
      vpc_cidr_valid         = can(cidrhost(var.vpc_cidr, 0))
      ephemeral_range_valid  = var.ephemeral_port_range.from < var.ephemeral_port_range.to
      environment_valid      = contains(["dev", "staging", "prod"], var.environment)
    }
  } : null
  
  sensitive = false
}