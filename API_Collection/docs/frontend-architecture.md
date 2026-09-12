# Angular Frontend Architecture

This document describes the structural layout and architectural patterns used in the Angular Web/Admin frontend (`platform/frontend`). While Mobile relies on Flutter, the web ecosystem is fully driven by Angular 18+.

## Directory Structure

The application's source code is primarily housed in `src/app/`, separated into feature-driven modules.

```text
src/app/
├── core/             # Core singletons, interceptors, auth guards, and services
├── features/         # Reusable feature modules (e.g., campaigns, users, ads)
├── layout/           # Global layouts (e.g., sidebar, header, main layout wrappers)
├── pages/            # Routable smart components representing entire views
├── shared/           # Dumb components, UI elements, pipes, directives
└── mobile-preview/   # Specific isolated pages for mobile UI emulation (e.g., Auth views)
```

## State Management

We use **Angular Signals** for reactive state management to provide fine-grained reactivity and eliminate RxJS boilerplate where appropriate.

- **Signal Stores**: Small, focused state services (e.g., `AuthSignalStore`) manage their own state atoms.
- Components read data by calling signals directly (e.g., `store.isLoading()`).
- Writes to state are managed internally by the store methods, ensuring predictability and unidirectional data flow.

## Routing Strategy

We utilize modern standalone component routing:
- **Lazy Loading**: Major feature modules are lazy-loaded through standard Angular `loadChildren` or `loadComponent`.
- **Guards**: 
  - `authGuard` protects administrative and advertiser views, ensuring a user has a valid active session.
  - `roleGuard` enforces Role-Based Access Control (RBAC) at the route level, matching user roles (e.g., `ROLE_ADVERTISER`, `ROLE_SUPER_ADMIN`, `ROLE_FINANCE_ADMIN`) against allowed configurations.

## API Integration

- **Environment Config**: Uses environment files (`environment.ts`) for endpoint configuration.
- **Interceptors**: 
  - To prevent auth token collisions, the platform strictly isolates interceptors using an Angular `HttpContextToken` (`IS_MOBILE_PREVIEW_API`).
  - The **`AuthInterceptor`** attaches the Bearer token for the admin web portal, and explicitly *ignores* any requests carrying the mobile preview token flag.
  - The **`MobileApiInterceptor`** attaches the mobile app session token and handles telemetry simulation, but *only* if the request carries the mobile preview token flag.
  - An error interceptor centrally handles 401 Unauthorized errors by invoking a token refresh or redirecting to the login view if the session cannot be restored.

## Analytics & Charts Integration

For the **Advertiser Analytics Dashboard** (`/advertiser-analytics`), we integrate `ng2-charts` and `Chart.js` for data visualization.
- Line charts show view and completion trends over customized date ranges.
- Real-time date picker controls trigger unified re-fetch calls to `/api/v1/analytics/advertiser/*` (overview, campaigns, trends).
- Offers direct CSV download export via browser redirect to `/api/v1/analytics/advertiser/export`.

## Campaign Builder Wizard & Real-Time Estimation

The campaign creation dialog in `CampaignsList` features a multi-step form wizard incorporating:
- **General Fields**: Objective selection (`VIDEO_VIEWS`, etc.), total campaign budget, and start/end dates.
- **Targeting Criteria**: Real-time rules configurations (Gender, Age Range, Location, and Activity statuses).
- **Audience Reach Estimation**: Subscription to `targetingForm.valueChanges` fires async requests to `/api/v1/campaigns/targeting/estimate` to dynamically estimate reachable audience size prior to creation.
- **Creative & Reward Uploads**: Multipart uploads handle creative files before posting to `/api/v1/campaigns/{id}/creatives` and configuring rewarded ad rules.

## Styling Approach

- **SCSS**: Global and component-scoped SCSS are used.
- **Material UI**: Angular Material is incrementally adopted for standard controls (e.g., icons, buttons, spinners).
- **Responsive Design**: Mobile-first media queries and flexbox ensure administrative tables scale down accurately for tablet environments.
