# Network 레이어: VPC 기반 인프라

module "vpc" {
  source = "../../../modules/vpc"

  name_prefix = var.name_prefix
  environment = var.environment

  vpc_cidr    = var.vpc_cidr
  enable_ipv6 = var.enable_ipv6

  azs                      = var.azs
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  private_db_subnet_cidrs  = var.private_db_subnet_cidrs

  create_nat_per_az = var.create_nat_per_az

  tags = var.tags
}

# ==========================================
# VPC 엔드포인트: AWS 서비스 프라이빗 연결
# ==========================================
# 네트워크 연결성을 제공하는 리소스이므로 network 레이어에서 관리
# 모든 인터페이스 엔드포인트를 통합 관리

# VPC 엔드포인트용 보안 그룹
resource "aws_security_group" "vpc_endpoint" {
  name_prefix = "${var.name_prefix}-vpc-endpoint-"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-vpc-endpoint-sg"
    Environment = var.environment
  })
}

# Parameter Store용 인터페이스 엔드포인트
resource "aws_vpc_endpoint" "ssm" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type = "Interface"

  subnet_ids         = values(module.vpc.private_app_subnet_ids)
  security_group_ids = [aws_security_group.vpc_endpoint.id]

  private_dns_enabled = true

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-ssm-endpoint"
    Environment = var.environment
    Service     = "ssm"
  })
}

# Secrets Manager용 인터페이스 엔드포인트
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type = "Interface"

  subnet_ids         = values(module.vpc.private_app_subnet_ids)
  security_group_ids = [aws_security_group.vpc_endpoint.id]

  private_dns_enabled = true

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-secretsmanager-endpoint"
    Environment = var.environment
    Service     = "secretsmanager"
  })
}

# ECR API용 인터페이스 엔드포인트
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type = "Interface"

  subnet_ids         = values(module.vpc.private_app_subnet_ids)
  security_group_ids = [aws_security_group.vpc_endpoint.id]

  private_dns_enabled = true

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-ecr-api-endpoint"
    Environment = var.environment
    Service     = "ecr-api"
  })
}

# ECR DKR용 인터페이스 엔드포인트
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type = "Interface"

  subnet_ids         = values(module.vpc.private_app_subnet_ids)
  security_group_ids = [aws_security_group.vpc_endpoint.id]

  private_dns_enabled = true

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-ecr-dkr-endpoint"
    Environment = var.environment
    Service     = "ecr-dkr"
  })
}

# CloudWatch Logs용 인터페이스 엔드포인트
resource "aws_vpc_endpoint" "logs" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type = "Interface"

  subnet_ids         = values(module.vpc.private_app_subnet_ids)
  security_group_ids = [aws_security_group.vpc_endpoint.id]

  private_dns_enabled = true

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-logs-endpoint"
    Environment = var.environment
    Service     = "logs"
  })
}

# X-Ray용 인터페이스 엔드포인트
resource "aws_vpc_endpoint" "xray" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.xray"
  vpc_endpoint_type = "Interface"

  subnet_ids         = values(module.vpc.private_app_subnet_ids)
  security_group_ids = [aws_security_group.vpc_endpoint.id]

  private_dns_enabled = true

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-xray-endpoint"
    Environment = var.environment
    Service     = "xray"
  })
}

# KMS용 인터페이스 엔드포인트
resource "aws_vpc_endpoint" "kms" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.kms"
  vpc_endpoint_type = "Interface"

  subnet_ids         = values(module.vpc.private_app_subnet_ids)
  security_group_ids = [aws_security_group.vpc_endpoint.id]

  private_dns_enabled = true

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-kms-endpoint"
    Environment = var.environment
    Service     = "kms"
  })
}

# S3용 게이트웨이 엔드포인트 (모든 라우팅 테이블에 연결)
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = module.vpc.vpc_id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    [data.aws_route_table.public.id],
    values(data.aws_route_table.private_app),
    values(data.aws_route_table.private_db)
  )

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-s3-endpoint"
    Environment = var.environment
    Service     = "s3"
  })
}

# CloudWatch Monitoring용 인터페이스 엔드포인트
resource "aws_vpc_endpoint" "monitoring" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.monitoring"
  vpc_endpoint_type = "Interface"

  subnet_ids         = values(module.vpc.private_app_subnet_ids)
  security_group_ids = [aws_security_group.vpc_endpoint.id]

  private_dns_enabled = true

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-monitoring-endpoint"
    Environment = var.environment
    Service     = "monitoring"
  })
}

# 참고:
# - 보안(IAM, SG, VPC Endpoints)은 security/ 환경에서 관리
# - L7(예: ALB, ECS)은 application/ 환경에서 관리