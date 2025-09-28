# ECS 태스크 보안 그룹
resource "aws_security_group" "ecs" {
  name        = "${var.name_prefix}-ecs-sg"
  description = "ECS 태스크용 보안 그룹"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-ecs-sg"
    Environment = var.environment
    Tier        = "app"
  })
}

# ALB SG에서 ECS 태스크 포트로 인바운드 허용 (ALB SG가 제공된 경우 선택 사항)
resource "aws_vpc_security_group_ingress_rule" "ecs_in_from_alb" {
  count = var.alb_security_group_id != "" ? 1 : 0

  security_group_id            = aws_security_group.ecs.id
  description                  = "ALB SG에서 ${var.ecs_task_port}/tcp 인바운드 허용"
  referenced_security_group_id = var.alb_security_group_id
  from_port                    = var.ecs_task_port
  to_port                      = var.ecs_task_port
  ip_protocol                  = "tcp"
}

# ECS에서 VPC 인터페이스 엔드포인트로 443 송신 (선호) 또는 인터넷 443 (폴백)
resource "aws_vpc_security_group_egress_rule" "ecs_out_to_vpce_443" {
  count = var.vpce_security_group_id != "" ? 1 : 0

  security_group_id            = aws_security_group.ecs.id
  description                  = "VPCE SG로 HTTPS (443) 송신 허용"
  referenced_security_group_id = var.vpce_security_group_id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "ecs_out_to_internet_443_ipv4" {
  count = var.vpce_security_group_id == "" ? 1 : 0

  security_group_id = aws_security_group.ecs.id
  description       = "VPCE SG가 제공되지 않은 경우 인터넷 (IPv4)으로 HTTPS (443) 송신 허용"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "ecs_out_to_internet_443_ipv6" {
  count = var.vpce_security_group_id == "" ? 1 : 0

  security_group_id = aws_security_group.ecs.id
  description       = "VPCE SG가 제공되지 않은 경우 인터넷 (IPv6)으로 HTTPS (443) 송신 허용"
  cidr_ipv6         = "::/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

# RDS 보안 그룹
resource "aws_security_group" "rds" {
  name        = "${var.name_prefix}-rds-sg"
  description = "RDS MySQL용 보안 그룹"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-rds-sg"
    Environment = var.environment
    Tier        = "db"
  })
}

# ECS SG에서 DB 인그레스 허용
resource "aws_vpc_security_group_ingress_rule" "rds_in_from_ecs" {
  security_group_id            = aws_security_group.rds.id
  description                  = "ECS 태스크 SG에서 DB 포트 허용"
  referenced_security_group_id = aws_security_group.ecs.id
  from_port                    = var.rds_port
  to_port                      = var.rds_port
  ip_protocol                  = "tcp"
}

# (선택 사항) ECS에서 RDS로 송신 (상태 저장인 경우 엄격히 필요하지 않지만 최소 권한을 위해 강화)
resource "aws_vpc_security_group_egress_rule" "ecs_out_to_rds" {
  security_group_id            = aws_security_group.ecs.id
  description                  = "ECS에서 RDS 포트로 송신 허용"
  referenced_security_group_id = aws_security_group.rds.id
  from_port                    = var.rds_port
  to_port                      = var.rds_port
  ip_protocol                  = "tcp"
}