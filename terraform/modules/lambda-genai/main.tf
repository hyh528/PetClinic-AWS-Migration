# Lambda GenAI 모듈

resource "aws_lambda_function" "genai_function" {
  function_name = "${var.name_prefix}-genai-function"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 60
  memory_size   = 512

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      BEDROCK_MODEL_ID = var.bedrock_model_id
      DB_HOST          = var.db_host
      DB_USER          = var.db_user
      DB_NAME          = var.db_name
      DB_PORT          = var.db_port
      DB_SECRET_ARN    = var.db_secret_arn
    }
  }

  tags = var.tags
}

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

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_execution_role.name
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  role       = aws_iam_role.lambda_execution_role.name
}

resource "aws_security_group" "lambda_sg" {
  name        = "${var.name_prefix}-lambda-genai-sg"
  description = "Lambda GenAI function security group"
  vpc_id      = var.vpc_id

  tags = var.tags
}

resource "aws_security_group_rule" "lambda_https_outbound" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.lambda_sg.id
}

resource "aws_security_group_rule" "lambda_mysql_outbound" {
  type              = "egress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  cidr_blocks       = ["10.0.0.0/16"]
  security_group_id = aws_security_group.lambda_sg.id
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"

  source {
    content  = "def handler(event, context): return {'statusCode': 200, 'body': 'Hello World'}"
    filename = "index.py"
  }
}