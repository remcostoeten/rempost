# Rempost Threat Model (Draft)

Scope: the MVP described in [docs/PRD.md](PRD.md). Updated each milestone.

## Assets

In rough order of sensitivity.

1. **Raw forwarded emails.** Contain full names, postal addresses, order history, account links, sometimes account-recovery one-time tokens. Stored canonically; never displayed to public users.
2. **Tracking numbers and tracking URLs.** Once known, a tracking URL is a public deep-link into a real shipment. Anyone with the URL can see the delivery address and status on the carrier site.
3. **Order metadata.** Order numbers, shop names, broad status. Less sensitive in isolation but correlatable with the owner's identity.
4. **Portal access answer.** A single shared secret guarding tracking reveal. Loss = full tracking exposure for everyone with a portal URL.
5. **Admin session.** Grants raw-email read, parser retry, and Oban job control. Loss = full mailbox-grade exposure plus operational impact.
6. **Cloudflare → Rempost ingestion secret.** Lets any holder inject arbitrary parsed "emails".

## Trust Boundaries

- Internet → Cloudflare Email Routing.
- Cloudflare Worker → Rempost `POST /api/inbound/email` (shared secret).
- Public visitor → Rempost portal (unauthenticated, then session-verified after shared-answer).
- Operator → Rempost admin surfaces (admin Basic Auth).
- Rempost → Postgres (trusted internal network).

## Public Routes vs Protected Routes

| Route | Audience | Must not leak |
|---|---|---|
| `/portal` | Public | full tracking number, tracking URL, raw email content, sender email if it identifies a private person |
| `/shipments/:id` | Public, unverified | same as `/portal` |
| `/shipments/:id` | Public, verified | raw email content, admin operations |
| `/dashboard` | Admin only | everything to the public |
| `/emails/:id` | Admin only | everything to the public |
| `/oban` | Admin only | everything to the public |
| `POST /api/inbound/email` | Cloudflare only | accept-anything from unauthenticated callers |

## Threats

### T1 — Public user reads raw email content

**Vector.** Direct request to `/emails/:id`, scraping JSON-encoded LiveView assigns, or guessing an admin route.
**Impact.** Mailbox-grade data exposure.
**Mitigations.** Admin auth sits in front of every admin route. LiveView assigns for the portal must contain only the public projection of a shipment, never the raw email record.

### T2 — Public user bypasses verification

**Vector.** Direct page state manipulation, replaying another visitor's session cookie, or visiting `/shipments/:id` and reading hidden DOM nodes.
**Impact.** Full tracking number + URL leak.
**Mitigations.** Verification state lives server-side in the session (not in client-controlled state). Templates never render hidden `tracking_url`. Tests assert no full tracking number or URL appears in unverified responses.

### T3 — Shared portal-access answer is guessed or leaked

**Vector.** Trivial answer, brute force, or social spread among acquaintances.
**Impact.** Anyone reaching the portal and supplying the answer sees all tracking for every order.
**Mitigations.**
- Treat this as low-assurance access control suitable only for a small known audience.
- Rate-limit failed verify attempts per IP and per session.
- Make the configured answer non-trivial and non-guessable from public facts.
- Expire the verified session after a short TTL.
- Plan M-later upgrade to per-order questions or stronger auth.
- Document the model honestly to anyone the URL is shared with.

### T4 — Missing portal-access env var allows access

**Vector.** Operator deploys without setting `REMPOST_PORTAL_ACCESS_ANSWER`. Code falls back to a default and accepts anyone.
**Impact.** Verification becomes a no-op in production.
**Mitigations.** M1 makes production fail closed: missing config raises on boot, and the verify handler refuses every answer when the configured value is empty.

### T5 — Admin surfaces unprotected

**Vector.** Routes documented in PRD; trivially fetchable.
**Impact.** See T1; plus retry / Oban manipulation lets an attacker re-fire jobs or amplify load.
**Mitigations.** Admin auth is required before public sharing. Hard requirement, not a polish task.

### T6 — Forged inbound emails

**Vector.** An attacker POSTs to `/api/inbound/email` with crafted payloads — either to plant fake shipments, exhaust storage, or smuggle stored-XSS payloads into the admin view.
**Impact.** Database pollution, parser DoS, possible admin-session XSS.
**Mitigations.**
- Require a shared secret on `POST /api/inbound/email`, validated before any DB write.
- Limit body size at the endpoint.
- Treat all raw fields as untrusted strings: never render raw HTML body unsanitized; escape every field in both portal and admin views.
- Dedupe by message ID to blunt bulk replay.

### T7 — Parser confusion creates fake shipments

**Vector.** Email content engineered to make the parser extract a wrong tracking number, or any tracking number at all where there is none.
**Impact.** Misleading shipment shown to public users; possible link to attacker-controlled URL if a tracking URL is extracted from a malicious `href`.
**Mitigations.**
- Deterministic parser refuses to invent tracking numbers; PRD requires this.
- Tracking URL extraction must restrict to a whitelist of known carrier hosts; never render an arbitrary `href` as "Open carrier tracking".
- Failed/uncertain extractions surface to admin instead of producing a public-visible shipment.

### T8 — Session fixation / open redirect after verify

**Vector.** Verify endpoint accepts arbitrary `return_to` and redirects, or session token is reused across users.
**Impact.** Phishing pivot or session leakage.
**Mitigations.** `safe_return_to` already restricts to same-origin paths starting with `/` and rejecting `//`. Keep that. Rotate the session ID on successful verification.

### T9 — Log / error-message leakage

**Vector.** Application logs include raw email bodies, tracking URLs, or the configured access answer.
**Impact.** Sensitive data ends up in disk logs, third-party log sinks, or stack traces.
**Mitigations.** Audit Logger calls; never log full bodies or tracking URLs at `info`. Never log the access answer or env var value.

## Public-User Rule of Thumb

A public user must never see:

- raw email headers, text, or HTML
- full tracking numbers (before verification)
- tracking URLs (before verification)
- sender email addresses that identify a private person
- parser errors or stack traces
- internal IDs that allow enumeration (prefer non-sequential identifiers in URLs)

Anything else may be public-shaped (order number, shop name, broad status, masked tracking suffix).

## Operating Assumptions

- The portal URL is shared with a small, known audience.
- The deployment is single-tenant; no cross-tenant isolation is required.
- TLS is terminated at the edge; in-cluster traffic is trusted.
- Backups inherit the sensitivity of the production database and need the same controls.

## Open Questions

- Should raw emails have a retention TTL by default? (M4 covers configurable retention.)
- Is logging of `received_at` + `from_email` to standard logs acceptable, or also redact?
- How should we revoke a leaked shared answer fast? (Today: rotate env var + redeploy.)
