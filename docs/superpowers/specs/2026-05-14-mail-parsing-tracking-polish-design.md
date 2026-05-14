# Mail showcase, parsing, and track-and-trace polish

Date: 2026-05-14
Status: approved

## Goal

A focused polish pass across the email-debug surface, the deterministic parser, and the public shipment detail view. Make the mail showcase useful, make parsing precise enough that the synthesized links actually open carrier pages, and make the shipment detail screen graceful when tracking events are missing.

## Scope

### 1. Mail showcase upgrade — `/emails/:id`

The current page renders raw text in a `<pre>` with no header, no parsed fields, no clickable links, and no way back. Replace with:

- A shared `<.app_header />` at top with a "Back to dashboard" link.
- A **Parsed fields** card showing: carrier, tracking number, tracking URL, order number, customer name, postal code, status, plus a link to the matched shipment if one exists.
- An **HTML body** section: when `raw_html` is present, render it inside a sandboxed iframe (`sandbox="allow-same-origin"`, no scripts) via `srcdoc`. Fall back to raw text when html is absent.
- A **Raw text** section that auto-linkifies URLs and tracking numbers. Links open in a new tab with `rel="noreferrer noopener"`.

No new LiveView events; the `retry_parse` button stays.

### 2. Parser precision — `lib/rempost/parsing/deterministic_parser.ex`

- **Tracking URL allowlist.** Replace the broad `@tracking_url_regex` with a function that scans all URLs in the raw text and keeps only those whose host matches a known carrier domain (`dhl.com`, `dhlecommerce.nl`, `dhlecommerce.com`, `postnl.nl`, `parcel.dhl.com`, `track.dhlparcel.nl`, etc.). Drop tracking pixels (sendgrid, sendcloud bounce, mailgun, list-manage).
- **Synthesized URLs.** New helper `Rempost.Parsing.TrackingUrl.build/2` that, given carrier + tracking number, returns the public tracking URL:
  - `JVGL…` → `https://www.dhlecommerce.nl/track/JVGL…`
  - `3S…` → `https://jouw.postnl.nl/track-and-trace/<code>/NL/<postcode>` (postcode optional; without it, fall back to `https://postnl.nl/tracktrace/?B=<code>&P=&D=NL`).
- **Combine.** `parse/1` returns `tracking_url` preferring (a) allowlisted URL from email, (b) synthesized URL, (c) nil.
- **Order regex fix.** Loosen the punctuation gap so `Ordernummer: #1234567` and `Bestelnummer 1234567` both match; keep the invalid-token guard.

### 3. Track & trace view — `lib/rempost_web/live/shipment_live/show.html.heex`

- Format `event.occurred_at` with `Calendar.strftime` (currently dumps the raw struct).
- When `tracking_events` is empty, hide the events panel and instead render a **status timeline** (Besteld → Verzonden → Onderweg → Bezorgd) using the existing `timeline_steps/0` helper that's already defined in `index.ex` — move it to a small shared module `RempostWeb.ShipmentView` so both index and show can use it.
- The "Open carrier tracking" button continues to use `@shipment.tracking_url`, which after the parser change is the trusted synthesized/allowlisted URL.
- Add `<.app_header />` for consistency with dashboard.

### 4. Shared header — `lib/rempost_web/components/core_components.ex`

A tiny function component:

```elixir
attr :title, :string, default: "Postbus"
attr :badge, :string, default: nil
attr :back_to, :string, default: nil
attr :back_label, :string, default: "Terug"

def app_header(assigns)
```

Used by dashboard (no back link, badge="Admin"), email_debug (back to `/dashboard`), and shipment show (back to `/`). The existing inline headers are replaced one-for-one.

## Out of scope

- Auth / portal flows
- Master access UX
- Database migrations
- Refactoring `shipment_live/index.ex` (541 lines but working)

## Testing

- New unit tests in `test/rempost/parsing/deterministic_parser_test.exs`:
  - JVGL tracking number with no clean URL → DHL eCommerce URL synthesized.
  - 3S tracking number → PostNL URL synthesized.
  - Sendgrid pixel URL is rejected; DHL portal URL is kept.
  - `Ordernummer: #1234567` produces order_number `1234567`.
- LiveView test: `/emails/:id` renders parsed fields panel and linkified body.
- Existing tests stay green.

## Files touched

- `lib/rempost_web/components/core_components.ex` (new app_header)
- `lib/rempost_web/live/email_debug_live/show.html.heex` (rewrite)
- `lib/rempost_web/live/dashboard_live/index.html.heex` (use app_header)
- `lib/rempost_web/live/shipment_live/show.html.heex` (timeline fallback, app_header, format)
- `lib/rempost/parsing/deterministic_parser.ex` (tighten + synthesize)
- `lib/rempost/parsing/tracking_url.ex` (new)
- Tests under `test/rempost/parsing/` and `test/rempost_web/`
