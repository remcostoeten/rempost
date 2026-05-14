# Manual QA Script

End-to-end acceptance test for the Rempost MVP. Run before sharing the portal with anyone outside the operator.

Time budget: ~15 minutes on a clean dev database.

## Setup

- Postgres running and reachable.
- `mix ecto.reset` to start from a clean schema.
- Set `REMPOST_PORTAL_ACCESS_ANSWER` to a known test value (e.g. `qatest`).
- Run `mix phx.server`.
- Have one sanitized fixture payload ready. If using local raw examples from `example-mails/`, sanitize before committing anything derived from them.

## 1. Inbound email accepted

- POST a sanitized fixture payload to `/api/inbound/email` (curl or a `mix` task).
- Expect HTTP 202.
- Expect the email to appear immediately in `/dashboard` without manual refresh.

Pass when the new row shows up in the admin dashboard with status `pending` or `processing`.

## 2. Async parse job runs

- Within a few seconds, dashboard row status flips through `processing` and ends at `parsed` or `failed`.
- The Oban dashboard at `/oban` shows the parse job for that email.

Pass when status reaches `parsed` for a fixture known to contain a tracking number.

## 3. Portal updates live

- Open `/portal` (the public shipment lookup) in a second browser window.
- Re-send a fixture POST.
- Expect the new shipment row to appear in `/portal` without manual refresh.

Pass when the LiveView updates without an F5.

## 4. Tracking is hidden before verification

- In `/portal`, locate the new shipment row.
- The "Track and trace" column shows a masked suffix (`**** ABCD`), not the full number.
- The shipment detail page header reads "Tracking hidden".
- No `tracking_url` value is rendered anywhere in the DOM.

Pass when no full tracking number and no carrier URL is visible to an unverified visitor. View source if in doubt.

## 5. Correct answer reveals tracking

- Submit the configured `REMPOST_PORTAL_ACCESS_ANSWER`.
- After redirect, the same row shows the full tracking number and an "Open carrier tracking" link.
- Reload the page. Tracking is still visible (session-persisted).
- The "Open carrier tracking" link target host matches the fixture's carrier.

Pass when verification survives a refresh and the carrier link resolves to the expected host.

## 6. Wrong answer fails closed

- Open a private/incognito window.
- Submit a wrong answer.
- Expect the error: "That answer didn't match. Try again."
- Tracking remains hidden. Verified state does not appear.

Pass when no tracking data leaks and the error message is shown.

## 7. Admin raw email inspection

- In `/dashboard`, click the new email.
- The raw email debug view renders headers, text body, and HTML body.
- Status, message ID, and parse error (if any) are visible.

Pass when the operator can read the raw email content for debugging.

## 8. Admin retry parsing

- Pick an email whose parse failed (or force a failure with a malformed fixture).
- Click the retry action.
- Expect a new Oban job and updated status.

Pass when retry triggers a fresh parse and the dashboard reflects the outcome.

## 9. Admin routes refuse unauthenticated visitors

- Open a private window with no admin session.
- Try each route: `/dashboard`, `/emails/<known-id>`, `/oban`, `POST /api/inbound/email` without the expected secret.
- Each should return 401/403 or redirect to a login flow.

Pass when none of the admin surfaces leak data.

## 10. Production-config sanity

- Stop the server. Unset `REMPOST_PORTAL_ACCESS_ANSWER`.
- Start with `MIX_ENV=prod` (or run the release).
- Expect the boot to fail closed (raise) or, at minimum, the verify endpoint to refuse every answer.
- Never fall back to a hardcoded default in production.

Pass when missing config does not silently allow access.

## Sign-off

A QA run is green only when steps 1–10 pass in a single session against the same build. File a release note with the build SHA and the date of the run.
