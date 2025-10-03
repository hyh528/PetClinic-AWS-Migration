# Lambda GenAI 모듈 - GenAI ECS 서비스를 Lambda + Bedrock으로 대체
# Amazon Bedrock과 통합하여 AI 기능을 서버리스로 제공

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
    Service     = "lambda-genai"
    ManagedBy   = "terraform"
  })
}

# Lambda 기본 실행 정책 연결
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_execution_role.name
}

# VPC 접근을 위한 정책 연결 (필요시)
resource "aws_iam_role_policy_attachment" "lambda_vpc_execution" {
  count = var.enable_vpc_config ? 1 : 0

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
          "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.bedrock_model_id}",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/anthropic.claude-3-haiku-20240307-v1:0"
        ]
      }
    ]
  })
}

# CloudWatch Logs 그룹
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.name_prefix}-genai-function"
  retention_in_days = var.log_retention_days

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
      aws_region      = var.aws_region
    })
    filename = "lambda_function.py"
  }

  source {
    content  = file("${path.module}/requirements.txt")
    filename = "requirements.txt"
  }
}

# Lambda 함수
resource "aws_lambda_function" "genai_function" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.name_prefix}-genai-function"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = var.runtime
  timeout         = var.timeout
  memory_size     = var.memory_size

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = merge(var.environment_variables, {
      BEDROCK_MODEL_ID = var.bedrock_model_id
      AWS_REGION      = var.aws_region
      LOG_LEVEL       = var.log_level
    })
  }

  # VPC 설정 (선택사항)
  dynamic "vpc_config" {
    for_each = var.enable_vpc_config ? [1] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = var.security_group_ids
    }
  }

  # X-Ray 추적 설정
  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  # 데드 레터 큐 설정 (선택사항)
  dynamic "dead_letter_config" {
    for_each = var.dead_letter_queue_arn != null ? [1] : []
    content {
      target_arn = var.dead_letter_queue_arn
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

# Lambda 함수 별칭 (버전 관리용)
resource "aws_lambda_alias" "genai_function_alias" {
  name             = var.function_alias
  description      = "GenAI Lambda 함수 별칭"
  function_name    = aws_lambda_function.genai_function.function_name
  function_version = "$LATEST"

  lifecycle {
    ignore_changes = [function_version]
  }
}

# API Gateway에서 Lambda 호출을 위한 권한
resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.genai_function.function_name
  principal     = "apigateway.amazonaws.com"
  qualifier     = aws_lambda_alias.genai_function_alias.name

  # API Gateway ARN 패턴 (모든 스테이지, 모든 메서드 허용)
  source_arn = "${var.api_gateway_execution_arn}/*/*"
}

# CloudWatch 알람 - Lambda 에러율
resource "aws_cloudwatch_metric_alarm" "lambda_error_rate" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.name_prefix}-lambda-genai-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.error_threshold
  alarm_description   = "Lambda GenAI 함수 에러율이 임계값을 초과했습니다"
  alarm_actions       = var.alarm_actions

  dimensions = {
    FunctionName = aws_lambda_function.genai_function.function_name
  }

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-lambda-genai-error-alarm"
    Environment = var.environment
    Type        = "monitoring"
  })
}

# CloudWatch 알람 - Lambda 실행 시간
resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.name_prefix}-lambda-genai-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = var.duration_threshold
  alarm_description   = "Lambda GenAI 함수 실행 시간이 임계값을 초과했습니다"
  alarm_actions       = var.alarm_actions

  dimensions = {
    FunctionName = aws_lambda_function.genai_function.function_name
  }

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-lambda-genai-duration-alarm"
    Environment = var.environment
    Type        = "monitoring"
  })
}

# CloudWatch 알람 - Lambda 동시 실행 수
resource "aws_cloudwatch_metric_alarm" "lambda_concurrent_executions" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.name_prefix}-lambda-genai-concurrent-executions"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ConcurrentExecutions"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Maximum"
  threshold           = var.concurrent_executions_threshold
  alarm_description   = "Lambda GenAI 함수 동시 실행 수가 임계값을 초과했습니다"
  alarm_actions       = var.alarm_actions

  dimensions = {
    FunctionName = aws_lambda_function.genai_function.function_name
  }

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-lambda-genai-concurrent-alarm"
    Environment = var.environment
    Type        = "monitoring"
  })
}

# Provisioned Concurrency 설정 (Cold Start 최소화용, 선택사항)
resource "aws_lambda_provisioned_concurrency_config" "genai_function_concurrency" {
  count = var.provisioned_concurrency_count > 0 ? 1 : 0

  function_name                     = aws_lambda_function.genai_function.function_name
  provisioned_concurrent_executions = var.provisioned_concurrency_count
  qualifier                        = aws_lambda_alias.genai_function_alias.name

  lifecycle {
    ignore_changes = [provisioned_concurrent_executions]
  }
}