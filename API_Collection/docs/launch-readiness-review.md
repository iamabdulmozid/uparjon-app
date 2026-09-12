# Launch Readiness Review

## Technical

- [x] Backend APIs complete.
- [x] Swagger/OpenAPI configured.
- [x] Postman collection available.
- [x] Postman environment files available.
- [x] CI/CD workflow present.
- [x] Monitoring configuration present.
- [x] Backup scripts present.
- [x] Final production hostnames replaced for `avytor.com`.
- [ ] Production secrets rotated from local defaults.

## Product

- [x] Campaign management.
- [x] Campaign targeting rules & estimation.
- [x] Wallet.
- [x] Rewards.
- [x] Withdrawals.
- [x] Notifications.
- [x] Profile.
- [x] KYC.
- [x] Advertiser Analytics dashboard.

## Mobile

- [x] Authentication contract documented.
- [x] Feed APIs documented.
- [x] Wallet APIs documented.
- [x] Notification APIs documented.
- [x] Profile APIs documented.
- [x] Screen-to-API mapping documented.
- [x] Offline strategy documented.
- [x] Push and deep link strategy documented.

## Release Gate

Before production launch, run:

```bash
newman run postman/RewardPlatform.smoke.postman_collection.json -e postman/Production.postman_environment.json
```

Launch is approved only after backend, Flutter, QA, and operations owners sign off on this checklist.
