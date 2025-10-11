data "aws_region" "current" {}

# 인터페이스 엔드포인트용 보안 그룹 (443)
resource "aws_security_group" "vpce" {
  name        = "${var.name_prefix}-vpce-sg"
  description = "VPC 인터페이스 엔드포인트용 보안 그룹"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-vpce-sg"
    Environment = var.environment
    Tier        = "network-endpoints"
  })
}

# 인터페이스 엔드포인트로 VPC IPv4 CIDR에서 HTTPS 허용
resource "aws_vpc_security_group_ingress_rule" "vpce_https_ipv4" {
  security_group_id = aws_security_group.vpce.id

  description = "VPC IPv4 CIDR에서 HTTPS 허용"
  cidr_ipv4   = var.vpc_cidr
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
}

# 엔드포인트 SG에서 모든 아웃바운드 허용 (응답 및 이그레스)
resource "aws_vpc_security_group_egress_rule" "vpce_all_out" {
  security_group_id = aws_security_group.vpce.id

  description = "모든 아웃바운드 허용"
  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

# S3 게이트웨이 엔드포인트 (RT에 연결)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    var.public_route_table_id == "" ? [] : [var.public_route_table_id],
    values(var.private_app_route_table_ids),
    values(var.private_db_route_table_ids)
  )

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-s3-gw-endpoint"
    Environment = var.environment
    Tier        = "network-endpoints"
  })
}

# 인터페이스 엔드포인트 (ECR API/DRK, Logs, X-Ray, SSM, Secrets, KMS 등)
locals {
  interface_services_full = [
    for s in var.interface_services :
    "com.amazonaws.${data.aws_region.current.name}.${s}"
  ]
}

resource "aws_vpc_endpoint" "interface" {
  for_each          = toset(local.interface_services_full)
  vpc_id            = var.vpc_id
  service_name      = each.value
  vpc_endpoint_type = "Interface"

  private_dns_enabled = true
  subnet_ids          = var.interface_subnet_ids
  security_group_ids  = [aws_security_group.vpce.id]

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-vpce-${replace(each.value, "com.amazonaws.${data.aws_region.current.name}.", "")}"
    Environment = var.environment
    Tier        = "network-endpoints"
  })
}
