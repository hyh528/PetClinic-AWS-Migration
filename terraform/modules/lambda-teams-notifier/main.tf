#
# resource "aws_lambda_function" "teams_notifier" {
#   function_name = "${var.project_name}-${var.environment}-teams-notifier"
#   handler       = "index.handler"
#   runtime       = "python3.9"
#   role          = var.lambda_iam_role_arn
#
#   filename         = data.archive_file.lambda_zip.output_path
#   source_code_hash = data.archive_file.lambda_zip.output_base64sha256
#
#   environment {
#     variables = {
#       TEAMS_WEBHOOK_URL = var.teams_webhook_url
#     }
#   }
#
#   tags = var.tags
# }
#
# data "archive_file" "lambda_zip" {
#   type        = "zip"
#   source_file = "${path.module}/index.py"
#   output_path = "${path.module}/lambda.zip"
# }
