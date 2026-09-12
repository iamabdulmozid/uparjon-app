# OpenAPI JSON

Canonical OpenAPI JSON is served by the running backend:

| Spec | Production | Local |
| --- | --- | --- |
| Full API | `https://api.avytor.com/v3/api-docs` | `http://localhost:8080/v3/api-docs` |
| Flutter mobile APIs | `https://api.avytor.com/v3/api-docs/02%20Mobile` | `http://localhost:8080/v3/api-docs/02%20Mobile` |
| Auth APIs | `https://api.avytor.com/v3/api-docs/01%20Auth` | `http://localhost:8080/v3/api-docs/01%20Auth` |

Download examples:

```bash
curl -o openapi.json https://api.avytor.com/v3/api-docs
curl -o openapi-mobile.json https://api.avytor.com/v3/api-docs/02%20Mobile
```

Use `openapi-mobile.json` for the lean Flutter client and the full `openapi.json` when the app also needs auth or shared endpoints not included in the mobile group.
