# Armory Telemetry Contract

Telemetry is anonymous and privacy-first.

## Event Endpoint

- Method: `POST`
- Path: `/v1/events`
- Content-Type: `application/json`

## Required Payload

```json
{
  "eventName": "installer_generated",
  "installId": "uuid",
  "sessionId": "uuid",
  "source": "dashboard",
  "toolIds": ["remedy", "chronicle"],
  "mode": "saga",
  "manifestRef": "<git-ref>",
  "timestamp": "2026-02-21T00:00:00Z"
}
```

## Retry / Backoff

- Dashboard telemetry is best-effort and non-blocking.
- Installer telemetry attempts one request and ignores network failures.
- Future endpoint implementations may add exponential retry.

## Opt-Out

- Installer flag: `-NoTelemetry`
- Env var: `ARMORY_TELEMETRY=off`
- Dashboard checkbox: "Opt out of anonymous telemetry"
