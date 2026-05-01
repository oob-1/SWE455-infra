# 15-Factor App Mapping

How each of the 15 factors is realized in this codebase.

| # | Factor | Implementation |
|---|---|---|
| 1 | **Codebase** | Three Git repos, one per deployable unit: `expense-tracker-user-manager`, `expense-tracker-expense-service`, `expense-tracker-infra`. Each service is "one codebase, many deploys" (dev via Compose, prod via Cloud Run). |
| 2 | **Dependencies** | Declared exhaustively in each service's `package.json` and locked in `package-lock.json`. The Dockerfile uses `npm ci` to guarantee deterministic installs; nothing is system-installed. |
| 3 | **Config** | All configuration is read from environment variables in `src/config.js`. There is no environment-specific code path. Values come from `.env` locally and from Cloud Run env vars (with secrets sourced from Secret Manager) in production. |
| 4 | **Backing services** | Cloud SQL is treated as an attached resource referenced solely by `DB_HOST` / `CLOUD_SQL_INSTANCE_CONNECTION_NAME`. Swapping local Postgres for Cloud SQL requires only env-var changes — no code changes. |
| 5 | **Build, release, run** | Build = `docker build` in CI. Release = image tagged with the commit SHA pushed to Artifact Registry plus its env-var/secret bindings. Run = `gcloud run deploy` produces an immutable revision. Releases are immutable and rollback-able by re-pointing traffic to a previous revision. |
| 6 | **Processes** | Both services are stateless Node processes; no in-memory session, no local file storage. Any instance can serve any request. |
| 7 | **Port binding** | Each service exports its HTTP server itself (`app.listen(PORT)`). No external app server (no Apache/NGINX wrapping the Node process). Cloud Run injects `PORT=8080`. |
| 8 | **Concurrency** | Horizontal scaling via Cloud Run: `min_instance_count = 0`, `max_instance_count` configurable per service. Concurrent requests are handled by Node's event loop within an instance and by adding instances across the fleet. |
| 9 | **Disposability** | Fast boot (<2 s, no warmup work in `index.js` beyond a single PG connectivity check). Graceful shutdown handler in `src/index.js` traps `SIGTERM`, stops accepting new requests, drains in-flight, closes the PG pool, and exits — with a 10 s hard ceiling. |
| 10 | **Dev/prod parity** | Identical Node version, identical Postgres major version, identical Docker image between dev (Compose) and prod (Cloud Run). Same code path, same migration scripts. |
| 11 | **Logs** | `pino` writes structured JSON to `stdout`. No file rotation, no log shipping in-app. Cloud Run captures stdout into Cloud Logging automatically; locally `docker compose logs -f` streams them. |
| 12 | **Admin processes** | DB migrations run via `npm run migrate` against the same image, executed as a Cloud Run **Job** (not the long-running service). Same image, same env, same code — just a different entry point. |
| 13 | **API first** | API Gateway is configured from a versioned `openapi.yaml` checked into `terraform/`. The contract precedes any client; the same spec doubles as documentation. |
| 14 | **Telemetry** | Structured request logs include `request_id`, `user_id`, route, status, and latency. Cloud Run emits RED metrics (request count, error rate, latency) into Cloud Monitoring with no extra code. |
| 15 | **Authentication & Authorization** | Authentication via bcrypt-hashed credentials, sessions via short-lived signed JWTs (HS256). Authorization at two layers: (a) IAM — only the API Gateway service account can invoke Cloud Run; (b) application — every Expense Service query is scoped by `WHERE user_id = $jwt.sub`, so users can never read or mutate another user's rows. |
