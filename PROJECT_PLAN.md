# Rempost Project Plan (Cloudflare Email → Searchable Ops Dashboard)

## Product Scope (Current)
Build a focused operational pipeline:

1. Cloudflare forwards incoming email events
2. Rempost ingests raw payloads via `/api/inbound/email`
3. Raw email is persisted first
4. Parsing runs asynchronously via Oban
5. Structured entities are derived (orders/shipments/tracking)
6. Operators view/search inbound emails in dashboard

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

## Phase C — Operator UI (Done for MVP)
- [x] basic dashboard route (`/` + `/dashboard`)
- [x] searchable inbound email table
- [x] live updates via PubSub lifecycle events
- [x] email debug page with retry parsing action

## Phase D — Data Lifecycle (In Progress)
- [x] scheduled raw email retention worker (daily)
- [ ] configurable retention days per environment/workspace
- [ ] optional hard-delete mode for old raw email records

## Phase E — Parser Depth (Next)
- [ ] add fixture-based tests for real XXL/DHL/UPS/FedEx examples
- [ ] improve extraction accuracy for order/tracking/status variants
- [ ] add explicit extraction-failure reason taxonomy

## Phase F — Hardening (Later)
- [ ] full test coverage for ingestion controller + worker + contexts
- [ ] operational alerts/telemetry around parsing failures and queue lag
- [ ] admin tooling for replaying raw emails by date range


## MVP Status
- ✅ End-to-end MVP is now implemented for a single mailbox:
  - Cloudflare worker receives email
  - Phoenix ingests/persists raw payload
  - Oban parses asynchronously
  - Dashboard lists/searches inbound emails
  - Debug view supports parsing retry
  - Retention worker redacts old raw payload data
