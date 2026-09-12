# Swagger And API Artifact URLs

Use these URLs for Flutter development, QA, and UAT.

| Artifact | Production URL | Local URL |
| --- | --- | --- |
| API base URL | `https://api.avytor.com` | `http://localhost:8080` |
| Swagger UI | `https://api.avytor.com/swagger-ui.html` | `http://localhost:8080/swagger-ui.html` |
| Full OpenAPI JSON | `https://api.avytor.com/v3/api-docs` | `http://localhost:8080/v3/api-docs` |
| Auth OpenAPI JSON | `https://api.avytor.com/v3/api-docs/01%20Auth` | `http://localhost:8080/v3/api-docs/01%20Auth` |
| Mobile OpenAPI JSON | `https://api.avytor.com/v3/api-docs/02%20Mobile` | `http://localhost:8080/v3/api-docs/02%20Mobile` |
| Profile OpenAPI JSON | `https://api.avytor.com/v3/api-docs/03%20Mobile%20Profile%20APIs` | `http://localhost:8080/v3/api-docs/03%20Mobile%20Profile%20APIs` |
| Notifications OpenAPI JSON | `https://api.avytor.com/v3/api-docs/08%20Mobile%20Notification%20APIs` | `http://localhost:8080/v3/api-docs/08%20Mobile%20Notification%20APIs` |
| Optimization OpenAPI JSON | `https://api.avytor.com/v3/api-docs/09%20Mobile%20Optimization%20APIs` | `http://localhost:8080/v3/api-docs/09%20Mobile%20Optimization%20APIs` |
| Admin OpenAPI JSON | `https://api.avytor.com/v3/api-docs/10%20Admin` | `http://localhost:8080/v3/api-docs/10%20Admin` |

Postman package:

- Collection: `postman/RewardPlatform.postman_collection.json`
- Smoke collection: `postman/RewardPlatform.smoke.postman_collection.json`
- Environments: `postman/Local.postman_environment.json`, `postman/Production.postman_environment.json`

Swagger authorization:

1. Log in with `POST /api/v1/auth/login`.
2. Copy `data.accessToken`.
3. Click `Authorize`.
4. Enter either the raw token or `Bearer <token>`.
