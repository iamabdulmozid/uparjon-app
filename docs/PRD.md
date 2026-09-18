# Uparjon — Product Requirements Document (PRD)

| | |
|---|---|
| **Product** | Uparjon (উপার্জন) — "Earning in every home" (উপার্জন হবে ঘরে ঘরে) |
| **Platforms** | Android (primary), iOS (secondary) |
| **Market** | Bangladesh |
| **Doc status** | v1.0 — 2026-08-22 |
| **Design** | [Figma — Uparjon](https://www.figma.com/design/80augsRtHX0YzTIcavNLI8/Uparjon--Copy-) · exported references in `assets/svg/` |

---

## 1. Vision

Uparjon is a mobile earning platform for people in Bangladesh. A user can earn
money from their phone through micro-tasks (watching ads, answering questions,
filling surveys), later through freelancing, and later through e-commerce
cashback. Earnings accumulate in an in-app wallet and are withdrawn through
local mobile financial services (bKash / Nagad / Rocket).

The app is a **super-app shell with three modules**, shipped in phases:

| Phase | Module | Summary | Status |
|---|---|---|---|
| 1 | **Uparjon (Earn)** | Watch video ads, photo ads, answer questions, fill surveys → earn money | **MVP — build now** |
| 2 | **Freelance** | Clients post jobs & hire; freelancers find work | Later |
| 3 | **E-commerce** | Buy products, earn cashback | Later |

The codebase must be structured so Phase 2 and 3 drop in as new feature
modules without restructuring (see `docs/ARCHITECTURE.md`).

## 2. Target users

- **Students** looking for pocket money in spare time.
- **Homemakers / stay-at-home earners** — the tagline audience ("ঘরে ঘরে").
- **Part-time earners** with a smartphone and a bKash/Nagad account.

Implications:
- **Bangla-first UI** with English as secondary locale.
- Must run well on **low/mid-range Android devices** and tolerate slow, flaky
  mobile networks (graceful loading, retries, small payloads).
- Simple onboarding: **phone number + OTP**, no email required.

## 3. Phase 1 scope — Earn module (MVP)

### 3.1 App entry

| ID | Requirement |
|---|---|
| ENT-1 | **Splash screen** (Figma: `Spalsh`): cream background `#FBF6F3`, watercolor cityscape artwork anchored to the bottom, Uparjon logo centered with a subtle entrance animation. Shown while the app bootstraps (load session, config). Minimum display ~2s, then route: first launch → Welcome/Onboarding; logged out → Login; logged in → Home. |
| ENT-2 | **Welcome screen** (Figma: `Spalsh 2`): same artwork, logo raised, **Explore Uparjon** gold gradient CTA → onboarding carousel. Shown only before first login. |
| ENT-3 | **Onboarding carousel** (Figma: `onboarding_flow_01..03`): 3 swipeable slides — *Earn Daily / Rewards beyond advertisements*, *Hire Experts / Trusted professionals nearby*, *Expand Business / Reach your ideal audience*. Each pairs an illustration with an eyebrow + headline and a gold accent bar. Chrome: Skip (top right), page indicator (bottom left), and a gradient next button ringed by a progress arc that completes on the last slide. Skipping or finishing records completion so it is shown only once, then leads to Sign up / Login. |

### 3.2 Authentication

| ID | Requirement |
|---|---|
| AUTH-1 | Sign up with **BD phone number (+880)**, name, password, referral code (optional). |
| AUTH-2 | **OTP verification** via SMS (4 or 6 digit — see `otp_1`, `otp_2` designs) with resend cooldown. |
| AUTH-3 | Login with phone + password (or OTP), "forgot password" via OTP. |
| AUTH-4 | Session: access + refresh tokens stored in secure storage; silent refresh; auto-logout on refresh failure. |
| AUTH-5 | One account per phone number; device binding recorded for fraud checks. |

### 3.3 Home & navigation

| ID | Requirement |
|---|---|
| HOME-1 | Home (Figma: `main_home`) shows wallet balance summary, earning categories (Watch Ads, Surveys, Questions/Quiz), and promos. |
| HOME-2 | Bottom navigation: Home, Earnings/Tasks, Wallet, Profile (icons exported in `assets/icons/`). Freelance & Shop tabs appear in later phases. |
| HOME-3 | Side/overflow menu (Figma: `menu`) with profile, support, terms, logout. |

### 3.4 Earning — Watch Ads

| ID | Requirement |
|---|---|
| ADS-1 | Ad list (Figma: `ad list`, `ad overview`) shows available video/photo ads with reward amount and duration. |
| ADS-2 | Watch flow (Figma: `watch_ad_1..5`, `preparing advertisement`): preparing state → video playback → completion verification → reward credited with confirmation. |
| ADS-3 | An ad only pays after **verified completion** (server-side check: watch duration, focus events). Leaving early forfeits the reward. |
| ADS-4 | Some ads include **follow-up questions about the ad**; answering correctly earns the (bonus) reward. _Status 2026-09-18: UI built (Figma V2 question → Verifying → Congratulation!/Wrong Answer!), but the API still exposes no question or answer endpoint, so it stays hidden until `VideoAdDto` carries one — see ARCHITECTURE.md._ |
| ADS-5 | Daily caps per user (server-configured) to control payout liability. |

### 3.5 Earning — Surveys & questions

| ID | Requirement |
|---|---|
| SUR-1 | Survey list & overview (Figma: `survey list`, `survey overview`) show reward, estimated time, and slots remaining. |
| SUR-2 | Survey runner (Figma: `survey_1..5`): one question per step — single choice, multi choice, free text, rating; progress indicator; answers submitted atomically at the end. |
| SUR-3 | Server may reject low-quality/too-fast submissions (anti-fraud); user sees a clear reason. |
| SUR-4 | Reward credited to wallet on acceptance. |

### 3.6 Wallet & withdrawal

| ID | Requirement |
|---|---|
| WAL-1 | Wallet (Figma: `wallet`) shows current balance (৳), pending earnings, and transaction history (earned / withdrawn / rejected). |
| WAL-2 | Withdraw to **bKash / Nagad / Rocket** with minimum withdrawal threshold and processing states (requested → processing → paid / failed). |
| WAL-3 | All monetary amounts come from the server in the smallest unit (poisha) — the client never computes money. |

### 3.7 Profile & settings

| ID | Requirement |
|---|---|
| PRO-1 | View/edit profile (name, photo, district), linked payout numbers. |
| PRO-2 | Language switch Bangla ⇄ English (app-wide, persisted). |
| PRO-3 | Support/contact, Terms & Privacy, app version, logout, delete account. |

### 3.8 Cross-cutting (MVP)

| ID | Requirement |
|---|---|
| X-1 | **Global error handling**: every API error is mapped to a typed `Failure` and surfaced through one global snackbar/toast system — no raw exceptions or silent failures reach the UI. |
| X-2 | **Global loading & empty states**: shared components for loading, empty, and error-with-retry. |
| X-3 | **Offline awareness**: detect no-connectivity, show non-blocking banner, retry affordances. |
| X-4 | **Localization**: all strings via l10n (bn + en); Bangla numerals where the design uses them. |
| X-5 | **Anti-fraud hooks**: device ID, root/jailbreak signal, app integrity flags sent with reward-earning requests (server decides). |

## 4. Out of scope for MVP

- Freelance module (Phase 2), E-commerce module (Phase 3) — nav placeholders only.
- In-app chat, push-notification campaigns (FCM wiring may land, campaigns later).
- iOS release polish (codebase stays iOS-compatible; Android ships first).

## 5. Non-functional requirements

| Area | Requirement |
|---|---|
| Performance | Cold start < 3s on mid-range Android; 60fps scrolling; app size kept lean (design mockups in `assets/svg/` are **not** bundled). |
| Reliability | Reward-critical calls are idempotent (client sends an idempotency key); no double-credit or double-withdraw from retries. |
| Security | Tokens in platform secure storage; HTTPS only; no secrets in the repo; obfuscated release builds. |
| Scalability | Feature-module architecture; new earn types (e.g. photo tasks) addable as data-driven task types. |
| Maintainability | Layered features, shared core, custom UI kit — see `docs/ARCHITECTURE.md`. |
| Compliance | Play Store real-money/rewards policy review before launch; clear T&C on payout timelines. |

## 6. Design language

Extracted from Figma exports (`assets/`):

| Token | Value | Usage |
|---|---|---|
| Brand gold | `#FDD700` | Primary actions, highlights, logo money-bag |
| Gold gradient | `#FEE79C → #FDD700` (approx.) | CTA buttons ("Explore Uparjon") |
| Charcoal | `#333132` | Headings, logo text |
| Gray | `#6D6E71` | Secondary text |
| Cream | `#FBF6F3` / `#FCF7F3` | Screen backgrounds |
| Surface | `#F9F9F9` | Cards |

- Typography: Bangla-capable font (Hind Siliguri / Noto Sans Bengali) — to be
  confirmed against Figma text styles.
- Components follow a **custom internal UI kit** (shadcn-inspired API: variant
  based buttons, cards, inputs) themed with the tokens above — we do not adopt
  a third-party UI library. Rationale in `docs/ARCHITECTURE.md`.

## 7. Success metrics (MVP)

- Activation: ≥60% of installs complete OTP signup.
- Engagement: median ≥3 completed tasks per active day.
- Trust: ≥95% withdrawals paid within the promised window; crash-free sessions ≥99.5%.

## 8. Open questions

1. Backend: is the API being built in parallel (own backend vs. ad-network SDKs for inventory)? The client assumes a first-party REST API.
2. Reward economics: exact rates, daily caps, minimum withdrawal amount.
3. OTP provider (SMS gateway) choice.
4. Referral program in MVP or fast-follow?
