# Campaign Flow Guide

Lifecycle:

```text
Campaign
  -> Start
  -> Complete
  -> Fraud Validation
  -> Reward Queue
  -> Wallet Credit
```

Flutter APIs:

| Step | API |
| --- | --- |
| Load feed | `GET /api/v1/mobile/home-feed` |
| Load campaigns | `GET /api/v1/mobile/campaigns` |
| View campaign | `GET /api/v1/mobile/campaigns/{id}` |
| Start campaign | `POST /api/v1/mobile/campaigns/{id}/start` |
| Complete campaign | `POST /api/v1/mobile/campaigns/{id}/complete` |
| View rewards | `GET /api/v1/mobile/rewards/history` |
| Refresh wallet | `GET /api/v1/mobile/wallet/overview` |

Reward timing:

- Completion does not always mean instant wallet credit.
- Fraud validation may hold rewards before approval.
- Show pending reward state when reward history returns pending items.
- Refresh wallet after approved reward events or notification deep links.

Client handling:

- On `CAMPAIGN_NOT_ELIGIBLE`, remove/disable the card and refresh feed.
- On duplicate completion, refresh campaign details and reward history.
- Do not complete campaigns offline.

---

## Advertiser Campaign Lifecycle

For advertisers using the Web Portal (Angular application), the campaign setup and tracking flow involves the following APIs:

### 1. Creation & Configuration

| Step | Endpoint | DTO / Payload | Description |
| --- | --- | --- | --- |
| **Estimate Reach** | `POST /api/v1/campaigns/targeting/estimate` | `EstimateAudienceRequest` | Computes eligible user count based on targeting rules |
| **Create Campaign** | `POST /api/v1/campaigns` | `CreateCampaignRequest` | Saves base campaign metadata & status (`PENDING`) |
| **Configure Targeting** | `POST /api/v1/campaigns/{id}/targeting/rules` | `List<TargetingRuleDto>` | Saves audience rules (Gender, Location, Wallet, Age range) |
| **Upload Assets** | `POST /api/v1/files/upload` | Multipart File | Uploads image or video file to cloud storage |
| **Link Creative** | `POST /api/v1/campaigns/{id}/creatives` | `CreateAdCreativeRequest` | Links media format/url and CTA to the campaign |
| **Configure Rewards** | `POST /api/v1/ads` | `CreateAdRequest` | Configures individual reward amounts and questions (if Quiz/Survey) |

### 2. Campaign Targeting Rules logic
Targeting builder supports rules under multiple groups:
- **Demographics**: Gender (MALE, FEMALE, OTHER, ALL), Age Range (Min, Max).
- **Location**: Country, Division/State, District/City.
- **Activity**: User Activity (New, Active, Returning), Wallet Activity (Has Earnings, Has Withdrawals, Never Withdrawn).
- **Participation**: Campaign Participation (Completed Campaigns, Completed Surveys, Completed Quizzes).

### 3. Advertiser Performance Tracking
Once approved and active, campaign statistics are tracked via the Advertiser Analytics dashboard:

| Dashboard Element | API Endpoint | Data Model |
| --- | --- | --- |
| **Overview Cards** | `GET /api/v1/analytics/advertiser/overview` | `AdvertiserOverviewDto` |
| **Campaigns Table** | `GET /api/v1/analytics/advertiser/campaigns` | `CampaignAnalyticsDto` |
| **Detailed Stats & Breakdown** | `GET /api/v1/analytics/advertiser/campaigns/{campaignId}` | `CampaignDetailAnalyticsDto` |
| **Trends Chart** | `GET /api/v1/analytics/advertiser/trends` | `TrendChartDto` |
| **CSV Export** | `GET /api/v1/analytics/advertiser/export` | Text/CSV attachment |

