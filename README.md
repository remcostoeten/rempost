# Rempost

Rempost is an operational inbox intelligence app for ecommerce logistics emails.

## Current focus

MVP focus is intentionally narrow:

1. ingest forwarded emails (Cloudflare email pipeline)
2. store raw email
3. parse asynchronously
4. display emails in a searchable dashboard

## Inbound API

`POST /api/inbound/email`

Authentication:
- Header: `x-rempost-token: <token>` (recommended)
- or payload field: `token`
- token value configured by `config :rempost, :inbound_token`

Accepted payload fields (Cloudflare-friendly aliases supported):

- `message_id` or `id`
- `from_email` or `from`
- `subject`
- `raw_text` or `text` or `raw`
- `raw_html` or `html`
- `received_at` or `date` (ISO8601)
- `headers`

## Query API

- `GET /api/inbound/emails`
  - optional query params: `workspace_id`, `q`, `limit` (max 200)
  - requires same token auth as inbound POST (`x-rempost-token` or `token`)
  - returns recent inbound emails for debugging/search integrations

## Dashboard

- `/` or `/dashboard` for searchable inbound email feed
- `/emails/:id` for raw email debug + retry parsing

## Local development

```bash
mix deps.get
mix ecto.setup
mix phx.server
```


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


## Default workspace bootstrap

On boot, the app ensures the configured `workspace_id` exists by creating a `Default Workspace` record if needed.
