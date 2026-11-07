# Mobile API Changes — 2026-09-30

What changed for the mobile app in this release. Everything is **additive**: existing fields keep their names and meaning, so current app builds keep working.

- **Stage API**: `https://api.avytor.com/api/v1`
- **Auth**: `Authorization: Bearer <accessToken>` from `POST /api/v1/auth/login`
- **Test user**: `kyc@test.com` / `Password@123`

## Summary

| # | Endpoint | Change | Action for the app |
|---|---|---|---|
| 1 | `GET /mobile/campaigns/{id}` | Now returns the ad: `adId`, `adType`, `videoUrl`, `thumbnailUrl`, `passingScore`, `maxAttempts`, `questions` | Play the video and show the questions from this response |
| 2 | `GET /mobile/campaigns`, `/featured`, `/trending`, `home-feed.featuredCampaigns` | `type` is now the real ad type (`VIDEO` or `QUIZ`); newest first | Use `type` for the card badge and to choose the screen |
| 3 | `GET /mobile/ads/feed` | Adds `adType`, `thumbnailUrl`; returns the 20 newest active ads | Show the thumbnail and the ad type |
| 4 | `GET /mobile/quizzes`, `home-feed.quizzes` | Now filled with real quizzes | Build or enable the Quiz section |
| 5 | Errors | Documented the real error body and status codes | Branch on HTTP status and `errorCode` |

---

## 1. Campaign details include the video and questions

`GET /api/v1/mobile/campaigns/{campaignId}`

Before, this returned only title, image, reward and duration, so the app had no video or questions to show. New fields are marked `NEW`.

```json
{
  "success": true,
  "message": "Campaign details retrieved successfully",
  "data": {
    "id": "814c706b-5bbc-4250-880f-de815d2b2873",
    "title": "Arogga & Praava Digital Health Access Campaign - Quiz",
    "description": "Public wellness initiative incentivizing preventative health checks.",
    "image": "https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?w=600",
    "instructions": "1. Watch the video ad completely.\n2. Complete the required tasks.\n3. Claim your reward.",
    "rewardAmount": 15.00,
    "estimatedDuration": 10,
    "eligible": true,
    "adId": "054266f2-5faa-4850-80d6-e4b67e552dc2",
    "adType": "QUIZ",
    "videoUrl": "https://api.avytor.com/api/v1/files/download/df448967-d136-4b27-84d5-5e5c2a6cc059.mp4",
    "thumbnailUrl": "https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?w=600",
    "passingScore": 100,
    "maxAttempts": 3,
    "questions": [
      {
        "id": "9e073534-6943-4938-a08e-8f85b144bd6d",
        "questionText": "What energy savings percentage was demonstrated in the ad?",
        "questionType": "SINGLE_CHOICE",
        "isRequired": true,
        "orderIndex": 0,
        "options": [
          { "id": "0e093b03-97da-4e5b-9507-ab9026c97513", "optionText": "15%" },
          { "id": "b866ce57-81b3-48ac-96a4-b20b2fadbff3", "optionText": "5%" },
          { "id": "f66fbd6b-b1cf-461d-95f3-1e495f82466c", "optionText": "50%" }
        ]
      }
    ]
  }
}
```

| Field | Type | Notes |
|---|---|---|
| `adId` | string (UUID) | `NEW`. Use for `POST /mobile/ads/{adId}/view` and as `adId` in `POST /quizzes/submit` |
| `adType` | string | `NEW`. `VIDEO` = watch and earn; `QUIZ` = watch, then answer `questions` |
| `videoUrl` | string | `NEW`. Media to play for at least `estimatedDuration` seconds |
| `thumbnailUrl` | string, nullable | `NEW`. Poster image |
| `passingScore` | number, nullable | `NEW`. Percent of correct answers needed (quiz only) |
| `maxAttempts` | number, nullable | `NEW`. Quiz retries allowed |
| `questions` | array | `NEW`. Empty for `VIDEO`. Options never include the correct answer |

`adId`, `adType` and `videoUrl` are `null` (and `questions` is empty) if a campaign has no ad yet — hide the Start button in that case.

### Flow to earn from a campaign

```
GET  /mobile/campaigns                 -> list; tap a card
GET  /mobile/campaigns/{campaignId}    -> adId, adType, videoUrl, questions
     play videoUrl for at least estimatedDuration seconds
POST /mobile/ads/{adId}/view           body: {"watchedDurationSeconds": 10, "deviceId": "<device-id>"}
     VIDEO -> reward credited now (status REWARDED). Done.
     QUIZ  -> status COMPLETED, reward waits for the answers
POST /quizzes/submit                   body: {"adId": "<adId>", "answers": [{"questionId": "<id>", "optionId": "<id>"}]}
     {"passed": true,  "rewardTriggered": true}  -> reward credited, card becomes COMPLETED
     {"passed": false, "rewardTriggered": false} -> user may retry until maxAttempts
GET  /mobile/wallet/overview           -> refresh balance
```

---

## 2. Real ad type on campaign cards, newest first

Affects `GET /mobile/campaigns`, `GET /mobile/campaigns/featured`, `GET /mobile/campaigns/trending` and `featuredCampaigns` in `GET /mobile/home-feed`.

- `type` was always `"VIDEO"`. It is now the campaign's ad type: `"VIDEO"` or `"QUIZ"`.
- Lists are sorted newest first, so newly published campaigns appear on page 0.

```json
{
  "id": "814c706b-5bbc-4250-880f-de815d2b2873",
  "title": "Arogga & Praava Digital Health Access Campaign - Quiz",
  "thumbnailUrl": "https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?w=600",
  "type": "QUIZ",
  "rewardAmount": 15.00,
  "durationSeconds": 10,
  "status": "ACTIVE"
}
```

Cards still do not contain the video or questions; open the details endpoint (§1) for those.

---

## 3. Ads feed: ad type and thumbnail

`GET /api/v1/mobile/ads/feed` (plain JSON array, no `success`/`data` wrapper)

- Adds `adType` (`VIDEO` or `QUIZ`) and `thumbnailUrl` (nullable) to every item.
- Returns the **20 newest** active ads (before, 20 in no fixed order, so new videos could be missing).

```json
[
  {
    "adId": "bde96b13-ff6f-447e-8f9b-c3c60afd061c",
    "title": "Doorstep Healthcare & Diagnostic Care Showcase Ad",
    "videoUrl": "https://api.avytor.com/api/v1/files/download/df448967-d136-4b27-84d5-5e5c2a6cc059.mp4",
    "duration": 10,
    "reward": 15.00,
    "viewed": false,
    "status": "ACTIVE",
    "adType": "VIDEO",
    "thumbnailUrl": "https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?w=600"
  }
]
```

For a `QUIZ` item, load its questions with `GET /api/v1/ads/{adId}` (or from campaign details) after the video.

---

## 4. Standalone quizzes now have data

The Quiz section (`GET /mobile/quizzes` and `quizzes` in `GET /mobile/home-feed`) was always empty because nothing could create quizzes. Admins can now create them, and stage has seeded quizzes. The mobile endpoints themselves did not change:

| Step | Endpoint | Notes |
|---|---|---|
| List | `GET /api/v1/mobile/quizzes` | Plain array of `{ id, title, totalQuestions, questionCount, rewardAmount }`. A quiz disappears after the user submits it |
| Open | `GET /api/v1/mobile/quizzes/{id}` | `{ id, title, description, rewardAmount, questions: [{ id, questionText, options: [{ id, optionText }] }] }` |
| Submit | `POST /api/v1/mobile/quizzes/{id}/submit` | Body `{"answers": [{"questionId": "<id>", "optionId": "<id>"}]}`; all questions required |

Submit response:

```json
{ "score": 1, "totalQuestions": 1, "passed": true, "rewardAmount": 15.00, "reward": 15.00, "message": "Congratulations! You passed the quiz." }
```

- Pass = at least 60% correct; the reward is credited on pass.
- One attempt per quiz. A second submit returns `500` `ILLEGAL_STATE` "You have already completed this quiz."

---

## 5. Error responses (corrected documentation)

Error body:

```json
{
  "success": false,
  "errorCode": "ALREADY_CLAIMED",
  "message": "You have already completed and claimed the reward for this ad",
  "timestamp": "2026-09-30T18:00:00"
}
```

| HTTP | `errorCode` | When |
|---|---|---|
| `400` | e.g. `VALIDATION_ERROR` | Invalid body, unknown ID, missing answers, invalid option ID |
| `401` | — | Access token missing or expired — call `/auth/refresh` |
| `409` | `ALREADY_CLAIMED` | Reward for this ad already claimed |
| `500` | `ILLEGAL_STATE` | Rule not met: quiz submitted before the video view, quiz already completed, max attempts reached. Show `message` |

Earlier docs said a quiz submitted before watching returns `400`; it actually returns `500` with `ILLEGAL_STATE`.

These endpoints return plain JSON (no `success`/`data` wrapper): `/mobile/ads/feed`, `/mobile/ads/{id}/view`, `/quizzes/submit`, `/mobile/quizzes/**`, `/mobile/surveys/**`.

---

## Data on stage

Stage is seeded with surveys, standalone quizzes, `VIDEO` ad campaigns and `QUIZ` ad campaigns, all active and not yet completed by the test user. Full reference for every endpoint: `docs/mobile-api-specification.md`.
