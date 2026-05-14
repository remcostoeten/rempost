# Portal Entry Flow — Design

Status: approved (brainstorm), pending implementation plan
Date: 2026-05-14

## Goal

Reduce the public shipment-lookup portal to a single conversational step so friends ordering through the user's shared discount account can find their packages without typing exact names or postcodes.

## Context

- Rempost is single-tenant. The user owns the webshop account; friends order through it. Shipments carry the friend's own name + their own address.
- Friends are trusted; the portal URL is shared informally. Privacy from strangers is not a goal of this design (see `memory/project_portal_use_case.md`).
- The current flow is two strict steps: name (`identify`) then postcode/house number (`verify`), then results. The portal also has a session-scoped reveal gate (`REMPOST_PORTAL_ACCESS_ANSWER`) that hides tracking numbers until verified.
- The master-password back-door (`REMPOST_PORTAL_MASTER_PASSWORD`) is unrelated to this redesign and stays.

## Non-goals

- Multi-tenant or per-friend authentication.
- Free-text semantic search ("the protein I ordered last week").
- Changes to inbound ingestion, parsing, admin routes, or the master flow.
- Changes to the results-page rendering itself (only the data feeding it).

## User flow

```
/portal
  ┌────────────────────────────────────────┐
  │  Hé, wie ben je?                       │
  │  [ Begin met typen...           ]      │
  │    ↳ Anna van Dijk        (2 pakketten)│
  │    ↳ Annelies B.          (1 pakket)   │
  │    ↳ Anouk Janssen        (3 pakketten)│
  └────────────────────────────────────────┘
        │ pick suggestion  OR  Enter
        ▼
/portal?name=<name>        (deep-linkable)
  ┌────────────────────────────────────────┐
  │  Pakketten van Anna van Dijk           │
  │  · XXL Nutrition · Onderweg            │
  │  · DHL · Bezorgd                       │
  └────────────────────────────────────────┘
```

1. Single landing screen with a greeting and one text field.
2. Keyup ≥ 2 chars (debounced ~200 ms) → `phx-keyup` event `suggest` → server returns up to 8 matching recipients with shipment counts and latest-activity timestamps.
3. Click suggestion → results page (push_patch).
4. Enter / submit free text:
   - resolves to exactly 1 recipient → results page;
   - resolves to 0 → inline error "Geen pakketten gevonden — controleer de spelling";
   - resolves to >1 → stay on lookup, render the candidates inline as picks.
5. Results page renders all shipments for that recipient, no extra reveal step. Tracking numbers and carrier links are shown inline.

## Architecture

### New / changed modules

| module | change |
| --- | --- |
| `Rempost.Shipments` | add `suggest_recipients/2`, add `lookup_by_recipient/1`, delete `lookup_public_shipments/3` |
| `RempostWeb.ShipmentLive.Index` | collapse `:identify`/`:verify` into single `:lookup` step; remove postcode/house-number assigns; add `suggest`, `pick`, `submit` events |
| `RempostWeb.ShipmentLive.Index` template | replace two-step form with single field + suggestions dropdown |
| `RempostWeb.Router` | drop `POST /portal/verify`; keep `live "/portal"` |
| `RempostWeb.PortalAccessController` | delete |
| `Rempost.Access` | delete `portal_session_verified?/1` and related verification helpers; keep master helpers |

### `Shipments.suggest_recipients/2`

```elixir
@spec suggest_recipients(String.t(), pos_integer()) ::
        [%{name: String.t(), shipment_count: non_neg_integer(), latest_activity_at: DateTime.t() | nil}]
```

- Trims and downcases the query; folds accents via `unaccent`.
- Returns `[]` for queries shorter than 2 trimmed characters.
- Substring match against `customer_name` (so "anna" finds "Anna van Dijk" and "van Dijk").
- Groups by `customer_name`, orders by `latest_activity_at DESC NULLS LAST`.
- Default limit 8.

### `Shipments.lookup_by_recipient/1`

```elixir
@spec lookup_by_recipient(String.t()) :: [Shipment.t()]
```

- Same accent / case folding as `suggest_recipients`.
- Returns all shipments whose `customer_name` matches the (single) name exactly after folding — i.e. once the user has picked or typed a complete name. Used after suggestion-resolution.

### SQL

Needs the `unaccent` extension. Add migration `enable_unaccent_extension`:

```sql
CREATE EXTENSION IF NOT EXISTS unaccent;
```

Suggest query shape:

```sql
SELECT customer_name,
       COUNT(*)            AS shipment_count,
       MAX(latest_event_at) AS latest_activity_at
FROM shipments  -- joined with orders if customer_name lives on orders
WHERE unaccent(lower(customer_name)) LIKE '%' || unaccent(lower($1)) || '%'
GROUP BY customer_name
ORDER BY latest_activity_at DESC NULLS LAST
LIMIT $2;
```

(Implementation may live entirely in Ecto with `fragment("unaccent(lower(?))", ...)`.)

### LiveView state

| assign | type |
| --- | --- |
| `:step` | `:lookup` \| `:results` |
| `:query` | `String.t()` (current input) |
| `:suggestions` | `[%{name, shipment_count, latest_activity_at}]` |
| `:candidates` | `[String.t()]` (multi-match disambiguator after submit) |
| `:lookup_name` | `String.t()` (resolved recipient on results page) |
| `:lookup_error` | `String.t() | nil` |
| `:shipments` | `[Shipment.t()]` |
| `:selected_shipment_id` | `integer() | nil` |
| `:master_access?` | `boolean()` (untouched) |

### Events

- `suggest %{"q" => q}` → updates `:suggestions`.
- `pick %{"name" => name}` → resolves directly, push_patch `/portal?name=<name>`, loads results.
- `submit %{"lookup" => %{"name" => name}}` → resolves: if exactly one match, push_patch to results; if multiple, populate `:candidates`; if zero, set `:lookup_error`.
- `clear` / "edit lookup" → back to `:lookup` with empty state.
- `master_access` → unchanged.

### Routes

- `live "/portal", ShipmentLive.Index, :index` — unchanged path, new content.
- `live "/", ShipmentLive.Index, :index` — unchanged.
- `live "/shipments", ShipmentLive.Index, :index` — unchanged alias.
- `live "/shipments/:id", ShipmentLive.Show, :show` — unchanged (deep-linkable individual shipment).
- `POST /portal/verify` — deleted.

## Error handling

| condition | behaviour |
| --- | --- |
| query < 2 chars | no dropdown, no error |
| no suggestions for ≥ 2 chars | dropdown shows "Geen suggesties" (subtle) |
| submit with no match | inline error under the field; field keeps value so friend can edit |
| submit matches > 1 recipient | render candidates as clickable picks; clicking resolves |
| direct URL `/portal?name=Unknown` | landing page renders results with empty list + same "geen pakketten" message |
| DB error during suggest | log + return `[]`; UI shows no dropdown rather than failing |

## Testing

### Unit (`Rempost.Shipments`)

- `suggest_recipients/2`: prefix match; substring match; accent fold ("jose" finds "José"); short query returns `[]`; limit honoured; ordering by latest activity.
- `lookup_by_recipient/1`: exact match; case-insensitive; accent-fold; no-match returns `[]`.

### LiveView (`RempostWeb.ShipmentLiveTest`)

- Typing 2+ chars renders suggestions.
- Clicking a suggestion navigates to `?name=<name>` and renders shipments.
- Submitting a name that uniquely resolves navigates to results.
- Submitting a name with multiple matches renders candidates.
- Submitting an unknown name renders the inline error.
- Master password flow still works.

### Migration

- `enable_unaccent_extension` runs cleanly on a fresh DB and is idempotent (`IF NOT EXISTS`).

## Migration of existing URLs

Any inbound link still pointing at `?step=identify` / `?step=verify` should land on the new `:lookup` step. Implementation: `handle_params` ignores unknown `step` values and defaults to `:lookup`.

## Out-of-scope follow-ups

- "Recent shipments" landing block (variant B from brainstorming) — possible later.
- Per-friend bookmark URLs / QR codes.
- Email notifications when a friend's tracking status changes.
