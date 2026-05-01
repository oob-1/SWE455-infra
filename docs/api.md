# API Documentation

Base URL: `https://{gateway_hostname}` — see `terraform output gateway_url`.
All bodies are JSON. All authenticated routes require `Authorization: Bearer <jwt>`.

## Status codes

| Code | Meaning |
|---|---|
| `200` | Success (GET, PATCH) |
| `201` | Resource created |
| `204` | Success, no body (DELETE) |
| `400` | Validation failure |
| `401` | Missing / invalid / expired JWT, or wrong credentials |
| `404` | Resource not found, or not visible to this user |
| `409` | Email already registered |
| `5xx` | Internal — see `request_id` in the response and search Cloud Logging |

## Error envelope (every 4xx/5xx)

```json
{ "error": { "code": "VALIDATION_ERROR", "message": "...", "request_id": "..." } }
```

## Auth flow

1. `POST /signup` → returns user record.
2. `POST /login` → returns JWT.
3. Send JWT in `Authorization` header on all subsequent calls.

## Endpoint catalogue

| Method | Path | Auth | Service | Description |
|---|---|---|---|---|
| POST   | `/signup`         | no  | user-manager    | Register a new user |
| POST   | `/login`          | no  | user-manager    | Exchange credentials for a JWT |
| GET    | `/users/profile`  | yes | user-manager    | Return the caller's profile |
| POST   | `/expenses`       | yes | expense-service | Create an expense for the caller |
| GET    | `/expenses`       | yes | expense-service | List the caller's expenses (filters: `from`, `to`, `category`, `limit`, `offset`) |
| GET    | `/expenses/{id}`  | yes | expense-service | Fetch one of the caller's expenses |
| PATCH  | `/expenses/{id}`  | yes | expense-service | Partial update of one expense |
| DELETE | `/expenses/{id}`  | yes | expense-service | Delete one of the caller's expenses |

## Request / response examples

### POST /signup
```json
{ "full_name": "Sara Al-Otaibi", "email": "sara@example.com", "password": "S3cure-Passw0rd!" }
```
→ `201`
```json
{ "id": 42, "full_name": "Sara Al-Otaibi", "email": "sara@example.com", "created_at": "2026-05-01T10:14:22Z" }
```

### POST /login
```json
{ "email": "sara@example.com", "password": "S3cure-Passw0rd!" }
```
→ `200`
```json
{ "token": "eyJhbGciOi...", "token_type": "Bearer", "expires_in": 3600 }
```

### POST /expenses
```json
{ "title": "Lunch", "amount": 64.50, "category": "food", "expense_date": "2026-04-30", "notes": "..." }
```
→ `201` with the created record (including `id`, `user_id`, `created_at`, `updated_at`).

### GET /expenses
→ `200`
```json
{ "items": [ /* ... */ ], "limit": 20, "offset": 0, "count": 1 }
```

## cURL quickstart

```bash
GW="https://<your-gateway-host>"

curl -sX POST $GW/signup -H 'content-type: application/json' \
  -d '{"full_name":"Sara","email":"sara@example.com","password":"S3cure-Passw0rd!"}'

TOKEN=$(curl -sX POST $GW/login -H 'content-type: application/json' \
  -d '{"email":"sara@example.com","password":"S3cure-Passw0rd!"}' | jq -r .token)

curl -sX POST $GW/expenses -H "authorization: Bearer $TOKEN" -H 'content-type: application/json' \
  -d '{"title":"Lunch","amount":64.50,"category":"food","expense_date":"2026-04-30"}'

curl -s $GW/expenses -H "authorization: Bearer $TOKEN"

curl -sX PATCH  $GW/expenses/1 -H "authorization: Bearer $TOKEN" -H 'content-type: application/json' \
  -d '{"amount":70.00}'

curl -sX DELETE $GW/expenses/1 -H "authorization: Bearer $TOKEN"
```
