# Monitoring Dashboard Access

Operations links for production should be filled with the final infrastructure hostnames.

| Tool | Production URL | Purpose |
| --- | --- | --- |
| Grafana | `https://grafana.avytor.com` | API, JVM, DB, queue, and business metrics dashboards. |
| RabbitMQ | `https://rabbitmq.avytor.com` | Queue depth, consumers, dead-letter checks. |
| MinIO | `https://minio.avytor.com` | Uploaded files and object storage health. |
| PostgreSQL | `https://postgres.avytor.com` | Database monitoring/admin access. |
| API Health | `https://api.avytor.com/actuator/health` | Runtime health and readiness. |

Minimum dashboard checks:

- API error rate.
- API latency by endpoint.
- JVM memory and GC.
- Database connections and slow queries.
- RabbitMQ queue depth and dead-letter count.
- Storage errors.
- Login failures and withdrawal failure rates.
