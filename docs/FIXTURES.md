# Parser Fixture Plan

How real forwarded ecommerce emails get turned into safe, committable test fixtures.

This doc defines the process and rules. It does not contain any sample email content. Real `.eml` exports stay under `example-mails/` and are git-ignored. Sanitized fixtures live under `test/fixtures/emails/` and are the only email-shaped data committed to the repo.

## Goals

- Cover the real Dutch ecommerce / shipment phrasing the parser must handle.
- Never commit personally identifying or order-identifying data.
- Make it obvious to a reviewer that a fixture is synthetic.

## Source Material

- Raw `.eml` exports live under `example-mails/` (git-ignored).
- One source `.eml` produces one sanitized fixture file.
- Never copy raw `.eml` content into the repo. Sanitize first.

## Fixture Layout

```
test/fixtures/emails/
  postnl_in_transit.eml
  postnl_delivered.eml
  dhl_in_transit.eml
  dhl_delivered.eml
  order_confirmation_xxl.eml
  shipped_generic.eml
```

Naming: `<carrier_or_shop>_<event>.eml`. Lowercase, snake_case. The filename is the test identifier.

Each fixture is a valid RFC 5322 message: headers, blank line, body. UTF-8.

## Redaction Rules

Replace every value below before committing. Use the listed placeholder pattern so fixtures stay searchable and consistent.

| Field | Real value | Replace with |
|---|---|---|
| Recipient name | "Jan Jansen" | `Test Recipient` |
| Recipient email | personal address | `recipient@example.test` |
| Sender display name | shop's real name | keep shop brand (it is public) |
| Sender email | real shop address | `noreply@<shop>.example` |
| Street address | real street + number | `Teststraat 1` |
| Postal code | real | `1000 AA` |
| City | real | `Amsterdam` (or `Rotterdam` if multiple) |
| Phone number | real | `+31 6 00000000` |
| Order number | real | `ORDER-0001`, `ORDER-0002`, … |
| Customer number | real | `CUST-0001` |
| Tracking number | real | synthetic but format-valid: `3SAAAA0000000`, `JVGL0000000000000000`, etc. |
| Tracking URL token | real token | replace token segment with `TESTTOKEN0001` |
| Invoice / receipt URLs | real | `https://example.test/invoice/0001` |
| Account URLs | real | `https://example.test/account` |
| Message-ID | real | `<fixture-0001@example.test>` |
| In-Reply-To / References | real | drop or use `<fixture-0001@example.test>` |
| DKIM / ARC / Received headers | real | drop, or replace hostnames with `example.test` |
| IP addresses | real | `203.0.113.1` (TEST-NET-3) |

Tracking numbers must keep the **carrier-recognisable format** (length, prefix). The parser depends on shape, not value. PostNL `3S…` and DHL `JVGL…` prefixes stay; only the digits change.

URLs must use a reserved test TLD (`.test`, `.example`) so no fixture URL ever resolves to a real host.

## Procedure

1. Drop the real `.eml` into `example-mails/`.
2. Copy it to `test/fixtures/emails/<name>.eml`.
3. Apply the redaction table above. Tools: editor find/replace, or a small `mix` task.
4. Open the sanitized file and grep it for:
   - the real recipient first name
   - the real street name
   - the real postal code
   - the real tracking number prefix's full real value
   - any `@` address that is not `*.example` or `*.test`
5. Strip large base64 attachments (logos, tracking pixels) unless the parser needs them. Replace with a single `[redacted-attachment]` line.
6. Add or update a test in `test/rempost/` that asserts the expected extracted fields for that fixture.

A fixture is only mergeable when every cell in the redaction table is satisfied.

## What Fixtures Must Preserve

- `From`, `Subject`, `Date`, `Content-Type` headers
- the Dutch phrasing that drives parsing ("is onderweg", "is bezorgd", "klaar voor verzending", "Track & Trace")
- the carrier link's host and path shape (`postnl.nl/tracktrace`, `dhlecommerce.nl/track`)
- HTML structure if the parser reads link `href` targets

## What Fixtures Must Strip

- real personal data
- real order, tracking, customer, invoice identifiers
- real authentication / unsubscribe / one-time-action tokens
- DKIM signatures, ARC seals, internal mail-server hostnames
- embedded images / large base64 blobs unless required by a test

## Review Checklist (per fixture PR)

- [ ] No name from the redaction table appears in the diff
- [ ] All URLs use `.test` or `.example`
- [ ] Tracking numbers match a carrier's shape but not a real shipment
- [ ] Message-ID is synthetic
- [ ] Subject + body still trigger the parser path the test claims
- [ ] A matching test exists and asserts extracted fields
