# Release Checklist

Backend:

- Backend deployed to production.
- `/actuator/health` is healthy.
- Swagger/OpenAPI available or intentionally restricted with team access.
- Postman smoke suite passes.
- Database migrations applied.
- Backups enabled and restore process tested.
- SSL certificate active.
- CI/CD pipeline green.

Flutter:

- Production API base URL configured.
- Firebase production apps configured.
- Push notification permissions tested on Android and iOS.
- Deep links tested from terminated, background, and foreground states.
- Force update and maintenance screens tested.
- Generated API client matches production OpenAPI.

Operations:

- Grafana dashboards available.
- RabbitMQ management available.
- MinIO console available.
- PostgreSQL monitoring available.
- Error logs include correlation IDs.
- On-call support playbook reviewed.

Product:

- Campaign management and targeting rules verified.
- Wallet and rewards verified.
- Withdrawals verified.
- Notifications verified.
- Profile and KYC verified.
- Advertiser analytics dashboard & CSV export verified.
