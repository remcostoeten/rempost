# Rempost Project Plan (Operational MVP)

## North Star
Convert raw forwarded ecommerce emails into reliable, real-time operational intelligence.

## Phase 0 — Foundations (Done / In Progress)
- [x] Phoenix app skeleton and contexts
- [x] Core schemas: workspaces, inbound_emails, orders, shipments, tracking_events
- [x] Oban setup for async jobs
- [x] Basic LiveViews for dashboard, shipments, and email debug
- [~] Deterministic parser baseline

## Phase 1 — Ingestion & Parsing Reliability (Current Execution)
### Goals
1. Ensure ingestion remains idempotent and safe under retries.
2. Make parsing states operationally visible (`pending -> processing -> parsed|failed`).
3. Guarantee failures are captured on canonical raw emails.

### Acceptance Criteria
- Inbound ingestion always persists raw email before parsing.
- Duplicate message IDs are accepted idempotently without data corruption.
- Worker transitions email status to `processing` before parsing.
- Successful parse clears stale parse errors.
- Failures update `status=failed` and store an error reason.

## Phase 2 — Structured Extraction Expansion
### Goals
- Expand deterministic extraction coverage:
  - order numbers
  - carrier detection
  - tracking numbers by carrier
  - lifecycle status normalization
- Add regression tests per carrier template.

### Acceptance Criteria
- Parser fixtures pass consistently.
- Normalized output shape stays stable.

## Phase 3 — Operational Dashboard Depth
### Goals
- Add KPI tiles: active shipments, failed parsing, delayed deliveries, recent inbound volume.
- Add shipment timeline density improvements.
- Add email debug panel with retry parsing action.

### Acceptance Criteria
- Dashboard updates over PubSub without full refresh.
- Operators can inspect raw + parsed data and retry failures.

## Phase 4 — Tenant Isolation Hardening
### Goals
- Enforce workspace scoping everywhere.
- Add tests for cross-workspace access denial.

### Acceptance Criteria
- No context query returns cross-tenant records.

## Phase 5 — Background Ops & Recovery
### Goals
- Retry workflows for failed parsing.
- Dead-letter visibility in UI.
- Replay tooling by workspace/date range.

### Acceptance Criteria
- Failed jobs are visible and recoverable by operators.

## Phase 6 — Production Readiness
### Goals
- Add telemetry and structured logging around pipeline stages.
- Harden indexes and query plans for high ingestion volume.
- Define runbooks and operational alerts.

### Acceptance Criteria
- Mean-time-to-detect parse failures is low.
- Pipeline throughput scales with queue concurrency.
