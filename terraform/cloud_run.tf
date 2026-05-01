locals {
  ar_host      = "${var.region}-docker.pkg.dev"
  image_tag_um = "${local.ar_host}/${var.project_id}/${google_artifact_registry_repository.images.repository_id}/user-manager:bootstrap"
  image_tag_es = "${local.ar_host}/${var.project_id}/${google_artifact_registry_repository.images.repository_id}/expense-service:bootstrap"
}

resource "google_cloud_run_v2_service" "user_manager" {
  name     = "user-manager"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL" # protected by API Gateway invoker IAM

  template {
    service_account = google_service_account.user_manager.email
    scaling {
      min_instance_count = 0
      max_instance_count = 5
    }

    containers {
      image = local.image_tag_um
      ports { container_port = 8080 }

      env {
        name  = "DB_NAME"
        value = var.db_name
      }
      env {
        name  = "DB_USER"
        value = var.db_user
      }
      env {
        name  = "CLOUD_SQL_INSTANCE_CONNECTION_NAME"
        value = google_sql_database_instance.pg.connection_name
      }
      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_password.secret_id
            version = "latest"
          }
        }
      }
      env {
        name = "JWT_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.jwt_secret.secret_id
            version = "latest"
          }
        }
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [google_sql_database_instance.pg.connection_name]
      }
    }
  }

  lifecycle {
    ignore_changes = [template[0].containers[0].image] # CI updates the image
  }

  depends_on = [google_project_service.enabled]
}

resource "google_cloud_run_v2_service" "expense_service" {
  name     = "expense-service"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.expense_service.email
    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }

    containers {
      image = local.image_tag_es
      ports { container_port = 8080 }

      env {
        name  = "DB_NAME"
        value = var.db_name
      }
      env {
        name  = "DB_USER"
        value = var.db_user
      }
      env {
        name  = "CLOUD_SQL_INSTANCE_CONNECTION_NAME"
        value = google_sql_database_instance.pg.connection_name
      }
      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_password.secret_id
            version = "latest"
          }
        }
      }
      env {
        name = "JWT_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.jwt_secret.secret_id
            version = "latest"
          }
        }
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [google_sql_database_instance.pg.connection_name]
      }
    }
  }

  lifecycle {
    ignore_changes = [template[0].containers[0].image]
  }

  depends_on = [google_project_service.enabled]
}
