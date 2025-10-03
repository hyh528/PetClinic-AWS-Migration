# NACL (Network Access Control List) 모듈 메인 파일
# 이 파일은 지정된 VPC에 네트워크 ACL을 생성하고 서브넷에 연결합니다.

# 네트워크 ACL을 생성합니다.
resource "aws_network_acl" "this" {
  vpc_id = var.vpc_id # NACL이 속할 VPC의 ID

  tags = {
    Name        = "${var.name_prefix}-${var.environment}-nacl" # NACL의 이름 태그
    Environment = var.environment                               # 환경 태그 (예: dev, prod)
    ManagedBy   = "terraform"                                   # Terraform으로 관리됨을 명시
  }
}

# NACL 타입에 따른 인바운드/아웃바운드 규칙을 정의합니다.
# 이 규칙들은 'To-Be 아키텍처 인프라 설계 초안 문서.md'를 기반으로 합니다.
locals {
  # Public Subnet용 인바운드 규칙
  public_ingress_rules = {
    "http" = {
      rule_no    = 100
      action     = "allow"
      protocol   = "tcp"
      cidr_block = "0.0.0.0/0"
      from_port  = 80
      to_port    = 80
    },
    "https" = {
      rule_no    = 110
      action     = "allow"
      protocol   = "tcp"
      cidr_block = "0.0.0.0/0"
      from_port  = 443
      to_port    = 443
    },
    "ephemeral_return_traffic" = {
      rule_no    = 120
      action     = "allow"
      protocol   = "tcp"
      cidr_block = var.vpc_cidr # VPC 내부에서 시작된 응답 트래픽 허용
      from_port  = 1024
      to_port    = 65535
    }
  }

  # Public Subnet용 아웃바운드 규칙
  public_egress_rules = {
    "all_outbound" = {
      rule_no    = 100
      action     = "allow"
      protocol   = "-1"
      cidr_block = "0.0.0.0/0"
      from_port  = 0
      to_port    = 0
    }
  }

  # Private App Subnet용 인바운드 규칙
  private_app_ingress_rules = {
    "alb_to_app" = {
      rule_no    = 100
      action     = "allow"
      protocol   = "tcp"
      cidr_block = var.vpc_cidr # ALB가 위치한 VPC CIDR로부터의 트래픽 허용
      from_port  = 8080
      to_port    = 8080
    },
    "vpc_internal_communication" = {
      rule_no    = 110
      action     = "allow"
      protocol   = "-1"
      cidr_block = var.vpc_cidr # VPC 내부 통신 허용 (DB, VPC Endpoint 등)
      from_port  = 0
      to_port    = 0
    },
    "ephemeral_return_traffic" = {
      rule_no    = 120
      action     = "allow"
      protocol   = "tcp"
      cidr_block = "0.0.0.0/0" # 외부로 나간 트래픽에 대한 응답 허용
      from_port  = 1024
      to_port    = 65535
    }
  }

  # Private App Subnet용 아웃바운드 규칙
  private_app_egress_rules = {
    "all_outbound" = {
      rule_no    = 100
      action     = "allow"
      protocol   = "-1"
      cidr_block = "0.0.0.0/0"
      from_port  = 0
      to_port    = 0
    }
  }

  # Private DB Subnet용 인바운드 규칙
  private_db_ingress_rules = {
    "app_to_db" = {
      rule_no    = 100
      action     = "allow"
      protocol   = "tcp"
      cidr_block = var.vpc_cidr # Private App Subnet이 위치한 VPC CIDR로부터의 트래픽 허용
      from_port  = 3306
      to_port    = 3306
    },
    "vpc_internal_communication" = {
      rule_no    = 110
      action     = "allow"
      protocol   = "-1"
      cidr_block = var.vpc_cidr # VPC 내부 통신 허용
      from_port  = 0
      to_port    = 0
    },
    "ephemeral_return_traffic" = {
      rule_no    = 120
      action     = "allow"
      protocol   = "tcp"
      cidr_block = "0.0.0.0/0" # 외부로 나간 트래픽에 대한 응답 허용 (Egress-only IGW 등)
      from_port  = 1024
      to_port    = 65535
    }
  }

  # Private DB Subnet용 아웃바운드 규칙
  private_db_egress_rules = {
    "all_outbound_to_vpc" = {
      rule_no    = 100
      action     = "allow"
      protocol   = "-1"
      cidr_block = var.vpc_cidr # VPC 내부로 나가는 모든 트래픽 허용
      from_port  = 0
      to_port    = 0
    },
    "ephemeral_outbound_to_internet" = {
      rule_no    = 110
      action     = "allow"
      protocol   = "tcp"
      cidr_block = "0.0.0.0/0" # Egress-only IGW를 통한 IPv6 아웃바운드 등
      from_port  = 1024
      to_port    = 65535
    }
  }

  # nacl_type에 따라 선택될 규칙 세트 맵
  all_nacl_rules = {
    "public"      = {
      ingress = local.public_ingress_rules
      egress  = local.public_egress_rules
    },
    "private-app" = {
      ingress = local.private_app_ingress_rules
      egress  = local.private_app_egress_rules
    },
    "private-db"  = {
      ingress = local.private_db_ingress_rules
      egress  = local.private_db_egress_rules
    },
  }

  # 현재 nacl_type에 해당하는 규칙 세트
  current_nacl_rules = lookup(local.all_nacl_rules, var.nacl_type, {
    ingress = {},
    egress  = {}
  })
}

# 인바운드(Ingress) 규칙을 정의합니다.
# nacl_type에 따라 선택된 규칙 세트의 각 항목에 대해 aws_network_acl_rule 리소스를 생성합니다.
resource "aws_network_acl_rule" "ingress" {
  for_each = local.current_nacl_rules.ingress

  network_acl_id = aws_network_acl.this.id
  rule_number    = each.value.rule_no
  egress         = false
  rule_action    = each.value.action
  protocol       = each.value.protocol
  cidr_block     = each.value.cidr_block
  from_port      = each.value.from_port
  to_port        = each.value.to_port
}

# 아웃바운드(Egress) 규칙을 정의합니다.
# nacl_type에 따라 선택된 규칙 세트의 각 항목에 대해 aws_network_acl_rule 리소스를 생성합니다.
resource "aws_network_acl_rule" "egress" {
  for_each = local.current_nacl_rules.egress

  network_acl_id = aws_network_acl.this.id
  rule_number    = each.value.rule_no
  egress         = true
  rule_action    = each.value.action
  protocol       = each.value.protocol
  cidr_block     = each.value.cidr_block
  from_port      = each.value.from_port
  to_port        = each.value.to_port
}

# NACL과 서브넷을 연결합니다.
# subnet_ids 변수에 정의된 각 서브넷 ID에 대해 aws_network_acl_association 리소스를 생성합니다.
resource "aws_network_acl_association" "this" {
  for_each = toset(var.subnet_ids)

  network_acl_id = aws_network_acl.this.id
  subnet_id      = each.value
}