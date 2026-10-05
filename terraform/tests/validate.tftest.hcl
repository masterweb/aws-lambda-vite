run "config_sanity" {
  command = plan

  assert {
    condition     = aws_dynamodb_table.tasks.billing_mode == "PAY_PER_REQUEST"
    error_message = "DynamoDB debe usar PAY_PER_REQUEST"
  }

  assert {
    condition     = aws_dynamodb_table.tasks.hash_key == "id"
    error_message = "La clave de partición de DynamoDB debe ser 'id'"
  }

  assert {
    condition     = aws_lambda_function.api.runtime == "python3.12"
    error_message = "Lambda debe correr en python3.12"
  }

  assert {
    condition     = aws_lambda_function.api.handler == "handler.lambda_handler"
    error_message = "Handler de Lambda incorrecto"
  }

  assert {
    condition     = length(aws_apigatewayv2_route.routes) == 5
    error_message = "Deben existir las 5 rutas CRUD"
  }

  assert {
    condition = alltrue([
      for key in [
        "GET /tasks",
        "POST /tasks",
        "GET /tasks/{id}",
        "PUT /tasks/{id}",
        "DELETE /tasks/{id}",
      ] : contains(keys(aws_apigatewayv2_route.routes), key)
    ])
    error_message = "Falta alguna ruta CRUD en API Gateway"
  }

  assert {
    condition     = aws_apigatewayv2_api.http.protocol_type == "HTTP"
    error_message = "API Gateway debe ser HTTP (v2)"
  }

  assert {
    condition     = contains(tolist(aws_apigatewayv2_api.http.cors_configuration[0].allow_origins), "*")
    error_message = "CORS debe permitir cualquier origen"
  }
}
