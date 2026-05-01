variable "project_id" {
  type        = string
  description = "GCP project ID."
  default     = "swe-455-cloud-applications"
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "GCP region for Cloud Run, Artifact Registry, Cloud SQL, API Gateway."
}

variable "github_owner" {
  type        = string
  description = "GitHub user/org that owns the three repos."
  default     = "oob-1"
}

variable "user_manager_repo" {
  type    = string
  default = "SWE455-user-manager"
}

variable "expense_service_repo" {
  type    = string
  default = "SWE455-expense-service"
}

variable "infra_repo" {
  type    = string
  default = "SWE455-infra"
}

variable "db_tier" {
  type    = string
  default = "db-f1-micro"
}

variable "db_user" {
  type    = string
  default = "app"
}

variable "db_name" {
  type    = string
  default = "expense_tracker"
}
