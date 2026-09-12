# Payment And Withdrawal Flow Guide

Withdrawal lifecycle:

```text
Request
  -> Pending
  -> Approved
  -> Paid
```

Rejected path:

```text
Request
  -> Pending
  -> Rejected
```

Flutter APIs:

| Step | API |
| --- | --- |
| List payment methods | `GET /api/v1/mobile/payment-methods` |
| Add payment method | `POST /api/v1/mobile/payment-methods` |
| Delete payment method | `DELETE /api/v1/mobile/payment-methods/{id}` |
| Request withdrawal | `POST /api/v1/mobile/withdrawals` |
| View withdrawal history | `GET /api/v1/mobile/withdrawals` |
| Refresh wallet | `GET /api/v1/mobile/wallet/overview` |

Client handling:

- Require online state for withdrawal submission.
- Disable submit after tap and send an `Idempotency-Key`.
- On `KYC_REQUIRED`, route to KYC.
- On `INSUFFICIENT_BALANCE`, refresh wallet and show balance error.
- On `WITHDRAWAL_LIMIT_EXCEEDED`, show limit guidance.
- Treat `PENDING` as normal after submission; payment is an operations workflow.
