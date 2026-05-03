output "gateway_url" {
  value       = "https://${google_api_gateway_gateway.this.default_hostname}"
  description = "Public API Gateway URL — the only entry point for clients."
}

output "artifact_registry_url" {
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.images.repository_id}"
  description = "Push images here from CI."
}

output "user_manager_url" {
  value = google_cloud_run_v2_service.user_manager.uri
}

output "expense_service_url" {
  value = google_cloud_run_v2_service.expense_service.uri
}

output "deployer_sa_email" {
  value       = google_service_account.github_deployer.email
  description = "Set this as DEPLOYER_SA_EMAIL in each GitHub repo's Actions variables."
}

output "wif_provider" {
  value       = google_iam_workload_identity_pool_provider.github.name
  description = "Set this as WIF_PROVIDER in each GitHub repo's Actions variables."
}

output "cloud_sql_connection" {
  value       = google_sql_database_instance.pg.connection_name
  description = "PROJECT:REGION:INSTANCE — used by the Cloud SQL connector."
}

# Echoed inputs — handy for scripts that don't want to re-read terraform.tfvars.
output "project_id" {
  value = var.project_id
}

output "region" {
  value = var.region
}

output "github_owner" {
  value = var.github_owner
}

output "user_manager_repo" {
  value = var.user_manager_repo
}

output "expense_service_repo" {
  value = var.expense_service_repo
}

output "artifact_registry_repo" {
  value = google_artifact_registry_repository.images.repository_id
}
