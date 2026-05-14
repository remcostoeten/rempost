# Rempost PRD

## Summary

Rempost is a self-service order and tracking portal backed by an email ingestion pipeline.

The product exists so people who use the owner's ecommerce accounts do not need to ask the owner for order emails or track-and-trace links. They can visit Rempost, search for the relevant order or shipment, answer a security question, and view the tracking details that were extracted from forwarded ecommerce emails.

Rempost is not an email client. Users should not browse the owner's mailbox. Raw emails are stored for ingestion, parsing, debugging, and operational audit only.

## Product Goal

Turn forwarded ecommerce emails into searchable, structured shipment data.

```txt
Cloudflare Email Routing
-> raw email storage
-> async parsing
-> derived order/shipment records
-> self-service lookup
-> secure tracking reveal
```

## Primary Users

### Self-service user

Someone who needs order or delivery information for an order placed through the owner's account.

They need to:

- search for an order, shop, carrier, or shipment status
- see whether a relevant shipment exists
- answer a security question
- reveal the track-and-trace number and carrier link

They should not:

- read raw emails
- access the admin dashboard
- retry parser jobs
- see unrelated sensitive mailbox data

### Operator/admin

The owner or maintainer of the system.

They need to:

- inspect inbound emails
- inspect parser status
- see failed parsing
- retry parsing
- debug Cloudflare ingestion
- understand what structured shipment data was derived

## Non-Goals

Rempost is not:

- a Gmail or Outlook clone
- a shared mailbox UI
- a CRM
- a customer support desk
- a general personal-email search engine
- a billing or notification system

The admin raw-email view is an operational triage surface, not a mailbox UI. It exists to debug ingestion and parsing, not to browse correspondence.

## Core Requirements

### Email Ingestion

- Cloudflare Email Routing forwards ecommerce emails to Rempost.
- Rempost receives normalized payloads through `POST /api/inbound/email`.
- Raw email data is persisted before any parsing happens.
- Duplicate messages are deduplicated by message ID.
- Parsing must run asynchronously through Oban.

### Raw Email Storage

Raw emails are canonical.

The system stores:

- message ID
- sender
- subject
- received timestamp
- raw headers
- raw text
- raw HTML
- processing status
- parse error, when present

Raw emails are internal records. Public users do not access them.

### Parsing

Deterministic parsing comes first.

The parser should extract only high-confidence fields:

- order number
- carrier
- tracking number
- tracking URL
- broad shipment status

Broad shipment statuses:

- `ordered`
- `shipped`
- `in_transit`
- `delivered`
- `failed`

The parser should support Dutch ecommerce/shipment emails first, including common DHL, PostNL, XXL Nutrition, order confirmation, shipped, in-transit, and delivered phrases.

The parser must not invent fake tracking numbers. If no tracking number is found, the raw email may still be marked parsed, but no shipment should be created.

### Derived Data

Orders and shipments are derived models.

Orders should represent the ecommerce order when an order number can be extracted or inferred.

Shipments should represent trackable delivery records and require a real tracking number.

Tracking numbers and tracking URLs are sensitive fields.

### Self-Service Portal

The default user-facing route should be the self-service shipment lookup.

Users can:

- search shipment records
- see non-sensitive shipment context
- verify access with a security answer
- reveal track-and-trace details after verification

Before verification, the UI may show:

- order number
- shop/sender
- carrier
- broad status
- masked tracking suffix

Before verification, the UI must hide:

- full tracking number
- tracking URL
- raw email content

### Security Verification

The first version uses a shared security answer configured by environment variable.

Required production behavior:

- production must not use a hardcoded fallback answer
- missing configuration should fail closed
- verification should be scoped to the browser session
- verification should expire after a reasonable TTL

Future versions may support per-order questions or stronger authentication.

### Admin Dashboard

Admin surfaces are separate from public self-service routes.

Admin users need:

- inbound email dashboard
- raw email debug view
- parser status
- parse error visibility
- retry parsing action
- Oban dashboard

Admin routes must be protected before the product is shared with non-admin users.

### Realtime Updates

The portal and admin dashboard should update through Phoenix PubSub and LiveView when:

- a new email is ingested
- parsing starts
- parsing succeeds
- parsing fails
- a shipment is created or updated

Manual refresh should not be required for normal updates.

## UX Principles

The product should feel:

- operational
- calm
- fast
- search-first
- dense but readable
- reliable

The self-service route should be simpler than the admin dashboard.

Self-service users should not need to understand parsing, raw emails, Oban, or system internals.

Admin users should see enough operational detail to debug ingestion and parsing failures quickly.

## Current MVP State

Implemented:

- Cloudflare-compatible inbound email endpoint
- raw inbound email persistence
- async Oban parsing worker
- deterministic parser for basic English and Dutch shipment patterns
- derived orders and shipments
- tracking URL field on shipments
- self-service shipment lookup
- masked tracking before verification
- shared-answer tracking reveal with browser-session TTL
- admin email dashboard and email debug view
- admin auth for dashboard, email debug, Oban, and admin email search API
- LiveView/PubSub update wiring
- sample `.eml` exports ignored from git

Known gaps:

- parser tests should use sanitized real-world fixtures (see [docs/FIXTURES.md](FIXTURES.md))
- worker/controller/LiveView behavior needs broader test coverage
- local dev database may contain a stale deleted-workspace migration entry

## MVP Acceptance Criteria

The MVP is usable when:

- a forwarded ecommerce email appears in Rempost without manual import
- the raw email is stored before parsing
- parsing runs asynchronously
- a shipment with real tracking data is created when extraction is confident
- no fake shipment is created when no tracking number is found
- public users can search shipments
- public users cannot see raw emails
- tracking number and tracking URL stay hidden until verification
- verified users can open the carrier tracking link
- admin users can inspect raw emails and retry failed parsing
- new inbound emails and parsed shipments appear without manual refresh

## Milestones

Each milestone has a fixed scope and a done-when test. Milestones ship in order.

### M1 — Safe Sharing

Scope:

- protect `/dashboard`, `/emails/:id`, `/api/inbound/emails`, and `/oban` behind admin auth
- fail closed when `REMPOST_PORTAL_ACCESS_ANSWER` is missing in production
- persist tracking-reveal verification in the browser session with a TTL
- align README and project plan with this PRD

Done when:

- an unauthenticated visitor cannot reach any admin route
- production refuses to boot or refuses reveal when the access answer env var is unset
- a verified visitor stays verified across page refreshes until the TTL expires

### M2 — Parser Reliability

Scope:

- sanitized Dutch `.eml` / text fixtures committed under `test/fixtures` per [docs/FIXTURES.md](FIXTURES.md)
- PostNL and DHL carrier detection variants
- tracking URL extraction from HTML link targets, not only plain text
- structured extraction-failure reasons stored on the raw email
- idempotency tests for the parsing pipeline

Done when:

- the parser test suite runs on sanitized fixtures with no real customer data
- re-parsing the same email twice produces no duplicate orders or shipments
- a failed parse stores a machine-readable reason, surfaced in admin

### M3 — Self-Service Polish

Scope:

- clearer empty states and grouped search results
- search match highlighting
- shipment-detail status timeline
- copy-tracking-number action after verification
- mobile-first portal layout

Done when:

- portal usable end-to-end on a typical phone viewport without horizontal scroll
- empty, loading, and error states render distinctly for every portal view

### M4 — Operational Hardening

Scope:

- parser failure metrics
- Oban queue lag visibility
- admin replay tools for stuck/failed jobs
- configurable raw email retention
- optional raw email hard-delete policy

Done when:

- admin can see parser failure rate and queue lag without shelling into the box
- a retention policy can be configured and removes raw emails past the threshold

## Final Principle

Rempost's value is not showing emails.

Its value is converting trusted inbound ecommerce emails into safe, searchable, self-service shipment information.
