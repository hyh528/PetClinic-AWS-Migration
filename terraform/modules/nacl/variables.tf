# ==========================================
# Network ACL 모듈 변수 정의
# ==========================================
# 클린 아키텍처 원칙: 의존성 역전 및 설정 외부화

# ==========================================
# 필수 네트워크 설정 (Required Network Configuration)
# ==========================================

variable "vpc_id" {
  description = "VPC ID where NACLs will be created"
  type        = string

  validation {
    condition     = can(regex("^vpc-[a-z0-9]{8,17}$", var.vpc_id))
    error_message = "VPC ID는 유효한 AWS VPC 식별자여야 합니다."
  }
}

variable "vpc_cidr" {
  description = "VPC CIDR block for internal traffic rules"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR은 유효한 CIDR 블록이어야 합니다."
  }
}

# ==========================================
# 서브넷 설정 (Subnet Configuration)
# ==========================================

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB and NAT Gateway"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for subnet_id in var.public_subnet_ids : can(regex("^subnet-[a-z0-9]{8,17}$", subnet_id))
    ])
    error_message = "All subnet IDs must be valid AWS subnet identifiers."
  }
}

variable "private_app_subnet_ids" {
  description = "List of private application subnet IDs for ECS services"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for subnet_id in var.private_app_subnet_ids : can(regex("^subnet-[a-z0-9]{8,17}$", subnet_id))
    ])
    error_message = "All subnet IDs must be valid AWS subnet identifiers."
  }
}

variable "private_db_subnet_ids" {
  description = "List of private database subnet IDs for Aurora cluster"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for subnet_id in var.private_db_subnet_ids : can(regex("^subnet-[a-z0-9]{8,17}$", subnet_id))
    ])
    error_message = "All subnet IDs must be valid AWS subnet identifiers."
  }
}

# ==========================================
# 기본 설정 (Basic Configuration)
# ==========================================

variable "name_prefix" {
  description = "Name prefix for all NACL resources"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name_prefix))
    error_message = "Name prefix must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

# ==========================================
# Well-Architected Framework 태그 (Cost Optimization)
# ==========================================

variable "cost_center" {
  description = "Cost center for billing and cost tracking"
  type        = string
  default     = "infrastructure"
}

variable "owner" {
  description = "Owner of the NACL resources"
  type        = string
  default     = "platform-team"
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# ==========================================
# 보안 설정 (Security Configuration)
# ==========================================

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs for NACL monitoring"
  type        = bool
  default     = true
}

variable "flow_logs_role_arn" {
  description = "IAM role ARN for VPC Flow Logs"
  type        = string
  default     = ""
}

variable "flow_logs_destination" {
  description = "Destination for VPC Flow Logs (CloudWatch Logs ARN or S3 bucket ARN)"
  type        = string
  default     = ""
}

variable "flow_logs_log_group_name" {
  description = "CloudWatch Log Group name for VPC Flow Logs"
  type        = string
  default     = ""
}

variable "enable_security_monitoring" {
  description = "Enable security monitoring and alerting for NACL denies"
  type        = bool
  default     = true
}

variable "security_alert_threshold" {
  description = "Threshold for NACL denied connections alert"
  type        = number
  default     = 100

  validation {
    condition     = var.security_alert_threshold > 0
    error_message = "Security alert threshold must be greater than 0."
  }
}

variable "alarm_actions" {
  description = "List of ARNs to notify when security alarms trigger"
  type        = list(string)
  default     = []
}

# ==========================================
# 네트워크 보안 설정 (Network Security Configuration)
# ==========================================

variable "allowed_cidr_blocks" {
  description = "Additional CIDR blocks allowed for specific rules"
  type        = map(list(string))
  default     = {}

  validation {
    condition = alltrue(flatten([
      for key, cidrs in var.allowed_cidr_blocks : [
        for cidr in cidrs : can(cidrhost(cidr, 0))
      ]
    ]))
    error_message = "All CIDR blocks must be valid CIDR notation."
  }
}

variable "custom_ports" {
  description = "Custom port configurations for specific applications"
  type = map(object({
    port        = number
    protocol    = string
    description = string
  }))
  default = {}

  validation {
    condition = alltrue([
      for key, config in var.custom_ports : (
        config.port >= 1 && config.port <= 65535 &&
        contains(["tcp", "udp", "icmp"], config.protocol)
      )
    ])
    error_message = "Custom ports must have valid port numbers (1-65535) and protocols (tcp, udp, icmp)."
  }
}

# ==========================================
# 고급 설정 (Advanced Configuration)
# ==========================================

variable "enable_ipv6" {
  description = "Enable IPv6 support for NACL rules"
  type        = bool
  default     = false
}

variable "ipv6_cidr_block" {
  description = "IPv6 CIDR block for the VPC"
  type        = string
  default     = ""

  validation {
    condition     = var.ipv6_cidr_block == "" || can(regex("^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}/[0-9]{1,3}$", var.ipv6_cidr_block))
    error_message = "IPv6 CIDR 블록은 유효한 IPv6 CIDR 표기법이거나 빈 문자열이어야 합니다."
  }
}

variable "enable_strict_mode" {
  description = "Enable strict mode with minimal required rules only"
  type        = bool
  default     = false
}

variable "enable_logging_rules" {
  description = "Enable additional rules for logging and monitoring traffic"
  type        = bool
  default     = true
}

# ==========================================
# 성능 최적화 설정 (Performance Optimization)
# ==========================================

variable "ephemeral_port_range" {
  description = "Custom ephemeral port range configuration"
  type = object({
    from = number
    to   = number
  })
  default = {
    from = 32768
    to   = 65535
  }

  validation {
    condition = (
      var.ephemeral_port_range.from >= 1024 &&
      var.ephemeral_port_range.to <= 65535 &&
      var.ephemeral_port_range.from < var.ephemeral_port_range.to
    )
    error_message = "Ephemeral port range must be valid (from >= 1024, to <= 65535, from < to)."
  }
}

variable "optimize_for_performance" {
  description = "Optimize NACL rules for performance over security"
  type        = bool
  default     = false
}

# ==========================================
# 환경별 설정 (Environment-specific Configuration)
# ==========================================

variable "production_hardening" {
  description = "Apply production-level security hardening"
  type        = bool
  default     = false
}

variable "development_mode" {
  description = "Enable development mode with relaxed rules"
  type        = bool
  default     = false
}

variable "enable_debug_rules" {
  description = "Enable debug rules for troubleshooting (dev environment only)"
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_debug_rules || var.environment == "dev"
    error_message = "Debug rules can only be enabled in dev environment."
  }
}