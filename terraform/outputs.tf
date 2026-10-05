output "api_url" {
  description = "Base URL of the HTTP API"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "table_name" {
  value = aws_dynamodb_table.tasks.name
}

output "lambda_name" {
  value = aws_lambda_function.api.function_name
}
