data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda"
  output_path = "${path.module}/.build/lambda.zip"
}

locals {
  lambda_name = "${var.project_name}-api"
}

# Log group con nombre custom (fuera del namespace /aws/lambda/<fn> que
# Lambda auto-crea). Así nunca lo recrea tras un destroy.
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/${var.project_name}/lambda/${local.lambda_name}"
  retention_in_days = 7
}

resource "aws_lambda_function" "api" {
  function_name = local.lambda_name
  role          = aws_iam_role.lambda_exec.arn
  runtime       = "python3.12"
  handler       = "handler.lambda_handler"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  timeout     = 10
  memory_size = 256

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.lambda.name
  }

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.tasks.name
    }
  }
}
