# Rempost

Rempost is a self-service shipment lookup backed by an operational ecommerce
email ingestion pipeline.

## Current focus

MVP focus is intentionally narrow:

1. ingest forwarded emails (Cloudflare Email Routing)
2. store raw email before parsing
3. parse asynchronously through Oban
4. derive orders, shipments, and tracking events
5. expose public shipment lookup separately from admin debugging surfaces

## Inbound API

`POST /api/inbound/email`

Authentication:
- Header: `x-rempost-token: <token>` (recommended)
- or payload field: `token`
- token value configured by `REMPOST_INBOUND_TOKEN`

Accepted payload fields (Cloudflare-friendly aliases supported):

- `message_id` or `id`
- `from_email` or `from`
- `subject`
- `raw_text` or `text` or `raw`
- `raw_html` or `html`
- `received_at` or `date` (ISO8601)
- `headers`

## Admin Query API

- `GET /api/inbound/emails`
  - optional query params: `q`, `limit` (max 200)
  - requires admin Basic Auth
  - returns recent inbound emails for debugging/search integrations

## Routes

Public:

- `/` and `/portal` for self-service shipment search
- `/shipments` for the same shipment search surface
- `/shipments/:id` for shipment timeline/details with tracking data hidden until verification
- `POST /api/inbound/email` for Cloudflare inbound delivery, protected by inbound token

Admin:

- `/dashboard` for inbound email/search operations
- `/emails/:id` for raw email debug and parser retry
- `/oban` for Oban job visibility
- `GET /api/inbound/emails` for admin email search integrations

Admin surfaces require Basic Auth. Public shipment routes never expose raw email
content, and full tracking numbers/links are revealed only after the configured
portal answer is verified for the browser session.

## Environment

Required before sharing outside localhost:

| variable | purpose |
| --- | --- |
| `REMPOST_INBOUND_TOKEN` | bearer-style shared token for `POST /api/inbound/email` |
| `REMPOST_ADMIN_USER` | Basic Auth username for admin routes |
| `REMPOST_ADMIN_PASSWORD` | Basic Auth password for admin routes |
| `REMPOST_PORTAL_ACCESS_ANSWER` | shared answer for revealing public tracking details |

Optional:

| variable | default | purpose |
| --- | --- | --- |
| `REMPOST_PORTAL_VERIFICATION_TTL_SECONDS` | `3600` | browser-session verification TTL |
| `DATABASE_URL` | required in prod | Postgres connection URL |
| `POOL_SIZE` | `10` | Ecto connection pool size |

Production requires inbound/admin secrets at boot. If admin credentials are
missing at runtime, admin routes fail closed with `503`. If the portal access
answer is missing, tracking reveal fails closed.

## Local database drift

This app is intentionally single-tenant. The old workspace migration was deleted
and should not be reintroduced for local drift. If a local development database
still has the deleted workspace migration recorded or contains obsolete
workspace tables, reset the local dev database:

```bash
mix ecto.reset
```

For production-like data, inspect `schema_migrations` and apply a narrow cleanup
only after backing up the database.

## Local development

```bash
mix deps.get
mix ecto.setup
mix phx.server
```

### `bin/dev` — interactive TUI

A small fuzzy-searchable wrapper around the most common `mix` and Docker
commands. Run it from anywhere inside the repo:

```bash
./bin/dev
```

Requires `bash`, [`fzf`](https://github.com/junegunn/fzf), and `mix`. Optional:
`docker` / `docker compose`, `xdg-open` (Linux) or `open` (macOS) for opening
URLs.

Inside the menu:

- type any keyword to fuzzy-filter actions
- `↑` / `↓` to navigate, `Enter` to run, `Esc` to quit
- the header shows whether the Phoenix server is up and on which port

Available actions:

| action                     | what it does                                                                 |
| -------------------------- | ---------------------------------------------------------------------------- |
| **Start server**           | runs `mix phx.server` in the background (logs in `tmp/dev_server.log`)       |
| **Stop server**            | stops the background Phoenix server                                          |
| **Restart server**         | stop + start                                                                 |
| **Restart dev --fully**    | `ecto.drop` → `ecto.create` → `ecto.migrate` → start server (asks first)     |
| **Server controls** *      | shown when the server is up: `o` open browser · `r` restart · `l` tail logs · `q` back |
| **Start Docker**           | `docker compose up -d` (falls back to `docker-compose`)                      |
| **Dependencies…**          | check outdated · install · add new · detect & remove unused                  |
| **Database…**              | status · migrate · clear · reset                                             |

Destructive actions (drop/reset, removing deps) always prompt for confirmation.


## Cloudflare Email Worker setup

A starter worker is included in `cloudflare/`.

1. `cd cloudflare && npm install`
2. Copy `wrangler.toml.example` to `wrangler.toml`
3. Set your API URL in `REMPOST_INBOUND_URL`
4. Set secret token:
   - `wrangler secret put REMPOST_INBOUND_TOKEN`
5. Deploy:
   - `wrangler deploy`

The worker receives inbound email, parses with `postal-mime`, and posts normalized JSON to `/api/inbound/email`.
