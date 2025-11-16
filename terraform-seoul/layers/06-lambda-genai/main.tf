# =============================================================================
# Lambda GenAI Layer - GenAI ECS 서비스를 Lambda + Bedrock으로 대체 (단순화됨)
# =============================================================================
# 목적: 서버리스 AI 서비스 제공 (기본 기능만)
# 의존성: 01-network, 02-security 레이어

# 공통 로컬 변수
locals {
  # Lambda GenAI 공통 설정
  layer_common_tags = merge(var.tags, {
    Layer     = "06-lambda-genai"
    Component = "serverless-ai"
    Purpose   = "genai-service-replacement"
  })
}

# =============================================================================
# 데이터 소스 - 다른 레이어에서 생성된 리소스 참조
# =============================================================================

# VPC 정보 가져오기
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = var.backend_bucket
    key    = "seoul-dev/01-network/terraform.tfstate"
    region = var.aws_region
  }
}

# 데이터베이스 정보 가져오기
data "terraform_remote_state" "database" {
  backend = "s3"
  config = {
    bucket = var.backend_bucket
    key    = "seoul-dev/03-database/terraform.tfstate"
    region = var.aws_region
  }
}

# =============================================================================
# Lambda GenAI 완전한 인프라 (Terraform 관리)
# =============================================================================

# 현재 AWS 계정 정보
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Lambda 함수 실행을 위한 IAM 역할
resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.name_prefix}-lambda-genai-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.layer_common_tags, {
    Name = "${var.name_prefix}-lambda-genai-execution-role"
    Type = "iam-role"
  })
}

# Lambda 기본 실행 정책 연결
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_execution_role.name
}

# VPC 접근을 위한 정책 연결
resource "aws_iam_role_policy_attachment" "lambda_vpc_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  role       = aws_iam_role.lambda_execution_role.name
}

# Bedrock 모델 호출을 위한 IAM 정책
resource "aws_iam_role_policy" "bedrock_invoke_policy" {
  name = "${var.name_prefix}-lambda-bedrock-invoke-policy"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = [
          # 서울 리전 foundation models
          "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/*",
          # Cross-region inference profiles (US 리전)
          "arn:aws:bedrock:us-east-1:${data.aws_caller_identity.current.account_id}:inference-profile/*",
          "arn:aws:bedrock:us-west-2:${data.aws_caller_identity.current.account_id}:inference-profile/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:GetFoundationModel",
          "bedrock:ListFoundationModels"
        ]
        Resource = "*"
      }
    ]
  })
}

# RDS Data API 접근을 위한 IAM 정책
resource "aws_iam_role_policy" "rds_data_api_policy" {
  name = "${var.name_prefix}-lambda-rds-data-api-policy"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds-data:ExecuteStatement",
          "rds-data:BatchExecuteStatement",
          "rds-data:BeginTransaction",
          "rds-data:CommitTransaction",
          "rds-data:RollbackTransaction"
        ]
        Resource = [
          "arn:aws:rds:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster:${var.name_prefix}-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:rds-db-credentials/*",
          "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.name_prefix}-*",
          "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:rds!cluster-*"
        ]
      }
    ]
  })
}

# CloudWatch Logs 그룹
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.name_prefix}-genai-function"
  retention_in_days = 14

  tags = merge(local.layer_common_tags, {
    Name    = "${var.name_prefix}-lambda-genai-logs"
    Service = "lambda-genai"
  })
}

# Lambda 함수용 보안 그룹
resource "aws_security_group" "lambda_sg" {
  name        = "${var.name_prefix}-lambda-genai-sg"
  description = "Lambda GenAI function security group"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  tags = merge(local.layer_common_tags, {
    Name = "${var.name_prefix}-lambda-genai-sg"
  })
}

# HTTPS 아웃바운드 규칙 (Bedrock API 호출용)
resource "aws_security_group_rule" "lambda_https_outbound" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.lambda_sg.id
  description       = "HTTPS outbound for Bedrock API"
}

# MySQL/Aurora 데이터베이스 접근을 위한 아웃바운드 규칙
resource "aws_security_group_rule" "lambda_mysql_outbound" {
  type              = "egress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  cidr_blocks       = ["10.0.0.0/16"]
  security_group_id = aws_security_group.lambda_sg.id
  description       = "MySQL/Aurora database access within VPC"
}

# DNS 해석을 위한 아웃바운드 규칙 (UDP)
resource "aws_security_group_rule" "lambda_dns_udp_outbound" {
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.lambda_sg.id
  description       = "DNS resolution (UDP)"
}

# DNS 해석을 위한 아웃바운드 규칙 (TCP)
resource "aws_security_group_rule" "lambda_dns_tcp_outbound" {
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.lambda_sg.id
  description       = "DNS resolution (TCP)"
}

# Lambda 함수 패키지 생성
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"

  source {
    content  = file("${path.module}/lambda_function.py")
    filename = "lambda_function.py"
  }
}

# Lambda 함수 (완전한 기능)
resource "aws_lambda_function" "genai_function" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "${var.name_prefix}-genai-function"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  timeout       = 60
  memory_size   = 512

  # VPC 설정 - Aurora 데이터베이스에 접근하기 위해 필요
  vpc_config {
    subnet_ids         = values(data.terraform_remote_state.network.outputs.private_app_subnet_ids)
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      BEDROCK_MODEL_ID = var.bedrock_model_id
      LOG_LEVEL        = "INFO"
      DB_CLUSTER_ARN   = data.terraform_remote_state.database.outputs.cluster_arn
      DB_SECRET_ARN    = data.terraform_remote_state.database.outputs.master_user_secret_name
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy_attachment.lambda_vpc_execution,
    aws_cloudwatch_log_group.lambda_logs
  ]

  tags = merge(local.layer_common_tags, {
    Name    = "${var.name_prefix}-genai-function"
    Service = "lambda-genai"
  })
}
