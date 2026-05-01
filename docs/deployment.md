# Deployment

End-to-end deployment from a clean machine to a working public API URL.

## 0. Prerequisites
- A GCP account with billing enabled.
- `gcloud` CLI authenticated locally (`gcloud auth login`).
- `gh` CLI authenticated (`gh auth login`).
- Terraform ≥ 1.7.

## 1. Bootstrap (one-time, manual — these steps cannot be in Terraform itself)

```bash
# Create GCP project & link billing
gcloud projects create swe455-expense-tracker --name="Expense Tracker"
gcloud config set project swe455-expense-tracker
gcloud beta billing projects link swe455-expense-tracker --billing-account=<BILLING_ACCOUNT_ID>

# Create the GCS bucket that holds Terraform state
gsutil mb -l us-central1 gs://swe455-expense-tracker-tfstate
gsutil versioning set on gs://swe455-expense-tracker-tfstate

# Push the three repos to GitHub
gh repo create <owner>/expense-tracker-infra            --public --source ./expense-tracker-infra            --push
gh repo create <owner>/expense-tracker-user-manager     --public --source ./expense-tracker-user-manager     --push
gh repo create <owner>/expense-tracker-expense-service  --public --source ./expense-tracker-expense-service  --push
```

## 2. First Terraform apply (runs locally)

```bash
cd expense-tracker-infra/terraform
gcloud auth application-default login

terraform init \
  -backend-config="bucket=swe455-expense-tracker-tfstate" \
  -backend-config="prefix=expense-tracker"

cp terraform.tfvars.example terraform.tfvars   # edit project_id, github_owner

terraform apply
```

Capture these outputs — you'll set them as repo variables next:
- `gateway_url`
- `deployer_sa_email`
- `wif_provider`
- `cloud_sql_connection`

> The Cloud Run services come up referencing placeholder `:bootstrap` images and
> will fail health checks until the service repos push real images. That is
> expected — the next step pushes them.

## 3. Wire GitHub Actions variables (one-time, per repo)

```bash
# In each repo directory:
gh variable set GCP_PROJECT_ID    --body "swe455-expense-tracker"
gh variable set GCP_REGION        --body "us-central1"
gh variable set WIF_PROVIDER      --body "<wif_provider output>"
gh variable set DEPLOYER_SA_EMAIL --body "<deployer_sa_email output>"

# Infra repo only (one extra each):
gh variable set TF_STATE_BUCKET   --body "swe455-expense-tracker-tfstate"
gh variable set GITHUB_OWNER      --body "<owner>"
```

## 4. First service deploys

```bash
# In each service repo
git commit --allow-empty -m "Trigger first deploy"
git push
```

Watch the workflow in GitHub Actions. On success:
- An image tagged with the commit SHA appears in Artifact Registry.
- A new Cloud Run revision serves traffic.

## 5. Run migrations (one-time after first successful deploy)

The simplest path is to deploy & execute a Cloud Run Job from a workstation:

```bash
PROJECT=swe455-expense-tracker
REGION=us-central1
CONN=$(cd terraform && terraform output -raw cloud_sql_connection)
RUNTIME_SA="sa-user-manager@${PROJECT}.iam.gserviceaccount.com"
IMAGE_UM=$(gcloud run services describe user-manager --region $REGION --format='value(spec.template.spec.containers[0].image)')

gcloud run jobs deploy migrate-user-manager \
  --image "$IMAGE_UM" \
  --command node --args src/db/migrate.js \
  --region $REGION \
  --service-account $RUNTIME_SA \
  --set-secrets DB_PASSWORD=DB_PASSWORD:latest \
  --set-env-vars "DB_NAME=expense_tracker,DB_USER=app,CLOUD_SQL_INSTANCE_CONNECTION_NAME=${CONN}"

gcloud run jobs execute migrate-user-manager --region $REGION --wait

# Repeat for expense-service (image, SA name, job name).
```

Migrations are idempotent — `schema_migrations` records applied versions.

## 6. Smoke test

```bash
GW=$(cd terraform && terraform output -raw gateway_url)
curl -s $GW/signup -X POST -H 'content-type: application/json' \
  -d '{"full_name":"Demo","email":"demo@x.com","password":"Demo-Passw0rd!"}'
```

## 7. Subsequent deploys

Fully automatic:
- Push to `main` of a service repo → that service redeploys.
- Push to `main` of the infra repo (under `terraform/**`) → Terraform re-applies.
