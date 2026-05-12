# AGENTS.md

## Product

Build Rempost: an Elixir + Phoenix LiveView SaaS for ingesting forwarded ecommerce emails, parsing order/shipment data, and showing operational dashboards.

This is NOT an email client.

It is:

* an email ingestion pipeline
* a structured extraction system
* an operational intelligence dashboard

The system converts raw ecommerce emails into structured operational data.

Examples:

* DHL shipment updates
* XXL Nutrition order confirmations
* delivery status updates
* tracking emails
* failed shipment notifications

---

## Stack

* Elixir
* Phoenix
* Phoenix LiveView
* Ecto
* PostgreSQL
* Oban
* Phoenix PubSub
* TailwindCSS

Optional:

* Swoosh
* Tesla
* Finch

---

## Architecture Philosophy

The application should feel:

* operational
* fast
* calm
* highly structured
* search-first
* realtime
* reliable

This is NOT a marketing-heavy app.

This is operational software for handling ecommerce order/shipment workflows.

The architecture should prioritize:

* maintainability
* scalability
* domain clarity
* background processing
* realtime updates
* operational UX

---

## Core System Flow

```txt
Incoming email
→ POST /api/inbound/email
→ store raw email
→ enqueue Oban parser job
→ parse + extract structured data
→ create/update orders + shipments
→ broadcast realtime update
→ LiveView dashboard updates
```

---

## Domain Rules

### Email ingestion is the source of truth

Never rely on third-party inbox querying.

The system owns:

* raw email storage
* parsing
* extraction
* operational state

---

### Raw emails must always be stored first

Never parse before persistence.

Flow:

1. receive raw email
2. persist raw email
3. enqueue async parsing
4. derive structured entities

---

### Structured entities are derived models

Orders, shipments, tracking events, and customers are derived from raw emails.

The raw email record is canonical.

---

## Phoenix Rules

### Use Phoenix Contexts as the ONLY domain boundaries

Examples:

* Accounts
* Workspaces
* Emails
* Orders
* Shipments
* Tracking
* Parsing

Do NOT create service-layer chaos.

---

### LiveViews must stay thin

LiveViews:

* orchestrate UI
* handle events
* subscribe to realtime updates

LiveViews should NOT:

* contain business logic
* parse emails
* directly manipulate persistence rules

Business logic belongs in contexts.

---

### Controllers must stay thin

Controllers only:

* validate request shape
* delegate to contexts/jobs
* return response

No domain logic in controllers.

---

## Oban Rules

All heavy work must run in Oban jobs.

Examples:

* email parsing
* AI extraction
* tracking synchronization
* retries
* cleanup jobs

Never process emails inline during HTTP requests.

---

### Jobs must be idempotent

Running the same job multiple times must not corrupt state.

Use:

* upserts
* uniqueness
* deduplication
* conflict handling

---

### Failed jobs are first-class states

Do NOT hide failures.

The UI must expose:

* failed parsing
* retries
* dead jobs
* extraction issues

Operational transparency is critical.

---

## Multi-Tenancy Rules

Everything must be scoped correctly.

Use:

* workspace_id
* ownership boundaries
* query isolation

Never allow cross-workspace leakage.

---

## Database Rules

Use Ecto schemas and migrations properly.

Requirements:

* indexes on searchable fields
* foreign key constraints
* enums/status fields where appropriate
* timestamps everywhere
* explicit associations

Store:

* raw email data
* structured extracted data
* processing metadata separately

---

## Parsing Rules

Deterministic extraction comes first.

Use:

* regex
* pattern matching
* domain-specific rules

AI extraction is fallback only.

Examples:

* DHL tracking codes
* order numbers
* shipment statuses
* carrier detection

Normalize all extracted values before persistence.

---

## Realtime Rules

Use Phoenix PubSub for:

* shipment updates
* parsing progress
* operational dashboards
* activity feeds

Dashboards should update live without refreshes.

---

## UI Philosophy

The UI should feel:

* operational
* dense but readable
* calm
* modern SaaS
* highly usable

Prioritize:

* tables
* timelines
* filters
* keyboard-friendly flows
* search-first workflows

Avoid:

* excessive animations
* flashy marketing UI
* frontend complexity
* unnecessary JavaScript

---

## Important UX Patterns

### Shipment Timeline

```txt
Ordered
→ Shipped
→ In Transit
→ Delivered
```

### Operational Dashboard

Should show:

* active shipments
* failed parsing
* delayed deliveries
* recent inbound emails
* shipment activity

### Email Debug View

Operators must be able to:

* inspect raw emails
* inspect parsing output
* retry parsing
* inspect extraction failures

---

## Coding Rules

Use:

* idiomatic Elixir
* pipelines
* pattern matching
* explicit function naming
* small focused modules

Avoid:

* giant god modules
* unnecessary abstractions
* deeply nested conditionals
* frontend-heavy architectures

---

## Folder Philosophy

Business logic:
```txt
/lib/rempost/
```

Web/UI layer:
```txt
/lib/rempost_web/
```

Jobs:
```txt
/lib/rempost/workers/
```

Contexts:
```txt
/lib/rempost/orders/
/lib/rempost/emails/
/lib/rempost/shipments/
```

---

## What This Product Is

This product is:

* an operational inbox intelligence platform
* an email-to-data pipeline
* a logistics/support operations tool
* a realtime shipment intelligence dashboard

It is NOT:

* Gmail clone
* consumer inbox app
* generic CRM
* frontend showcase project

---

## MVP Priorities

Build first:

1. inbound email ingestion
2. raw email persistence
3. parsing jobs
4. structured extraction
5. shipment dashboard
6. shipment timelines
7. realtime updates

Ignore initially:

* billing
* notifications
* enterprise auth complexity
* advanced AI orchestration
* overengineering

---

## Final Principle

The core value of the system is:

```txt
raw ecommerce email
→ structured operational intelligence
```

Everything in the architecture should support that transformation cleanly and reliably.