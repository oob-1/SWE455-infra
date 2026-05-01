# Destroy & Restore

## Destroy everything Terraform created

```bash
cd terraform

# Optional safety: list what will go
terraform plan -destroy

# Tear it down
terraform destroy \
  -var "project_id=swe455-expense-tracker" \
  -var "github_owner=<owner>"
```

What gets removed:
- Both Cloud Run services and revisions.
- API Gateway (gateway, config, API).
- Cloud SQL instance and database (DB content is lost; backups are deleted with the instance unless previously exported).
- Artifact Registry repository and all stored images.
- Secret Manager secrets and versions.
- All service accounts and IAM bindings created by Terraform.
- Workload Identity Pool and provider.

What stays (created outside Terraform):
- The GCP project itself.
- The Terraform state GCS bucket.
- Cloud Logging buckets (default retention applies).

## Remove the residue (truly everything)

```bash
gsutil rm -r gs://swe455-expense-tracker-tfstate
gcloud projects delete swe455-expense-tracker
```

## Restore from scratch

```bash
cd terraform
terraform init \
  -backend-config="bucket=swe455-expense-tracker-tfstate" \
  -backend-config="prefix=expense-tracker"

terraform apply

# Trigger image rebuilds from each service repo:
gh workflow run build-and-deploy --repo <owner>/expense-tracker-user-manager
gh workflow run build-and-deploy --repo <owner>/expense-tracker-expense-service

# Re-run migrations (see docs/deployment.md §5)
```

A full destroy → apply → first-deploy cycle takes about 8–12 minutes. The system
is fully restored to a working state with no manual console clicks.

## Restore data

This project's `destroy` intentionally takes the database with it. For data
continuity, dump before destroy and restore after the next apply:

```bash
gcloud sql export sql expense-tracker-pg gs://my-backups/dump.sql \
  --database=expense_tracker

# ...later, after restore...
gcloud sql import sql expense-tracker-pg gs://my-backups/dump.sql \
  --database=expense_tracker
```
