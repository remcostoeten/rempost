# Rempost Project Plan (Email → Shipment Intelligence)

## Product Scope (Current)
Build a focused operational pipeline:

1. Cloudflare forwards incoming email events
2. Rempost ingests raw payloads via `/api/inbound/email`
3. Raw email is persisted first
4. Parsing runs asynchronously via Oban
5. Structured entities are derived (orders/shipments/tracking)
6. Public users search shipment data without raw email access
7. Operators debug ingestion, parsing, and jobs through protected admin surfaces

## Phase A — Ingestion Baseline (Done)
- [x] API route for inbound email payloads
- [x] Cloudflare-friendly field normalization (`id`, `from`, `text/raw`, `html`, `date`)
- [x] Required field validation + accepted response semantics
- [x] Persist-first workflow before parsing

## Phase B — Parsing Reliability (Done)
- [x] Oban parser worker and retry-safe ingestion flow
- [x] lifecycle states: `pending`, `processing`, `parsed`, `failed`
- [x] parse errors persisted for operator debugging
- [x] parser retry action in email debug view

## Phase C — Public Portal + Operator UI (Done for MVP)
- [x] public shipment lookup route (`/`, `/portal`, `/shipments`)
- [x] browser-session verification before tracking reveal
- [x] admin dashboard route (`/dashboard`)
- [x] searchable inbound email table for admins
- [x] live updates via PubSub lifecycle events
- [x] email debug page with retry parsing action

## Phase D — Safe Sharing (Done)
- [x] protect `/dashboard` with admin auth
- [x] protect `/emails/:id` with admin auth
- [x] protect `/oban` with admin auth
- [x] protect `GET /api/inbound/emails` with admin auth
- [x] keep `/`, `/portal`, and shipment lookup public
- [x] remove hardcoded portal fallback answer
- [x] persist portal verification in session with TTL
- [x] document env vars and public/admin route split
- [x] document local migration drift reset path without restoring workspace migration

## Phase E — Data Lifecycle (In Progress)
- [x] scheduled raw email retention worker (daily)
- [ ] configurable retention days per environment
- [ ] optional hard-delete mode for old raw email records

## Phase F — Parser Depth (Next)
- [ ] add fixture-based tests for real XXL/DHL/UPS/FedEx examples
- [ ] improve extraction accuracy for order/tracking/status variants
- [ ] add explicit extraction-failure reason taxonomy

## Phase G — Hardening (Later)
- [ ] full test coverage for ingestion controller + worker
- [ ] operational alerts/telemetry around parsing failures and queue lag
- [ ] admin tooling for replaying raw emails by date range


## MVP Status
- End-to-end MVP is now implemented for a single mailbox:
  - Cloudflare worker receives email
  - Phoenix ingests/persists raw payload
  - Oban parses asynchronously
  - Public users search derived shipment data
  - Verified public sessions reveal tracking details until TTL expiry
  - Admin dashboard lists/searches inbound emails
  - Admin debug view supports parsing retry
  - Admin routes and Oban are protected by Basic Auth
  - Retention worker redacts old raw payload data

## Route Ownership

Public:

- `/`, `/portal`, `/shipments`, `/shipments/:id`
- `POST /api/inbound/email` with inbound token

Admin:

- `/dashboard`
- `/emails/:id`
- `/oban`
- `GET /api/inbound/emails`

Required env vars before external sharing:

- `REMPOST_INBOUND_TOKEN`
- `REMPOST_ADMIN_USER`
- `REMPOST_ADMIN_PASSWORD`
- `REMPOST_PORTAL_ACCESS_ANSWER`

Optional:

- `REMPOST_PORTAL_VERIFICATION_TTL_SECONDS` defaults to `3600`
