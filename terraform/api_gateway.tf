resource "google_api_gateway_api" "this" {
  provider   = google-beta
  api_id     = "expense-tracker-api"
  depends_on = [google_project_service.enabled]
}

resource "google_api_gateway_api_config" "this" {
  provider      = google-beta
  api           = google_api_gateway_api.this.api_id
  api_config_id = "v2"

  openapi_documents {
    document {
      path = "openapi.yaml"
      contents = base64encode(templatefile("${path.module}/openapi.yaml", {
        user_manager_url    = google_cloud_run_v2_service.user_manager.uri
        expense_service_url = google_cloud_run_v2_service.expense_service.uri
        gateway_sa_email    = google_service_account.api_gateway.email
      }))
    }
  }

  gateway_config {
    backend_config {
      google_service_account = google_service_account.api_gateway.email
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_api_gateway_gateway" "this" {
  provider   = google-beta
  api_config = google_api_gateway_api_config.this.id
  gateway_id = "expense-tracker-gw"
  region     = var.region
}
