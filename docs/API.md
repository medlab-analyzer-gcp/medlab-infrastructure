# Medical Lab Analyzer — API Reference

|              |                                         |
| ------------ | --------------------------------------- |
| **Version**  | 1.0.0                                   |
| **Gateway**  | GCP API Gateway                         |
| **Protocol** | HTTPS (REST) + WebSocket                |

---

## Base URLs

| Service          | URL                                                                 |
| ---------------- | ------------------------------------------------------------------- |
| API Gateway      | `https://medlab-analyzer-api.apigateway.swe455-medlab.cloud.goog`  |
| WS Service       | `https://medlab-analyzer-ws-service-<hash>-uc.a.run.app`           |

All REST requests go through the **API Gateway**. The WebSocket connects directly to the **WS Service** (API Gateway does not support WebSocket).

---

## Authentication

All requests must include a Firebase JWT token in the `Authorization` header:

```
Authorization: Bearer <firebase-id-token>
```

Tokens are obtained from Firebase Authentication after login. Each service validates the token independently.

---

## Reports

### Upload a Report

Upload a lab report file (PDF or image) to Cloud Storage and create a Firestore record.

**`POST /reports`**

Content-Type: `multipart/form-data`

| Field    | Type   | Required | Description             |
| -------- | ------ | -------- | ----------------------- |
| `file`   | File   | Yes      | The report file         |
| `userId` | string | Yes      | Firebase UID of uploader |

**Response `201 Created`**

```json
{
  "reportId": "abc123",
  "userId": "user_firebase_uid",
  "fileName": "report.pdf",
  "status": "uploaded",
  "uploadedAt": "2026-05-03T10:00:00Z",
  "fileUrl": "gs://swe455-medlab-reports/abc123/report.pdf"
}
```

---

### List Reports

Retrieve all reports for a specific user.

**`GET /reports?userId={userId}`**

| Query Param | Type   | Required | Description           |
| ----------- | ------ | -------- | --------------------- |
| `userId`    | string | Yes      | Firebase UID to filter by |

**Response `200 OK`**

```json
[
  {
    "reportId": "abc123",
    "userId": "user_firebase_uid",
    "fileName": "report.pdf",
    "status": "analyzed",
    "uploadedAt": "2026-05-03T10:00:00Z"
  }
]
```

---

### Get Report

Retrieve details of a single report.

**`GET /reports/{id}`**

| Path Param | Type   | Description  |
| ---------- | ------ | ------------ |
| `id`       | string | Report ID    |

**Response `200 OK`**

```json
{
  "reportId": "abc123",
  "userId": "user_firebase_uid",
  "fileName": "report.pdf",
  "status": "analyzed",
  "uploadedAt": "2026-05-03T10:00:00Z",
  "fileUrl": "gs://swe455-medlab-reports/abc123/report.pdf"
}
```

**Response `404 Not Found`**

```json
{ "error": "Report not found" }
```

---

### Delete Report

Delete a report from Firestore and Cloud Storage.

**`DELETE /reports/{id}`**

| Path Param | Type   | Description |
| ---------- | ------ | ----------- |
| `id`       | string | Report ID   |

**Response `200 OK`**

```json
{ "message": "Report deleted successfully" }
```

---

### Get File Download URL

Generate a temporary signed URL to download the original report file from Cloud Storage. The URL expires after 15 minutes.

**`GET /reports/{id}/file-url`**

| Path Param | Type   | Description |
| ---------- | ------ | ----------- |
| `id`       | string | Report ID   |

**Response `200 OK`**

```json
{
  "url": "https://storage.googleapis.com/swe455-medlab-reports/abc123/report.pdf?X-Goog-Signature=..."
}
```

---

## Analysis

### Queue Analysis Request

Submit lab values for analysis. Instead of calling the analysis service directly, the report service publishes a message to **Pub/Sub**, which delivers it to the analysis service asynchronously. This decouples the services and ensures the request is not lost if the analysis service is temporarily unavailable.

**`POST /analyze-request`**

```json
{
  "reportId": "abc123",
  "userId": "user_firebase_uid",
  "values": {
    "hemoglobin": 13.5,
    "wbc": 7.2,
    "rbc": 4.8,
    "platelets": 250
  }
}
```

**Response `202 Accepted`**

```json
{
  "message": "Analysis request queued",
  "reportId": "abc123"
}
```

The `202` response means the request was accepted and queued — not that the analysis is complete. Use the WebSocket to receive a real-time notification when the analysis finishes.

---

### Get Analysis by ID

Retrieve analysis results using the analysis document ID.

**`GET /analyze/{analysisId}`**

| Path Param   | Type   | Description  |
| ------------ | ------ | ------------ |
| `analysisId` | string | Analysis ID  |

**Response `200 OK`**

```json
{
  "analysisId": "xyz789",
  "reportId": "abc123",
  "userId": "user_firebase_uid",
  "status": "analyzed",
  "analyzedAt": "2026-05-03T10:05:00Z",
  "results": {
    "hemoglobin": { "value": 13.5, "status": "normal", "range": "12.0–17.5" },
    "wbc":        { "value": 7.2,  "status": "normal", "range": "4.5–11.0" },
    "rbc":        { "value": 4.8,  "status": "normal", "range": "4.5–5.9"  },
    "platelets":  { "value": 250,  "status": "normal", "range": "150–400"  }
  },
  "summary": "All values within normal range."
}
```

**Response `404 Not Found`**

```json
{ "error": "Analysis not found" }
```

---

### Get Analysis by Report ID

Retrieve the analysis results for a specific report. This is the endpoint the frontend uses on the history page to show analysis results alongside each report.

**`GET /analyze/report/{reportId}`**

| Path Param | Type   | Description |
| ---------- | ------ | ----------- |
| `reportId` | string | Report ID   |

**Response `200 OK`**

```json
{
  "analysisId": "xyz789",
  "reportId": "abc123",
  "userId": "user_firebase_uid",
  "status": "analyzed",
  "analyzedAt": "2026-05-03T10:05:00Z",
  "results": {
    "hemoglobin": { "value": 13.5, "status": "normal", "range": "12.0–17.5" },
    "wbc":        { "value": 7.2,  "status": "normal", "range": "4.5–11.0" }
  },
  "summary": "All values within normal range."
}
```

**Response `404 Not Found`**

```json
{ "error": "No analysis found for this report" }
```

---

## Health Check

Verify the API Gateway and report service are running.

**`GET /health`**

**Response `200 OK`**

```json
{ "status": "healthy", "service": "report-service" }
```

---

## WebSocket (Real-Time Notifications)

The WebSocket service runs on Cloud Run and uses **Firestore onSnapshot** to broadcast notifications across all instances. This solves the scaling problem: Cloud Run can run multiple instances, but any instance can notify the correct client because all instances watch the same Firestore document.

### Connect

```
wss://medlab-analyzer-ws-service-<hash>-uc.a.run.app
```

### Subscribe to Report Updates

After connecting, emit a `subscribe` event with the report ID to watch:

```json
{ "event": "subscribe", "reportId": "abc123" }
```

### Receive Notification

When analysis completes, the server pushes:

```json
{
  "event": "analysis-done",
  "reportId": "abc123",
  "status": "analyzed"
}
```

The frontend listens for this event to hide the loading state and display results without polling.

---

## Error Responses

All endpoints return errors in this format:

```json
{ "error": "Human-readable error message" }
```

| Status | Meaning                                      |
| ------ | -------------------------------------------- |
| `400`  | Bad request — missing or invalid parameters  |
| `401`  | Unauthorized — missing or invalid JWT token  |
| `403`  | Forbidden — token valid but access denied    |
| `404`  | Resource not found                           |
| `500`  | Internal server error                        |

---

## Architecture Flow

```
Frontend
  │
  ├── REST ──► API Gateway ──► report-service   (upload, list, delete, file-url)
  │                       ──► report-service   (POST /analyze-request)
  │                                │
  │                             Pub/Sub
  │                                │
  │                       analysis-service     (processes, writes to Firestore)
  │                                │
  └── WebSocket ──► ws-service ◄── Firestore onSnapshot
                                   (notifies client when status = "analyzed")
```
