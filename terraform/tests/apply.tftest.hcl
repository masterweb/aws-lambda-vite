variables {
  project_name = "todo-test"
  table_name   = "todo-tasks-test"
}

# Limpia log groups huérfanos de ejecuciones previas antes de desplegar.
# Lambda escribe logs de forma asíncrona, por lo que puede recrear su log
# group después de que terraform lo destruya en el teardown anterior.
run "pre_cleanup" {
  command = apply

  module {
    source = "./tests/cleanup"
  }

  variables {
    project_name = "todo-test"
    aws_region   = "eu-west-1"
    aws_profile  = "jorge-2026"
  }
}

run "deploy_infra" {
  command = apply

  assert {
    condition     = aws_dynamodb_table.tasks.name == "todo-tasks-test"
    error_message = "La tabla de test debería llamarse todo-tasks-test"
  }

  assert {
    condition     = length(aws_apigatewayv2_stage.default.invoke_url) > 0
    error_message = "El stage de API Gateway debe exponer una invoke_url"
  }
}

run "smoke_crud" {
  command = apply

  module {
    source = "./tests/smoke"
  }

  variables {
    api_url = run.deploy_infra.api_url
  }

  assert {
    condition     = output.create_status == 201
    error_message = "POST /tasks debería devolver 201"
  }

  assert {
    condition     = length(output.created_id) > 0
    error_message = "POST /tasks debería devolver una tarea con id"
  }

  assert {
    condition     = output.get_status == 200
    error_message = "GET /tasks/{id} debería devolver 200"
  }

  # Nota: no asertamos GET /tasks (lista): DynamoDB Scan tiene consistencia
  # eventual y la primera llamada tras crear puede responder sin la tarea.

  assert {
    condition     = length(output.put_delete_ran) > 0
    error_message = "El PUT y DELETE deberían completarse (status 200 y 204)"
  }
}
