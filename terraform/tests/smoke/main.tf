terraform {
  required_version = ">= 1.6"
  required_providers {
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

variable "api_url" {
  type = string
}

locals {
  base  = trimsuffix(var.api_url, "/")
  title = "tftest-${formatdate("YYYYMMDDhhmmss", timestamp())}"
}

data "http" "create" {
  url    = "${local.base}/tasks"
  method = "POST"
  request_headers = {
    "Content-Type" = "application/json"
  }
  request_body = jsonencode({ title = local.title })
}

locals {
  created    = jsondecode(data.http.create.response_body)
  created_id = try(local.created.id, "")
}

data "http" "get_one" {
  url = "${local.base}/tasks/${local.created_id}"
}

data "http" "list" {
  url        = "${local.base}/tasks"
  depends_on = [data.http.create]
}

resource "null_resource" "update_and_delete" {
  triggers = {
    id = local.created_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      TMP=$(mktemp)
      PUT=$(curl -s -o "$TMP" -w "%%{http_code}" -X PUT \
        -H "Content-Type: application/json" \
        -d '{"completed":true}' \
        "${local.base}/tasks/${local.created_id}")
      BODY=$(cat "$TMP") && rm -f "$TMP"
      if [ "$PUT" != "200" ]; then echo "PUT returned $PUT: $BODY" >&2; exit 1; fi
      echo "$BODY" | grep -q '"completed": true' || { echo "PUT body missing completed=true: $BODY" >&2; exit 1; }

      DEL=$(curl -s -o /dev/null -w "%%{http_code}" -X DELETE "${local.base}/tasks/${local.created_id}")
      if [ "$DEL" != "204" ]; then echo "DELETE returned $DEL" >&2; exit 1; fi
    EOT
  }
}

output "create_status" { value = data.http.create.status_code }
output "created_id"    { value = local.created_id }
output "get_status"    { value = data.http.get_one.status_code }
output "list_status"   { value = data.http.list.status_code }
output "list_has_task" {
  value = strcontains(data.http.list.response_body, local.created_id)
}
output "put_delete_ran" {
  value      = null_resource.update_and_delete.id
  depends_on = [null_resource.update_and_delete]
}
