# File Upload Guide

Avatar upload:

| Field | Value |
| --- | --- |
| Endpoint | `POST /api/v1/mobile/profile/avatar` |
| Content type | `multipart/form-data` |
| File field | `file` |
| Expected files | JPG, JPEG, PNG, WEBP |
| Recommended max size | 5 MB |

KYC upload:

| Field | Value |
| --- | --- |
| Endpoint | `POST /api/v1/mobile/kyc` |
| Content type | `multipart/form-data` |
| File fields | `frontDocument`, `backDocument`, `selfie` |
| Text fields | Full name, date of birth, national ID number as defined by Swagger |
| Expected files | JPG, JPEG, PNG, PDF for documents; JPG, JPEG, PNG for selfie |
| Recommended max size | 10 MB per document |

General upload rules:

- Always send `Authorization: Bearer <accessToken>`.
- Do not manually set multipart boundaries; let Dio/http package set them.
- Compress large images on device before upload.
- On `VALIDATION_ERROR`, show per-field errors when returned.
- On network failure, ask user to retry; do not silently queue KYC files.
