# Local Development Setup Guide

This document outlines the steps required to get the entire Platform Go application running locally on your development machine.

## Prerequisites

Ensure you have the following installed on your system:
- **Java 21** (JDK 21)
- **Node.js** (v18 or higher)
- **PostgreSQL** (v14 or higher)
- **Maven** (optional, as the Maven wrapper `mvnw` is included in the project)

## 1. Database Setup

The backend requires a local PostgreSQL database instance.

1. Start your local PostgreSQL server.
2. Create a new database named `uparjonx_db`:
   ```sql
   CREATE DATABASE uparjonx_db;
   ```
3. The application will use Flyway to automatically create and migrate all tables upon startup. The default credentials in `application.yaml` are:
   - **Username:** `postgres`
   - **Password:** `postgres`
   *(Update these in your local environment or `application.yaml` if yours differ).*

## 2. Backend Setup (Spring Boot)

The backend is a Spring Boot application built with Maven.

1. Navigate to the root directory of the project:
   ```bash
   cd platform
   ```
2. Build the project and download all dependencies:
   ```bash
   ./mvnw clean install -DskipTests
   ```
   *(On Windows, use `mvnw.cmd clean install -DskipTests`)*
3. Run the Spring Boot application:
   ```bash
   ./mvnw spring-boot:run
   ```
4. The backend should now be running at `http://localhost:8080`.
   - The database will be automatically seeded by `DatabaseSeeder.java` if it's empty.

## 3. Frontend Setup (Angular)

The frontend is an Angular 18+ web application.

1. Open a new terminal and navigate to the frontend directory:
   ```bash
   cd platform/frontend
   ```
2. Install all NPM dependencies:
   ```bash
   npm install
   ```
3. Start the Angular development server:
   ```bash
   npm run start
   ```
   *(Or `ng serve` if you have the Angular CLI installed globally)*
4. The frontend application should now be accessible at `http://localhost:4200`.

## 4. End-to-End Testing (Playwright)

We use Playwright for automated E2E testing of critical frontend flows against the real backend API.

1. Make sure both your backend (`localhost:8080`) and frontend (`localhost:4200`) are running.
2. Navigate to the `frontend` folder.
3. Install Playwright browsers (first-time only):
   ```bash
   npx playwright install
   ```
4. Run the tests:
   ```bash
   npx playwright test
   ```
5. To view the HTML report of the test results:
   ```bash
   npx playwright show-report
   ```

## Additional Notes

- **API Documentation:** Once the backend is running, you can explore the Swagger UI at `http://localhost:8080/swagger-ui.html`.
- **Mock Services:** Certain features like email and SMS OTPs are simulated locally and logged to the console to avoid unnecessary third-party API costs during development.
