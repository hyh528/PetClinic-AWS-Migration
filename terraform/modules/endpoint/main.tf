# VPC 엔드포인트 모듈 메인 파일
# 이 파일은 프라이빗 서브넷에서 AWS 서비스에 안전하게 접근하기 위한 VPC 인터페이스 엔드포인트를 생성합니다.

# ECR API VPC 엔드포인트
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_endpoint_type = "Interface"
  vpc_id            = var.vpc_id
  subnet_ids        = var.private_subnet_ids
  security_group_ids = [var.vpc_endpoint_sg_id]
  service_name      = "com.amazonaws.${var.aws_region}.ecr.api"
  # 프라이빗 DNS 이름을 활성화합니다.
  private_dns_enabled = true

  # VPC 엔드포인트 태그입니다.
  tags = {
    Name        = "${var.project_name}-ecr-api-vpce"
    Project     = var.project_name
    Environment = var.environment
  }
}

# ECR DKR VPC 엔드포인트
resource "aws_vpc_endpoint" "ecr_dkr" {
  # ECR DKR 서비스의 엔드포인트 서비스 이름입니다.
  vpc_endpoint_type = "Interface"
  vpc_id            = var.vpc_id
  subnet_ids        = var.private_subnet_ids
  security_group_ids = [var.vpc_endpoint_sg_id]
  service_name      = "com.amazonaws.${var.aws_region}.ecr.dkr"
  private_dns_enabled = true

  tags = {
    Name        = "${var.project_name}-ecr-dkr-vpce"
    Project     = var.project_name
    Environment = var.environment
  }
}

# CloudWatch Logs VPC 엔드포인트
resource "aws_vpc_endpoint" "cloudwatch_logs" {
  # CloudWatch Logs 서비스의 엔드포인트 서비스 이름입니다.
  vpc_endpoint_type = "Interface"
  vpc_id            = var.vpc_id
  subnet_ids        = var.private_subnet_ids
  security_group_ids = [var.vpc_endpoint_sg_id]
  service_name      = "com.amazonaws.${var.aws_region}.logs"
  private_dns_enabled = true

  tags = {
    Name        = "${var.project_name}-cloudwatch-logs-vpce"
    Project     = var.project_name
    Environment = var.environment
  }
}

# X-Ray VPC 엔드포인트
resource "aws_vpc_endpoint" "xray" {
  # X-Ray 서비스의 엔드포인트 서비스 이름입니다.
  vpc_endpoint_type = "Interface"
  vpc_id            = var.vpc_id
  subnet_ids        = var.private_subnet_ids
  security_group_ids = [var.vpc_endpoint_sg_id]
  service_name      = "com.amazonaws.${var.aws_region}.xray"
  private_dns_enabled = true

  tags = {
    Name        = "${var.project_name}-xray-vpce"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Systems Manager (SSM) VPC 엔드포인트
resource "aws_vpc_endpoint" "ssm" {
  # SSM 서비스의 엔드포인트 서비스 이름입니다.
  vpc_endpoint_type = "Interface"
  vpc_id            = var.vpc_id
  subnet_ids        = var.private_subnet_ids
  security_group_ids = [var.vpc_endpoint_sg_id]
  service_name      = "com.amazonaws.${var.aws_region}.ssm"
  private_dns_enabled = true

  tags = {
    Name        = "${var.project_name}-ssm-vpce"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Secrets Manager VPC 엔드포인트
resource "aws_vpc_endpoint" "secretsmanager" {
  # Secrets Manager 서비스의 엔드포인트 서비스 이름입니다.
  vpc_endpoint_type = "Interface"
  vpc_id            = var.vpc_id
  subnet_ids        = var.private_subnet_ids
  security_group_ids = [var.vpc_endpoint_sg_id]
  service_name      = "com.amazonaws.${var.aws_region}.secretsmanager"
  private_dns_enabled = true

  tags = {
    Name        = "${var.project_name}-secretsmanager-vpce"
    Project     = var.project_name
    Environment = var.environment
  }
}

# KMS VPC 엔드포인트
resource "aws_vpc_endpoint" "kms" {
  # KMS 서비스의 엔드포인트 서비스 이름입니다.
  vpc_endpoint_type = "Interface"
  vpc_id            = var.vpc_id
  subnet_ids        = var.private_subnet_ids
  security_group_ids = [var.vpc_endpoint_sg_id]
  service_name      = "com.amazonaws.${var.aws_region}.kms"
  private_dns_enabled = true

  tags = {
    Name        = "${var.project_name}-kms-vpce"
    Project     = var.project_name
    Environment = var.environment
  }
}