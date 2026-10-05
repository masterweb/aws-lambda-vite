terraform {
  required_version = ">= 1.6"
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

variable "project_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "aws_profile" {
  type = string
}

# Borra cualquier log group huérfano de un test previo. Lambda crea logs
# asíncronamente tras ser destruida, lo que puede dejar el log group fuera
# del state. Esto garantiza un punto de partida limpio.
resource "null_resource" "delete_orphan_log_groups" {
  triggers = {
    project = var.project_name
  }

  provisioner "local-exec" {
    environment = {
      AWS_PROFILE = var.aws_profile
      AWS_REGION  = var.aws_region
    }
    command = <<-EOT
      aws logs delete-log-group --log-group-name "/${var.project_name}/lambda/${var.project_name}-api" --region "${var.aws_region}" 2>/dev/null || true
      aws logs delete-log-group --log-group-name "/aws/lambda/${var.project_name}-api" --region "${var.aws_region}" 2>/dev/null || true
    EOT
  }
}

output "done" {
  value      = true
  depends_on = [null_resource.delete_orphan_log_groups]
}
