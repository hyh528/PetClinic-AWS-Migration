# VPC 엔드포인트 모듈 메인 파일
# 이 파일은 프라이빗 서브넷에서 AWS 서비스에 안전하게 접근하기 위한 VPC 엔드포인트를 생성합니다.
# Interface 엔드포인트(ENI 기반)와 Gateway 엔드포인트(라우팅 기반)를 모두 지원합니다.

# 공통 정책: VPC 내부에서만 접근 허용
locals {
  vpc_endpoint_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "*"
        Resource  = "*"
        Condition = {
          StringEquals = {
            "aws:PrincipalVpc" = var.vpc_id
          }
        }
      }
    ]
  })

  # SSM 전용 정책: GetParameters 등 필요한 권한만 명시적으로 허용
  ssm_vpc_endpoint_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter",
          "ssm:DescribeParameters"
        ]
        Resource = "*"
        # Condition = {
        #   StringEquals = {
        #     "aws:PrincipalVpc" = var.vpc_id
        #   }
        # }
      }
    ]
  })

  # ECR 전용 정책: ECR 관련 모든 액션을 명시적으로 허용
  ecr_vpc_endpoint_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "ecr:*" # ECR 관련 모든 작업을 허용
        Resource  = "*"
        Condition = {
          StringEquals = {
            "aws:PrincipalVpc" = var.vpc_id
          }
        }
      }
    ]
  })
}

# ECR API VPC 엔드포인트 (Docker 이미지 메타데이터 관리)
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_endpoint_type   = "Interface"
  vpc_id              = var.vpc_id
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [var.vpc_endpoint_sg_id]
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  private_dns_enabled = true
  policy              = local.ecr_vpc_endpoint_policy

  tags = {
    Name        = "${var.project_name}-ecr-api-vpce"
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "ECS 태스크의 ECR API 접근"
  }
}

# ECR DKR VPC 엔드포인트 (Docker 이미지 레이어 다운로드)
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_endpoint_type   = "Interface"
  vpc_id              = var.vpc_id
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [var.vpc_endpoint_sg_id]
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  private_dns_enabled = true
  policy              = local.ecr_vpc_endpoint_policy

  tags = {
    Name        = "${var.project_name}-ecr-dkr-vpce"
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "ECS 태스크의 ECR Docker 레지스트리 접근"
  }
}

# CloudWatch Logs VPC 엔드포인트 (애플리케이션 로그 전송)
resource "aws_vpc_endpoint" "cloudwatch_logs" {
  vpc_endpoint_type   = "Interface"
  vpc_id              = var.vpc_id
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [var.vpc_endpoint_sg_id]
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  private_dns_enabled = true
  policy              = local.vpc_endpoint_policy

  tags = {
    Name        = "${var.project_name}-cloudwatch-logs-vpce"
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "ECS 태스크의 CloudWatch Logs 접근"
  }
}

# X-Ray VPC 엔드포인트 (분산 추적 데이터 전송)
resource "aws_vpc_endpoint" "xray" {
  vpc_endpoint_type   = "Interface"
  vpc_id              = var.vpc_id
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [var.vpc_endpoint_sg_id]
  service_name        = "com.amazonaws.${var.aws_region}.xray"
  private_dns_enabled = true
  policy              = local.vpc_endpoint_policy

  tags = {
    Name        = "${var.project_name}-xray-vpce"
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "X-Ray 추적 데이터 전송"
  }
}

# Systems Manager (SSM) VPC 엔드포인트 (Parameter Store 접근)
resource "aws_vpc_endpoint" "ssm" {
  vpc_endpoint_type   = "Interface"
  vpc_id              = var.vpc_id
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [var.vpc_endpoint_sg_id]
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  private_dns_enabled = true
  policy              = local.ssm_vpc_endpoint_policy

  tags = {
    Name        = "${var.project_name}-ssm-vpce"
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "설정 관리를 위한 Parameter Store 접근"
  }
}

# Secrets Manager VPC 엔드포인트 (민감 정보 접근)
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_endpoint_type   = "Interface"
  vpc_id              = var.vpc_id
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [var.vpc_endpoint_sg_id]
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  private_dns_enabled = true
  policy              = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-secretsmanager-vpce"
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "민감 데이터를 위한 Secrets Manager 접근"
  }
}

# KMS VPC 엔드포인트
resource "aws_vpc_endpoint" "kms" {
  # KMS 서비스의 엔드포인트 서비스 이름입니다.
  vpc_endpoint_type   = "Interface"
  vpc_id              = var.vpc_id
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [var.vpc_endpoint_sg_id]
  service_name        = "com.amazonaws.${var.aws_region}.kms"
  private_dns_enabled = true

  policy = local.vpc_endpoint_policy

  tags = {
    Name        = "${var.project_name}-kms-vpce"
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "암호화/복호화를 위한 KMS 접근"
  }
}

# S3 Gateway VPC 엔드포인트 (ECR이 S3를 사용하므로 필수, 비용 효율적)
resource "aws_vpc_endpoint" "s3" {
  vpc_endpoint_type = "Gateway"
  vpc_id            = var.vpc_id
  route_table_ids   = var.private_route_table_ids
  service_name      = "com.amazonaws.${var.aws_region}.s3"

  # Gateway 엔드포인트는 보안 그룹이나 서브넷 설정 불필요
  tags = {
    Name        = "${var.project_name}-s3-gateway-vpce"
    Project     = var.project_name
    Environment = var.environment
  }
}

# CloudWatch Monitoring VPC 엔드포인트 (메트릭 전송용)
resource "aws_vpc_endpoint" "cloudwatch_monitoring" {
  vpc_endpoint_type   = "Interface"
  vpc_id              = var.vpc_id
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [var.vpc_endpoint_sg_id]
  service_name        = "com.amazonaws.${var.aws_region}.monitoring"
  private_dns_enabled = true

  policy = local.vpc_endpoint_policy

  tags = {
    Name        = "${var.project_name}-cloudwatch-monitoring-vpce"
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "CloudWatch 메트릭 전송"
  }
}
