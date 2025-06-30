terraform {
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "= 1.65.0"
    }
  }
}

provider "ibm" {
  region = "us-east"
}

variable "project_name" {
  description = "Name of the Code Engine project"
  type        = string
}

resource "ibm_code_engine_project" "project" {
  name = var.project_name
}

variable "backend_image" {
  default = "icr.io/iotmaxapi/iotmaxapi:latest"
}

variable "frontend_image" {
  default = "icr.io/iotmax-frontend/iotmax-frontend:latest"
}

variable "ibm_api_key" {
  description = "IBM Cloud API Key"
  type        = string
  sensitive   = true
}

variable "registry_secret_name" {
  default = "icr-secret"
}

variable "backend_env_vars" {
  description = "Custom environment variables for backend"
  type        = map(string)
  default     = {}
}


resource "ibm_code_engine_secret" "registry_secret" {
  project_id = ibm_code_engine_project.project.project_id
  name       = var.registry_secret_name
  format     = "registry"
  data = {
    "username" = "iamapikey"
    "password" = var.ibm_api_key
    "server"   = "icr.io"
  }
}

resource "ibm_code_engine_app" "backend" {
  name            = "iotmax-backend"
  project_id      = ibm_code_engine_project.project.project_id
  image_reference = var.backend_image
  image_port      = 8000
  image_secret    = ibm_code_engine_secret.registry_secret.name


  timeouts {
    create = "10m"
  }
  dynamic "run_env_variables" {
    for_each = var.backend_env_vars
    content {
      type  = "literal"
      name  = run_env_variables.key
      value = run_env_variables.value
    }
  }
  scale_cpu_limit    = "1"
  scale_memory_limit = "2G"
  scale_min_instances = 0
  scale_max_instances = 1
}

resource "ibm_code_engine_app" "frontend" {
  name            = "iotmax-frontend"
  project_id      = ibm_code_engine_project.project.project_id
  image_reference = var.frontend_image
  image_secret    = ibm_code_engine_secret.registry_secret.name
  image_port      = 3000
  depends_on = [ ibm_code_engine_app.backend ]


  run_env_variables {
    type  = "literal"
    name  = "REACT_APP_BACKEND_URL"
    value = "${ibm_code_engine_app.backend.endpoint}/api"
  }
  timeouts {
    create = "10m"
  }
}

output "backend_url" {
  description = "Backend application URL"
  value       = ibm_code_engine_app.backend.endpoint
}

output "frontend_url" {
  description = "Frontend application URL"
  value       = ibm_code_engine_app.frontend.endpoint
}
