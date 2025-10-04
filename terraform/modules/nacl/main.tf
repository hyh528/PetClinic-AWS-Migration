# NACL (Network Access Control List) 모듈 메인 파일
# 이 파일은 지정된 VPC에 네트워크 ACL을 생성하고 서브넷에 연결합니다.
# IPv4/IPv6 듀얼스택 지원 및 AWS 권장 보안 모범 사례를 적용합니다.

# 네트워크 ACL을 생성합니다.
resource "aws_network_acl" "this" {
  vpc_id = var.vpc_id # NACL이 속할 VPC의 ID

  tags = {
    Name        = "${var.name_prefix}-${var.environment}-nacl" # NACL의 이름 태그
    Environment = var.environment                              # 환경 태그 (예: dev, prod)
    ManagedBy   = "terraform"                                  # Terraform으로 관리됨을 명시
  }
}

# NACL 타입에 따른 인바운드/아웃바운드 규칙을 정의합니다.
# 이 규칙들은 'To-Be 아키텍처 인프라 설계 초안 문서.md'를 기반으로 합니다.
locals {
  # Public Subnet용 인바운드 규칙 (ALB, NAT Gateway 위치)
  public_ingress_rules = {
    "http_ipv4" = {
      rule_no    = 100
      action     = "allow"
      protocol   = "tcp"
      cidr_block = "0.0.0.0/0" # 전 세계에서 HTTP 접근 허용
      from_port  = 80
      to_port    = 80
    },
    "https_ipv4" = {
      rule_no    = 110
      action     = "allow"
      protocol   = "tcp"
      cidr_block = "0.0.0.0/0" # 전 세계에서 HTTPS 접근 허용
      from_port  = 443
      to_port    = 443
    },
    "ephemeral_return_traffic" = {
      rule_no    = 120
      action     = "allow"
      protocol   = "tcp"
      cidr_block = var.vpc_cidr # VPC 내부에서 시작된 응답 트래픽 허용 (AWS 권장 에페메랄 포트 범위)
      from_port  = 32768
      to_port    = 65535
    }
  }

  # Public Subnet용 아웃바운드 규칙 (ALB에서 Private App으로, NAT Gateway 트래픽)
  public_egress_rules = {
    "all_outbound_ipv4" = {
      rule_no    = 100
      action     = "allow"
      protocol   = "-1"
      cidr_block = "0.0.0.0/0" # 모든 아웃바운드 트래픽 허용 (ALB → App, NAT Gateway 기능)
      from_port  = 0
      to_port    = 0
    }
  }

  # Private App Subnet용 인바운드 규칙 (ECS Fargate 서비스 위치)
  private_app_ingress_rules = {
    "alb_to_app" = {
      rule_no    = 100
      action     = "allow"
      protocol   = "tcp"
      cidr_block = var.vpc_cidr # ALB에서 ECS 서비스로의 트래픽 허용 (8080 포트)
      from_port  = 8080
      to_port    = 8080
    },
    "vpc_internal_communication" = {
      rule_no    = 110
      action     = "allow"
      protocol   = "-1"
      cidr_block = var.vpc_cidr # VPC 내부 통신 허용 (DB 접근, VPC Endpoint 통신 등)
      from_port  = 0
      to_port    = 0
    },
    "ephemeral_return_traffic" = {
      rule_no    = 120
      action     = "allow"
      protocol   = "tcp"
      cidr_block = "0.0.0.0/0" # 외부 API 호출에 대한 응답 허용 (ECR Pull, 패키지 다운로드 등)
      from_port  = 32768
      to_port    = 65535
    }
  }

  # Private App Subnet용 아웃바운드 규칙 (ECS 서비스의 외부 통신)
  private_app_egress_rules = {
    "all_outbound" = {
      rule_no    = 100
      action     = "allow"
      protocol   = "-1"
      cidr_block = "0.0.0.0/0" # DB 접근, VPC Endpoint 통신, NAT Gateway를 통한 외부 API 호출
      from_port  = 0
      to_port    = 0
    }
  }

  # Private DB Subnet용 인바운드 규칙 (Aurora MySQL 클러스터 위치)
  private_db_ingress_rules = {
    "app_to_db" = {
      rule_no    = 100
      action     = "allow"
      protocol   = "tcp"
      cidr_block = var.vpc_cidr # ECS 서비스에서 Aurora MySQL로의 연결 허용 (3306 포트)
      from_port  = 3306
      to_port    = 3306
    },
    "vpc_internal_communication" = {
      rule_no    = 110
      action     = "allow"
      protocol   = "-1"
      cidr_block = var.vpc_cidr # VPC 내부 관리 트래픽 허용 (백업, 모니터링 등)
      from_port  = 0
      to_port    = 0
    },
    "ephemeral_return_traffic" = {
      rule_no    = 120
      action     = "allow"
      protocol   = "tcp"
      cidr_block = "0.0.0.0/0" # IPv6 Egress-only IGW를 통한 응답 트래픽 (패치, 업데이트 응답)
      from_port  = 32768
      to_port    = 65535
    }
  }

  # Private DB Subnet용 아웃바운드 규칙 (보안 강화: 최소 권한 원칙 적용)
  private_db_egress_rules = {
    "vpc_internal_response" = {
      rule_no    = 100
      action     = "allow"
      protocol   = "tcp"
      cidr_block = var.vpc_cidr # VPC 내부 응답 트래픽만 허용 (App 서버로의 응답)
      from_port  = 32768
      to_port    = 65535
    },
    "ipv6_egress_only" = {
      rule_no    = 110
      action     = "allow"
      protocol   = "tcp"
      cidr_block = "::/0" # IPv6 Egress-only IGW를 통한 아웃바운드 (패치, 업데이트용)
      from_port  = 443
      to_port    = 443
    }
  }

  # nacl_type에 따라 선택될 규칙 세트 맵
  all_nacl_rules = {
    "public" = {
      ingress = local.public_ingress_rules
      egress  = local.public_egress_rules
    },
    "private-app" = {
      ingress = local.private_app_ingress_rules
      egress  = local.private_app_egress_rules
    },
    "private-db" = {
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
