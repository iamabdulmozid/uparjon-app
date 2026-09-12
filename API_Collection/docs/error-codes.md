# API Error Codes

Flutter must branch on `errorCode`, not `message`. The human message may change for localization, support copy, or security hardening.

Standard error shape:

```json
{
  "success": false,
  "message": "Human-readable message",
  "errorCode": "INSUFFICIENT_BALANCE",
  "timestamp": "2026-05-30T10:00:00Z",
  "path": "/api/v1/mobile/withdrawals"
}
```

| Error Code | Typical HTTP Status | Flutter Handling |
| --- | --- | --- |
| `BAD_CREDENTIALS` | 401 | Show invalid login state; do not reveal whether email/mobile exists. |
| `INVALID_CREDENTIALS` | 401 | Alias-level handling for invalid login credentials. |
| `INVALID_TOKEN` | 401 | Try refresh once; if refresh fails, clear session and route to login. |
| `ACCESS_DENIED` | 403 | Show forbidden state or hide unavailable action. |
| `ACCOUNT_LOCKED` | 403 | Show locked account support path. |
| `ACCOUNT_DISABLED` | 403 | Show suspended/disabled account support path. |
| `ACCOUNT_SUSPENDED` | 403 | Treat as disabled account UX. |
| `USER_NOT_FOUND` | 404 | Show not-found state for profile/admin views. |
| `NOT_FOUND` | 404 | Show empty or removed-resource state. |
| `VALIDATION_ERROR` | 400 | Bind field errors to form controls when returned. |
| `BUSINESS_ERROR` | 400 | Show domain-specific failure state. |
| `CONCURRENCY_ERROR` | 409 | Refresh the screen and ask user to retry. |
| `DUPLICATE_REQUEST` | 409 | Treat as already submitted; refresh target resource. |
| `INSUFFICIENT_BALANCE` | 400 | Block withdrawal/payment and show wallet top-up/earning prompt. |
| `KYC_REQUIRED` | 403 | Route to KYC screen. |
| `CAMPAIGN_NOT_ELIGIBLE` | 403 | Remove/disable campaign card and refresh feed. |
| `WITHDRAWAL_LIMIT_EXCEEDED` | 400 | Show withdrawal limit guidance. |
| `INTERNAL_SERVER_ERROR` | 500 | Show retry state and log correlation ID. |

Required client rules:

- Refresh token only once per failed request chain.
- Do not retry validation, credential, KYC, eligibility, or balance errors automatically.
- Safe retry candidates are network failures, 408, 429 after backoff, and 5xx with idempotency.
