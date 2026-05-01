# Technical Report — Cloud-Based Expense Tracker Microservices System

**Course:** SWE 455 Cloud Applications
**Author:** _<your name>_

## Abstract

This project implements a cloud-native backend system — an Expense Tracker —
built as two Node.js + Express microservices fronted by a managed API Gateway,
persisted by a managed PostgreSQL instance, packaged as Docker containers,
deployed onto Google Cloud Run, provisioned end-to-end with Terraform, and
continuously delivered through GitHub Actions. The system is engineered
against the 15-Factor App methodology and demonstrates a complete, reproducible
cloud workflow from local development to public deployment.

## Objectives

1. Apply microservice principles by decomposing the application along bounded
   data ownership (`users`, `expenses`).
2. Demonstrate fully automated, declarative provisioning of cloud
   infrastructure (Terraform, no manual console steps).
3. Demonstrate continuous delivery from `git push` to a publicly reachable,
   versioned production deployment.
4. Apply each of the 15 factors and document the mapping concretely
   (`docs/15-factor.md`).

## Architecture

A client communicates only with a public **API Gateway**, which routes
requests to one of two stateless **Cloud Run** services. The **User Manager
Service** is the sole writer of the `users` table and is the only component
that mints JWTs. The **Expense Service** is the sole writer of the `expenses`
table and verifies — but never mints — JWTs. Both services share a single
**Cloud SQL** PostgreSQL instance and read short-lived secrets (DB password,
JWT signing key) from **Secret Manager** at boot. Service-to-service traffic
does not exist; identity is propagated by the JWT alone, eliminating a runtime
coupling.

```
            ┌──────────────┐
Client ───▶ │ API Gateway  │
            └──────┬───────┘
                   │
       ┌───────────┴────────────┐
       ▼                        ▼
┌────────────────┐      ┌────────────────┐
│ User Manager   │      │ Expense        │
│ (Cloud Run)    │      │ Service        │
└──────┬─────────┘      │ (Cloud Run)    │
       │                └──────┬─────────┘
       └──────────┬────────────┘
                  ▼
         ┌──────────────────┐
         │ Cloud SQL (PG)   │
         └──────────────────┘
```

## Repository Layout

Three independent Git repos (Factor I — Codebase):

- `expense-tracker-user-manager` — User Manager service.
- `expense-tracker-expense-service` — Expense Service.
- `expense-tracker-infra` — Terraform, OpenAPI gateway spec, docker-compose, docs.

## Security Model

- Passwords are hashed with **bcrypt** (cost 12). The plaintext is never
  logged or persisted.
- Sessions are stateless **JWTs** (HS256, 1 h TTL, `iss=user-manager`).
- Cloud Run services are **invoker-restricted** to the API Gateway's service
  account — they cannot be reached directly even though their ingress is
  public.
- Cloud SQL is reached over **TLS via the Cloud SQL connector**. No
  public-IP allowlist is needed and no DB credentials are committed.
- All deploys use **Workload Identity Federation** — GitHub Actions presents
  a short-lived OIDC token instead of a long-lived JSON key.
- Application-level authorization isolates user data with
  `WHERE user_id = $jwt.sub` on every query.

## Reliability & Operations

- **Health checks** — every service exposes `/health`; Cloud Run uses it for
  startup and liveness probing.
- **Graceful shutdown** — `SIGTERM` triggers connection drain and PG pool
  close within 10 s.
- **Backups & PITR** — enabled on Cloud SQL.
- **Logs & metrics** — JSON-on-stdout, ingested into Cloud Logging; Cloud
  Run-emitted RED metrics flow into Cloud Monitoring.
- **Rollback** — Cloud Run keeps prior revisions; rolling back is a single
  `gcloud run services update-traffic --to-revisions` call.

## Cost & Footprint

With no traffic the system idles at: Cloud Run scaled to zero (free),
Artifact Registry storage (~$0.10/GB·mo), Secret Manager (free tier), API
Gateway (free tier for low traffic), Cloud SQL `db-f1-micro` (the dominant
cost, roughly $7–10/mo). For a course demo, the total monthly cost is
single-digit USD; spinning the system down via `terraform destroy` between
assessments brings it to zero.

## Limitations & Future Work

- Single Cloud SQL instance, single region — no DR.
- HS256 JWT — adequate for one-issuer/one-audience but RS256 + JWKS would
  scale better.
- No request throttling beyond what API Gateway provides by default.
- Reporting, budgets, multi-currency, OCR are intentionally out of scope.

## Conclusion

Even a minimal CRUD domain, when delivered through this stack, exercises
every meaningful concern in modern cloud engineering: containerization, IaC,
OIDC-based CI/CD, managed databases, secret injection, structured
observability, and identity-aware routing. The 15-Factor methodology served
as a useful design constraint that pushed the implementation toward simpler,
more portable, and more operable code.
