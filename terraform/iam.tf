# Per-service runtime identities (least privilege)
resource "google_service_account" "user_manager" {
  account_id   = "sa-user-manager"
  display_name = "Run: User Manager"
}

resource "google_service_account" "expense_service" {
  account_id   = "sa-expense-service"
  display_name = "Run: Expense Service"
}

resource "google_service_account" "api_gateway" {
  account_id   = "sa-api-gateway"
  display_name = "API Gateway invoker"
}

resource "google_service_account" "github_deployer" {
  account_id   = "sa-github-deployer"
  display_name = "GitHub Actions deployer"
}

locals {
  runtime_sas = [
    google_service_account.user_manager.email,
    google_service_account.expense_service.email,
  ]
  runtime_roles = [
    "roles/cloudsql.client",
    "roles/secretmanager.secretAccessor",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
  ]
}

resource "google_project_iam_member" "runtime_bindings" {
  for_each = {
    for pair in setproduct(local.runtime_sas, local.runtime_roles) :
    "${pair[0]}|${pair[1]}" => { sa = pair[0], role = pair[1] }
  }
  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${each.value.sa}"
}

# API Gateway SA can invoke both Cloud Run services
resource "google_cloud_run_v2_service_iam_member" "gw_invokes_um" {
  location = var.region
  name     = google_cloud_run_v2_service.user_manager.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.api_gateway.email}"
}

resource "google_cloud_run_v2_service_iam_member" "gw_invokes_es" {
  location = var.region
  name     = google_cloud_run_v2_service.expense_service.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.api_gateway.email}"
}

# --- Workload Identity Federation: GitHub OIDC ---
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-pool"
  display_name              = "GitHub Actions"
  depends_on                = [google_project_service.enabled]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  attribute_condition = "assertion.repository_owner == \"${var.github_owner}\""
}

# Allow each repo to impersonate the deployer SA
locals {
  allowed_repos = [
    "${var.github_owner}/${var.user_manager_repo}",
    "${var.github_owner}/${var.expense_service_repo}",
    "${var.github_owner}/${var.infra_repo}",
  ]
}

resource "google_service_account_iam_member" "github_impersonate" {
  for_each           = toset(local.allowed_repos)
  service_account_id = google_service_account.github_deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${each.value}"
}

# Deployer SA needs to push images, deploy Cloud Run, and run Terraform
resource "google_project_iam_member" "deployer_roles" {
  for_each = toset([
    "roles/artifactregistry.writer",
    "roles/run.admin",
    "roles/iam.serviceAccountUser",
    "roles/cloudsql.admin",
    "roles/secretmanager.admin",
    "roles/apigateway.admin",
    "roles/storage.admin",
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.github_deployer.email}"
}
