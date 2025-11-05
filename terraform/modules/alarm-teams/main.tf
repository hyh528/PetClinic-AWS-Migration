resource "aws_lambda_function" "teams_notifier" {
  function_name    = "teams-alarm-notifier"
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  role             = aws_iam_role.lambda_exec_role.arn
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      TEAMS_WEBHOOK_URL = var.teams_webhook_url
    }
  }
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "teams-alarm-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "sns_publish_policy" {
  name        = "teams-alarm-sns-publish-policy"
  description = "Allows Lambda to publish to SNS topic"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "sns:Publish",
        ],
        Effect   = "Allow",
        Resource = var.sns_topic_arn,
      },
    ],
  })
}

resource "aws_iam_role_policy_attachment" "sns_publish_attachment" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.sns_publish_policy.arn
}

resource "aws_sns_topic_subscription" "lambda_subscription" {
  topic_arn = var.sns_topic_arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.teams_notifier.arn
}

resource "aws_lambda_permission" "with_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.teams_notifier.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = var.sns_topic_arn
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}
