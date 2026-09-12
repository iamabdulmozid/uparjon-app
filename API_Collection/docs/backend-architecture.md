# Backend Architecture and Database Guide

This document covers the high-level architecture of the Spring Boot backend (`uparjonx-api`) and explains how the PostgreSQL database is managed.

## Technical Stack

- **Framework**: Spring Boot 3.x with Java 21
- **Database**: PostgreSQL 14+
- **Security**: Spring Security with stateless JWT Authentication
- **ORM**: Spring Data JPA / Hibernate
- **Migrations**: Flyway

## Package Structure

The backend application follows a domain-driven package structure under `src/main/java/com/uparjonx/platform/`:

```text
├── auth/            # Controllers, DTOs, and Services for Login, Registration, JWT
├── users/           # User entity, role management, and repositories
├── profile/         # User profile data, KYC logic, Password Reset Tokens
├── campaigns/       # Ad Campaign business logic
├── ads/             # Advertisements and Views tracking
├── wallet/          # User wallet balances, earnings, transactions
├── common/          # Global exception handlers, Base API response formats
└── shared/          # Base Entity classes, Seeder components, Utilities
```

## Security & Authentication

1. **JWT Flow**: The `/api/v1/auth/login` endpoint validates credentials and returns a short-lived Access Token and a long-lived Refresh Token.
2. **Stateless Sessions**: The API is completely stateless. Every protected request requires the Access Token in the `Authorization: Bearer <token>` header.
3. **Role-Based Access Control (RBAC)**: Controllers are annotated with `@PreAuthorize("hasRole('ADMIN')")` to restrict endpoints based on the `Role` entity tied to the authenticated user.

## Database Migrations (Flyway)

We use **Flyway** for database migrations to keep track of schema changes across different environments consistently.

- `application.yaml` specifies `spring.jpa.hibernate.ddl-auto: validate` which prevents Hibernate from destroying or altering tables on its own.
- When creating a new entity or modifying an existing one, you must write a corresponding SQL script.
- **Migration Location**: Place new scripts in `src/main/resources/db/migration/`.
- **Naming Convention**: `V<Version_Number>__<Description>.sql` (e.g., `V1__init_schema.sql` or `V2__add_otp_tokens.sql`). Note the double underscore `__`.

## Data Seeding

For local testing, the `DatabaseSeeder.java` component automatically injects required dummy data when the application starts if the database is empty:
- Base roles (`ROLE_ADMIN`, `ROLE_USER`)
- Staging users (`admin@test.com`, `user@test.com`, etc.)
- Basic wallets and an initial active advertising campaign.

This speeds up development and guarantees everyone works from the same structural foundation.
