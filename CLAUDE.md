# Desplegar usando terraform

## Stack
- Región AWS: `eu-west-1` (ajustable vía variable).
- Backend de estado: local (`terraform.tfstate` en `terraform/`).
- Carpeta: `terraform/` con un fichero por recurso (`lambda.tf`, `dynamodb.tf`, `apigw.tf`, `iam.tf`, `outputs.tf`, `variables.tf`, `providers.tf`).

## Recursos
1. **Lambda pública**
   - Runtime: Python 3.12, handler `handler.lambda_handler`.
   - Código empaquetado desde `lambda/` con `archive_file` (zip generado por Terraform).
   - Variables de entorno: `TABLE_NAME`, `AWS_REGION`.
   - Expuesta a Internet mediante **API Gateway v2 (HTTP API)** con CORS abierto (`*`, métodos `GET/POST/PUT/DELETE/OPTIONS`). No se usa Function URL (bloqueado por "Block Public Access" de 2024).
   - Rutas: `GET /tasks`, `POST /tasks`, `GET /tasks/{id}`, `PUT /tasks/{id}`, `DELETE /tasks/{id}`.

2. **DynamoDB**
   - Tabla: `todo-tasks`.
   - Billing: `PAY_PER_REQUEST`.
   - Partition key: `id` (String, UUID v4 generado por la Lambda).
   - Sin GSIs ni streams.

3. **Modelo de tarea**
   ```json
   {
     "id": "uuid-v4",
     "title": "string",
     "completed": false,
     "createdAt": "ISO-8601",
     "updatedAt": "ISO-8601"
   }
   ```

4. **IAM de mínimo privilegio**
   - Rol de ejecución de la Lambda con `AWSLambdaBasicExecutionRole` para CloudWatch Logs.
   - Policy inline con `dynamodb:PutItem`, `GetItem`, `UpdateItem`, `DeleteItem`, `Scan` **solo** sobre el ARN de `todo-tasks`.

5. **Outputs**
   - `api_url`: URL pública del stage de API Gateway (consumida por el frontend).
   - `table_name`, `lambda_name` para debug.

# Testing
1. `cd terraform && terraform init && terraform apply -auto-approve`.
2. Capturar `terraform output -raw api_url`.
3. Smoke test con `curl` sobre los 5 endpoints:
   - `POST {api_url}/tasks` con `{"title":"demo"}` → 201 + tarea con `id`.
   - `GET {api_url}/tasks` → 200 + array con la tarea creada.
   - `GET {api_url}/tasks/{id}` → 200.
   - `PUT {api_url}/tasks/{id}` con `{"completed":true}` → 200.
   - `DELETE {api_url}/tasks/{id}` → 204.
4. Verificar en CloudWatch Logs que no hay excepciones.
5. Limpieza: `terraform destroy -auto-approve`.

# Hacer una web en vite para acceder al api de la lambda
1. **Scaffold** en `frontend/` con Vite + React + TypeScript. Diseño profesional usando el agent `frontend-design`, con **dark mode** por defecto y toggle claro/oscuro persistido en `localStorage`.
2. **UI**: lista de tareas con operaciones CRUD completas:
   - Input + botón para crear tarea.
   - Checkbox por tarea para marcar `completed` (PUT).
   - Edición inline del título (PUT).
   - Botón de borrar (DELETE).
   - Estados vacío / cargando / error visibles.
3. **Config**: la URL del API se lee de `VITE_API_URL` (fichero `.env`). Nada hardcodeado. Añadir `.env.example`.
4. **Deploy**:
   - Repo en GitHub (monorepo con `terraform/`, `lambda/`, `frontend/`).
   - Importar el repo en Vercel apuntando a `frontend/`.
   - Configurar `VITE_API_URL` en las env vars de Vercel con la URL del output de Terraform.
   - Build command: `npm run build`, output: `dist`.
