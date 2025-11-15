# ==========================================
# Network ACL 모듈 - 클린 아키텍처 & Well-Architected Framework
# ==========================================
# 
# 🏗️ 클린 아키텍처 원칙:
# - Single Responsibility: 네트워크 수준 보안만 담당
# - Open/Closed: 새로운 서브넷 타입 추가 시 기존 코드 수정 없이 확장
# - DRY: 중복 코드 완전 제거, 데이터 기반 규칙 생성
#
# 🏛️ AWS Well-Architected Framework:
# - Security: 최소 권한 원칙, 계층적 보안 (NACL + Security Group)
# - Reliability: 예측 가능한 네트워크 동작
# - Performance Efficiency: 최적화된 포트 범위
# - Cost Optimization: 불필요한 규칙 제거
# - Operational Excellence: 명확한 규칙 구조
# - Sustainability: 효율적인 네트워크 설계

# ==========================================
# 데이터 기반 설계 (Data-Driven Design)
# ==========================================

locals {
  # 포트 범위 정의 (AWS 권장사항)
  port_ranges = {
    ephemeral = {
      from = 32768
      to   = 65535
    }
    web = {
      http  = 80
      https = 443
    }
    database = {
      mysql = 3306
    }
    application = {
      spring_boot = 8080
      admin       = 9090
    }
  }

  # 서브넷 타입별 NACL 정의 (To-Be 아키텍처 기반)
  subnet_types = {
    public = {
      name_suffix = "public"
      subnet_ids  = var.public_subnet_ids
      tier        = "dmz"
      purpose     = "Internet-facing load balancers and NAT gateways"
    }
    private_app = {
      name_suffix = "private-app"
      subnet_ids  = var.private_app_subnet_ids
      tier        = "application"
      purpose     = "ECS Fargate services and application logic"
    }
    private_db = {
      name_suffix = "private-db"
      subnet_ids  = var.private_db_subnet_ids
      tier        = "data"
      purpose     = "Aurora MySQL cluster - maximum isolation"
    }
  }

  # 네트워크 규칙 매트릭스 (Clean Code: for_each 친화적 구조)
  network_rules = {
    # Public Subnet Rules (DMZ Layer)
    "public_inbound_100" = {
      subnet_type = "public"
      direction   = "inbound"
      rule_number = 100
      protocol    = "tcp"
      action      = "allow"
      cidr_block  = "0.0.0.0/0"
      from_port   = local.port_ranges.web.http
      to_port     = local.port_ranges.web.http
      description = "HTTP from internet"
    }
    "public_inbound_110" = {
      subnet_type = "public"
      direction   = "inbound"
      rule_number = 110
      protocol    = "tcp"
      action      = "allow"
      cidr_block  = "0.0.0.0/0"
      from_port   = local.port_ranges.web.https
      to_port     = local.port_ranges.web.https
      description = "HTTPS from internet"
    }
    "public_inbound_120" = {
      subnet_type = "public"
      direction   = "inbound"
      rule_number = 120
      protocol    = "tcp"
      action      = "allow"
      cidr_block  = "0.0.0.0/0"
      from_port   = local.port_ranges.ephemeral.from
      to_port     = local.port_ranges.ephemeral.to
      description = "Ephemeral ports for return traffic"
    }
    "public_outbound_100" = {
      subnet_type = "public"
      direction   = "outbound"
      rule_number = 100
      protocol    = "tcp"
      action      = "allow"
      cidr_block  = "0.0.0.0/0"
      from_port   = local.port_ranges.web.http
      to_port     = local.port_ranges.web.http
      description = "HTTP to internet"
    }
    "public_outbound_110" = {
      subnet_type = "public"
      direction   = "outbound"
      rule_number = 110
      protocol    = "tcp"
      action      = "allow"
      cidr_block  = "0.0.0.0/0"
      from_port   = local.port_ranges.web.https
      to_port     = local.port_ranges.web.https
      description = "HTTPS to internet"
    }
    "public_outbound_120" = {
      subnet_type = "public"
      direction   = "outbound"
      rule_number = 120
      protocol    = "tcp"
      action      = "allow"
      cidr_block  = var.vpc_cidr
      from_port   = local.port_ranges.application.spring_boot
      to_port     = local.port_ranges.application.spring_boot
      description = "ALB to ECS services"
    }
    "public_outbound_130" = {
      subnet_type = "public"
      direction   = "outbound"
      rule_number = 130
      protocol    = "tcp"
      action      = "allow"
      cidr_block  = "0.0.0.0/0"
      from_port   = local.port_ranges.ephemeral.from
      to_port     = local.port_ranges.ephemeral.to
      description = "Ephemeral ports for return traffic"
    }

    # Private App Subnet Rules (Application Layer)
    "private_app_inbound_100" = {
      subnet_type = "private_app"
      direction   = "inbound"
      rule_number = 100
      protocol    = "tcp"
      action      = "allow"
      cidr_block  = var.vpc_cidr
      from_port   = local.port_ranges.application.spring_boot
      to_port     = local.port_ranges.application.spring_boot
      description = "Spring Boot from ALB"
    }
    "private_app_inbound_110" = {
      subnet_type = "private_app"
      direction   = "inbound"
      rule_number = 110
      protocol    = "tcp"
      action      = "allow"
      cidr_block  = var.vpc_cidr
      from_port   = local.port_ranges.application.admin
      to_port     = local.port_ranges.application.admin
      description = "Admin server access"
    }
    "private_app_inbound_120" = {
      subnet_type = "private_app"
      direction   = "inbound"
      rule_number = 120
      protocol    = "tcp"
      action      = "allow"
      cidr_block  = "0.0.0.0/0"
      from_port   = local.port_ranges.ephemeral.from
      to_port     = local.port_ranges.ephemeral.to
      description = "Ephemeral ports for internet responses"
    }
    "private_app_outbound_100" = {
      subnet_type = "private_app"
      direction   = "outbound"
      rule_number = 100
      protocol    = "tcp"
      action      = "allow"
      cidr_block  = "0.0.0.0/0"
      from_port   = local.port_ranges.web.https
      to_port     = local.port_ranges.web.https
      description = "HTTPS to internet (ECR, updates)"
    }
    "private_app_outbound_110" = {
      subnet_type = "private_app"
      direction   = "outbound"
      rule_number = 110
      protocol    = "tcp"
      action      = "allow"
      cidr_block  = var.vpc_cidr
      from_port   = local.port_ranges.database.mysql
      to_port     = local.port_ranges.database.mysql
      description = "MySQL to Aurora"
    }
    "private_app_outbound_120" = {
      subnet_type = "private_app"
      direction   = "outbound"
      rule_number = 120
      protocol    = "tcp"
      action      = "allow"
      cidr_block  = var.vpc_cidr
      from_port   = local.port_ranges.web.https
      to_port     = local.port_ranges.web.https
      description = "HTTPS to VPC endpoints"
    }
    "private_app_outbound_130" = {
      subnet_type = "private_app"
      direction   = "outbound"
      rule_number = 130
      protocol    = "tcp"
      action      = "allow"
      cidr_block  = "0.0.0.0/0"
      from_port   = local.port_ranges.ephemeral.from
      to_port     = local.port_ranges.ephemeral.to
      description = "Ephemeral ports for responses"
    }

    # Private DB Subnet Rules (Data Layer - Maximum Security)
    "private_db_inbound_100" = {
      subnet_type = "private_db"
      direction   = "inbound"
      rule_number = 100
      protocol    = "tcp"
      action      = "allow"
      cidr_block  = var.vpc_cidr
      from_port   = local.port_ranges.database.mysql
      to_port     = local.port_ranges.database.mysql
      description = "MySQL from ECS services only"
    }
    "private_db_outbound_100" = {
      subnet_type = "private_db"
      direction   = "outbound"
      rule_number = 100
      protocol    = "tcp"
      action      = "allow"
      cidr_block  = var.vpc_cidr
      from_port   = local.port_ranges.ephemeral.from
      to_port     = local.port_ranges.ephemeral.to
      description = "MySQL responses to ECS services"
    }
  }
}

# ==========================================
# NACL 리소스 생성 (Single Responsibility)
# ==========================================

resource "aws_network_acl" "this" {
  for_each = local.subnet_types

  vpc_id     = var.vpc_id
  subnet_ids = each.value.subnet_ids

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-${each.value.name_suffix}-nacl"
    Environment = var.environment
    Tier        = each.value.tier
    Purpose     = each.value.purpose
    # Well-Architected: Cost Optimization
    CostCenter = var.cost_center
    Owner      = var.owner
    # Well-Architected: Security
    SecurityLevel = each.key == "private_db" ? "high" : each.key == "private_app" ? "medium" : "standard"
    # Well-Architected: Operational Excellence
    ManagedBy   = "terraform"
    LastUpdated = timestamp()
  })

  lifecycle {
    ignore_changes = [tags["LastUpdated"]]
  }
}

# ==========================================
# NACL 규칙 생성 (Clean Code: 단순한 for_each)
# ==========================================

resource "aws_network_acl_rule" "this" {
  for_each = local.network_rules

  network_acl_id = aws_network_acl.this[each.value.subnet_type].id
  rule_number    = each.value.rule_number
  protocol       = each.value.protocol
  rule_action    = each.value.action
  cidr_block     = each.value.cidr_block
  from_port      = each.value.from_port
  to_port        = each.value.to_port
  egress         = each.value.direction == "outbound"

  # Well-Architected: Operational Excellence
  lifecycle {
    create_before_destroy = true
  }
}

# ==========================================
# 보안 강화 규칙 (Security Pillar)
# ==========================================

# 기본 거부 규칙 (Explicit Deny)
resource "aws_network_acl_rule" "default_deny_inbound" {
  for_each = local.subnet_types

  network_acl_id = aws_network_acl.this[each.key].id
  rule_number    = 32767 # 최대 규칙 번호 (마지막 규칙)
  protocol       = "-1"  # 모든 프로토콜
  rule_action    = "deny"
  cidr_block     = "0.0.0.0/0"
  egress         = false

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_network_acl_rule" "default_deny_outbound" {
  for_each = local.subnet_types

  network_acl_id = aws_network_acl.this[each.key].id
  rule_number    = 32767 # 최대 규칙 번호 (마지막 규칙)
  protocol       = "-1"  # 모든 프로토콜
  rule_action    = "deny"
  cidr_block     = "0.0.0.0/0"
  egress         = true

  lifecycle {
    create_before_destroy = true
  }
}

# ==========================================
# 모니터링 및 로깅 (Operational Excellence)
# ==========================================

# VPC Flow Logs for NACL monitoring
resource "aws_flow_log" "nacl_monitoring" {
  count = var.enable_flow_logs ? 1 : 0

  iam_role_arn    = var.flow_logs_role_arn
  log_destination = var.flow_logs_destination
  traffic_type    = "ALL"
  vpc_id          = var.vpc_id

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-nacl-flow-logs"
    Purpose     = "NACL traffic monitoring and security analysis"
    Environment = var.environment
  })
}

# CloudWatch 메트릭 필터 (보안 이벤트 감지)
resource "aws_cloudwatch_log_metric_filter" "nacl_denies" {
  count = var.enable_flow_logs && var.enable_security_monitoring ? 1 : 0

  name           = "${var.name_prefix}-nacl-denies"
  log_group_name = var.flow_logs_log_group_name
  pattern        = "[version, account, eni, source, destination, srcport, destport, protocol, packets, bytes, windowstart, windowend, action=\"REJECT\", flowlogstatus]"

  metric_transformation {
    name      = "NACLDeniedConnections"
    namespace = "Security/NACL"
    value     = "1"
  }
}

# CloudWatch 알람 (보안 이벤트 알림)
resource "aws_cloudwatch_metric_alarm" "nacl_security_alert" {
  count = var.enable_security_monitoring ? 1 : 0

  alarm_name          = "${var.name_prefix}-nacl-security-alert"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "NACLDeniedConnections"
  namespace           = "Security/NACL"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.security_alert_threshold
  alarm_description   = "This metric monitors NACL denied connections for security threats"
  alarm_actions       = var.alarm_actions

  tags = var.tags
}