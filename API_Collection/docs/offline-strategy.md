# Offline Strategy

Offline supported:

| Area | Strategy |
| --- | --- |
| App config | Cache latest successful `GET /api/v1/mobile/app-config`. |
| Static config | Cache `GET /api/v1/mobile/config/static`. |
| Profile | Cache `GET /api/v1/mobile/profile` and dashboard summary. |
| Wallet | Cache `GET /api/v1/mobile/wallet/overview`; mark as stale while offline. |
| Notifications | Cache latest page and unread count; reconcile after reconnect. |
| Feed | Cache last home feed for read-only display; refresh before reward actions. |

Offline queue candidates:

| Action | API | Requirement |
| --- | --- | --- |
| Notification read | `PATCH /api/v1/mobile/notifications/{id}/read` | Add `Idempotency-Key`. |
| Read all notifications | `PATCH /api/v1/mobile/notifications/read-all` | Add `Idempotency-Key`. |
| Analytics batch | `POST /api/v1/mobile/analytics/batch` | Batch and replay. |
| Connection quality | `POST /api/v1/mobile/connection-quality` | Batch and replay. |

Offline unsupported:

| Action | Reason |
| --- | --- |
| Login / refresh | Requires backend validation. |
| Campaign start / complete | Eligibility, fraud checks, and reward timing must be server-authoritative. |
| Quiz / survey submit | Server validates answers, fraud signals, and duplicate submissions. |
| Withdrawal request | Balance and KYC must be checked online. |
| KYC upload | Requires multipart upload and server validation. |

Sync after reconnect:

1. Call `GET /api/v1/mobile/sync?since=<lastSuccessfulSync>`.
2. Replay queued supported actions with idempotency keys.
3. Refresh changed screens.
4. Clear successful queue entries only after 2xx or accepted duplicate result.
