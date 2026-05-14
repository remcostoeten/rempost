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


## Default workspace bootstrap

On boot, the app ensures the configured `workspace_id` exists by creating a `Default Workspace` record if needed.
