#!/usr/bin/env bash
set -euo pipefail

echo ""
echo "=================================================="
echo "REMPOST AI SKILLS CONTEXT"
echo "=================================================="
echo ""

cat <<'EOF'

# REMPOST

Rempost is a production-grade operational intelligence SaaS built with:

* Elixir
* Phoenix
* Phoenix LiveView
* PostgreSQL
* Ecto
* Oban
* Phoenix PubSub
* TailwindCSS

The system ingests forwarded ecommerce emails and transforms them into structured operational data.

This is NOT:

* an email client
* a CRM
* a marketing website

This IS:

* an email ingestion pipeline
* a shipment intelligence platform
* an operational dashboard system
* a realtime logistics workflow tool

==================================================
CORE SYSTEM FLOW
================

Incoming email
→ POST /api/inbound/email
→ persist raw email
→ enqueue Oban parsing job
→ parse deterministic patterns
→ extract structured entities
→ create/update orders + shipments
→ broadcast realtime updates
→ LiveView dashboards update automatically

==================================================
ARCHITECTURE RULES
==================

* Use Phoenix Contexts as the ONLY domain boundaries.
* Keep LiveViews thin.
* Keep Controllers thin.
* Business logic belongs inside contexts.
* Async work belongs in Oban workers.
* Use PubSub for realtime state synchronization.
* Avoid overengineering.
* Build production-quality architecture.
* Prefer explicitness over magic.
* Prefer composable modules over giant abstractions.

==================================================
DOMAIN MODEL
============

Core domains:

* Accounts
* Workspaces
* Emails
* Orders
* Shipments
* Tracking
* Parsing
* Customers

Core entities:

* Users
* Workspaces
* EmailSources
* InboundEmails
* Orders
* Shipments
* TrackingEvents
* ParsingJobs

==================================================
MULTI-TENANCY RULES
===================

* All tenant-owned data must include workspace_id.
* Never allow cross-workspace leakage.
* Scope queries properly.
* Build tenant isolation from the beginning.

==================================================
EMAIL PIPELINE RULES
====================

IMPORTANT:
Raw emails are the source of truth.

Always:

1. persist raw email first
2. enqueue async parsing
3. derive structured entities later

Never:

* parse inline during request lifecycle
* trust email formatting
* assume deterministic structures

==================================================
PARSING RULES
=============

Deterministic extraction comes first.

Use:

* regex
* pattern matching
* domain normalization

Examples:

* DHL tracking codes
* order numbers
* shipment statuses
* carrier extraction

AI extraction is FUTURE fallback logic only.

==================================================
OBAN RULES
==========

All heavy work must run in Oban jobs.

Examples:

* email parsing
* extraction
* retries
* reconciliation
* cleanup
* future AI enrichment

Jobs must be:

* idempotent
* retry-safe
* failure-aware

Failed parsing is a FIRST-CLASS operational state.

==================================================
LIVEVIEW RULES
==============

LiveViews:

* orchestrate UI
* handle events
* subscribe to realtime updates

LiveViews should NOT:

* contain business logic
* perform parsing
* contain persistence orchestration

Use:

* assigns
* handle_event
* PubSub subscriptions
* reusable components

==================================================
UI PHILOSOPHY
=============

The UI should feel:

* calm
* operational
* structured
* dense but readable
* modern SaaS
* highly usable

Prioritize:

* tables
* timelines
* filters
* search-first UX
* realtime updates

Avoid:

* flashy animation
* frontend complexity
* excessive JavaScript
* marketing-heavy UI patterns

==================================================
CODING RULES
============

Use:

* idiomatic Elixir
* pipelines
* pattern matching
* focused modules
* explicit naming
* proper changesets
* schema validation

Avoid:

* god modules
* hidden magic
* deep nesting
* unnecessary abstraction layers

==================================================
DATABASE RULES
==============

Use:

* indexes on searchable fields
* foreign key constraints
* explicit associations
* timestamps
* enums/status fields where appropriate

Store separately:

* raw email data
* structured extracted data
* processing metadata

==================================================
REALTIME RULES
==============

Use Phoenix PubSub for:

* shipment updates
* dashboard updates
* parsing progress
* operational feeds

Realtime operational visibility is core product value.

==================================================
MVP PRIORITIES
==============

Build first:

1. email ingestion
2. raw email persistence
3. parsing jobs
4. structured extraction
5. shipment dashboard
6. shipment timelines
7. realtime updates

Ignore initially:

* billing
* advanced auth complexity
* notifications
* AI orchestration
* microservices

==================================================
FINAL PRODUCT PRINCIPLE
=======================

The core value of Rempost is:

raw ecommerce email
→ structured operational intelligence

Everything in the architecture should support that transformation cleanly, reliably, and in realtime.

EOF

echo ""
echo "=================================================="
echo "REMPOST SKILLS CONTEXT LOADED"
echo "=================================================="
echo ""
