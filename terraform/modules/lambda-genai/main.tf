# Lambda GenAI 모듈 - GenAI ECS 서비스를 Lambda + Bedrock으로 대체 (단순화됨)
# 기본 서버리스 AI 기능만 제공

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

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-lambda-genai-execution-role"
    Environment = var.environment
    Type        = "iam-role"
  })
}

# Lambda 기본 실행 정책 연결
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
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
        Action = "*"
        Resource = "*"
      }
    ]
  })
}

# CloudWatch Logs 그룹
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.name_prefix}-genai-function"
  retention_in_days = 14

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-lambda-genai-logs"
    Environment = var.environment
    Service     = "lambda-genai"
  })
}

# Lambda 함수 코드를 위한 ZIP 파일 생성
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"

  source {
    content = templatefile("${path.module}/lambda_function.py", {
      bedrock_model_id = var.bedrock_model_id
      aws_region       = data.aws_region.current.name
    })
    filename = "lambda_function.py"
  }
}

# Lambda 함수 (기본 설정만)
resource "aws_lambda_function" "genai_function" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "${var.name_prefix}-genai-function"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  timeout       = 30
  memory_size   = 512

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      BEDROCK_MODEL_ID = var.bedrock_model_id
      LOG_LEVEL        = "INFO"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_cloudwatch_log_group.lambda_logs
  ]

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-genai-function"
    Environment = var.environment
    Service     = "lambda-genai"
    ManagedBy   = "terraform"
  })
}