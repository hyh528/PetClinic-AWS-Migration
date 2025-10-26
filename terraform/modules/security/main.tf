# ECS 태스크 보안 그룹
resource "aws_security_group" "ecs" {
  name        = "${var.name_prefix}-ecs-security-group"
  description = "Security group for ECS tasks"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-ecs-security-group"
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
  description                  = "Allow HTTPS (443) outbound to VPCE SG"
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

# Aurora 클러스터 보안 그룹
resource "aws_security_group" "rds" {
  name        = "${var.name_prefix}-aurora-security-group"
  description = "Security group for Aurora MySQL cluster"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-aurora-security-group"
    Environment = var.environment
    Tier        = "db"
  })
}

# ECS SG에서 Aurora 클러스터 인그레스 허용
resource "aws_vpc_security_group_ingress_rule" "rds_in_from_ecs" {
  security_group_id            = aws_security_group.rds.id
  description                  = "Allow Aurora port from ECS task SG"
  referenced_security_group_id = aws_security_group.ecs.id
  from_port                    = var.rds_port
  to_port                      = var.rds_port
  ip_protocol                  = "tcp"
}

# Lambda SG에서 Aurora 클러스터 인그레스 허용 (Lambda GenAI 함수용)
resource "aws_vpc_security_group_ingress_rule" "rds_in_from_lambda" {
  count = var.lambda_security_group_id != "" ? 1 : 0

  security_group_id            = aws_security_group.rds.id
  description                  = "Allow Aurora port from Lambda GenAI SG"
  referenced_security_group_id = var.lambda_security_group_id
  from_port                    = var.rds_port
  to_port                      = var.rds_port
  ip_protocol                  = "tcp"
}

# (선택 사항) ECS에서 Aurora로 송신 (상태 저장인 경우 엄격히 필요하지 않지만 최소 권한을 위해 강화)
resource "aws_vpc_security_group_egress_rule" "ecs_out_to_rds" {
  security_group_id            = aws_security_group.ecs.id
  description                  = "Allow outbound to Aurora port from ECS"
  referenced_security_group_id = aws_security_group.rds.id
  from_port                    = var.rds_port
  to_port                      = var.rds_port
  ip_protocol                  = "tcp"
}

# =============================================================================
# IAM 정책들 (애플리케이션별 세분화된 권한)
# =============================================================================

# RDS 시크릿 접근 정책
resource "aws_iam_policy" "rds_secret_access" {
  name        = "${var.name_prefix}-rds-secret-access"
  description = "RDS 관리형 데이터베이스 시크릿 접근 정책"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GetRDSSecrets"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:*:secret:rds-db-credentials/*",
          "arn:aws:secretsmanager:${var.aws_region}:*:secret:${var.name_prefix}-*"
        ]
      },
      {
        Sid    = "DecryptSecrets"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "arn:aws:kms:${var.aws_region}:*:key/*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${var.aws_region}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name      = "${var.name_prefix}-rds-secret-access"
    Component = "iam-policy"
    Purpose   = "rds-secret-access"
  })
}

# Parameter Store 접근 정책
resource "aws_iam_policy" "parameter_store_access" {
  name        = "${var.name_prefix}-parameter-store-access"
  description = "Parameter Store 설정 정보 접근 정책"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GetParameters"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          "arn:aws:ssm:${var.aws_region}:*:parameter/${var.name_prefix}/*",
          "arn:aws:ssm:${var.aws_region}:*:parameter/petclinic/*"
        ]
      },
      {
        Sid    = "DecryptParameters"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "arn:aws:kms:${var.aws_region}:*:key/*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "ssm.${var.aws_region}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name      = "${var.name_prefix}-parameter-store-access"
    Component = "iam-policy"
    Purpose   = "parameter-store-access"
  })
}

# CloudWatch Logs 접근 정책
resource "aws_iam_policy" "cloudwatch_logs_access" {
  name        = "${var.name_prefix}-cloudwatch-logs-access"
  description = "CloudWatch Logs 접근 정책"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogsAccess"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:*:log-group:/ecs/${var.name_prefix}*",
          "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${var.name_prefix}*"
        ]
      }
    ]
  })

  tags = merge(var.tags, {
    Name      = "${var.name_prefix}-cloudwatch-logs-access"
    Component = "iam-policy"
    Purpose   = "cloudwatch-logs"
  })
}