# Expense Tracker · Infrastructure

Terraform, API Gateway OpenAPI spec, local docker-compose, and project docs for
the Cloud-Based Expense Tracker (SWE 455 Cloud Applications course project).

## Repos in this system
- `expense-tracker-infra`              — this repo
- `expense-tracker-user-manager`       — auth & users
- `expense-tracker-expense-service`    — expenses CRUD

## Provisioning

```bash
cd terraform
terraform init \
  -backend-config="bucket=<state-bucket>" \
  -backend-config="prefix=expense-tracker"

cp terraform.tfvars.example terraform.tfvars   # fill in project_id, github_owner
terraform apply
```

Outputs include the public **API Gateway URL** and the GitHub Actions
`WIF_PROVIDER` / `DEPLOYER_SA_EMAIL` you need to set as repo variables in the
two service repos.

## Local development (all 3 repos cloned as siblings)

```bash
docker compose up -d postgres
docker compose run --rm user-manager   npm run migrate
docker compose run --rm expense-service npm run migrate
docker compose up -d
# user-manager     → http://localhost:8081
# expense-service  → http://localhost:8082
```

## Deploy lifecycle
1. Bootstrap GCP project + GCS state bucket (manual, one-off — see `docs/deployment.md`).
2. `terraform apply` from this repo (or via `terraform.yml` workflow on `main`).
3. Push each service repo to deploy its image — *or* run `scripts\deploy-images.ps1` locally to skip GitHub.

## Helper scripts (PowerShell)

If you hit "running scripts is disabled" on first run, either run with `-File`
(no policy needed):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy-images.ps1
```

…or relax the policy once for your user:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

- `scripts\deploy-images.ps1 [user-manager|expense-service]` — build, push, and deploy one or both
  service images to Cloud Run, replacing the placeholder image. Reads project/region from
  `terraform output`. Default (no arg) deploys both.
- `scripts\set-github-vars.ps1` — read `wif_provider`, `deployer_sa_email`, `project_id`, `region`
  from `terraform output` and set them as GitHub Actions `vars` on each service repo
  (`GCP_PROJECT_ID`, `GCP_REGION`, `WIF_PROVIDER`, `DEPLOYER_SA_EMAIL`). Re-run after every fresh
  apply because the WIF suffix rotates.
- `scripts\destroy-keep-db.ps1` — partial teardown of Cloud Run + API Gateway only. Cloud SQL,
  WIF, secrets, IAM, Artifact Registry, and the `random_id` suffix all stay. Re-apply takes
  ~5 min instead of ~20 min and GitHub vars don't need re-syncing. Use plain `terraform destroy`
  for a full teardown.

## Tear down

```bash
cd terraform && terraform destroy
```

See `docs/teardown.md` for the full procedure (including state-bucket cleanup).

## Documentation
- `docs/15-factor.md`         — factor-by-factor mapping
- `docs/api.md`               — consolidated API reference
- `docs/deployment.md`        — step-by-step deploy guide
- `docs/teardown.md`          — destroy & restore
- `docs/technical-report.md`  — submitted report
