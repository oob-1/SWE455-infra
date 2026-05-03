# Unique 4-byte (8 hex chars) suffix shared by resources whose GCP-side
# names enter a soft-deleted reservation period after destroy:
#   - Cloud SQL instance names: ~7 days
#   - Workload Identity Pool/Provider IDs: 30 days
# Without a unique suffix, `terraform destroy` followed by `terraform apply`
# within that window fails with 409 "already exists".
# This suffix is generated once per state — stable across plain `apply`
# runs, fresh on a re-apply that follows `destroy` (because state is wiped
# along with everything else).
resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  apis = [
    "run.googleapis.com",
    "sqladmin.googleapis.com",
    "secretmanager.googleapis.com",
    "artifactregistry.googleapis.com",
    "apigateway.googleapis.com",
    "servicecontrol.googleapis.com",
    "servicemanagement.googleapis.com",
    "iamcredentials.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
  ]
}

resource "google_project_service" "enabled" {
  for_each           = toset(local.apis)
  service            = each.value
  disable_on_destroy = false
}

# --- Artifact Registry (one repo for both services' images) ---
resource "google_artifact_registry_repository" "images" {
  location      = var.region
  repository_id = "expense-tracker"
  format        = "DOCKER"
  depends_on    = [google_project_service.enabled]
}

# --- Cloud SQL ---
resource "random_password" "db" {
  length  = 24
  special = false
}

resource "google_sql_database_instance" "pg" {
  name             = "expense-tracker-pg-${random_id.suffix.hex}"
  database_version = "POSTGRES_16"
  region           = var.region

  settings {
    tier              = var.db_tier
    availability_type = "ZONAL"

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
    }

    ip_configuration {
      ipv4_enabled = true
    }
  }

  deletion_protection = false
  depends_on          = [google_project_service.enabled]
}

resource "google_sql_database" "appdb" {
  name     = var.db_name
  instance = google_sql_database_instance.pg.name
}

resource "google_sql_user" "app" {
  name     = var.db_user
  instance = google_sql_database_instance.pg.name
  password = random_password.db.result
}

# --- Secret Manager ---
resource "google_secret_manager_secret" "db_password" {
  secret_id = "DB_PASSWORD"
  replication {
    auto {}
  }
  depends_on = [google_project_service.enabled]
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db.result
}

resource "random_password" "jwt" {
  length  = 48
  special = true
}

resource "google_secret_manager_secret" "jwt_secret" {
  secret_id = "JWT_SECRET"
  replication {
    auto {}
  }
  depends_on = [google_project_service.enabled]
}

resource "google_secret_manager_secret_version" "jwt_secret" {
  secret      = google_secret_manager_secret.jwt_secret.id
  secret_data = random_password.jwt.result
}
