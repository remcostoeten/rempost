# Portal Entry Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the two-step name+postcode portal lookup with a single autocomplete-driven recipient picker, and remove the reveal gate so friends see tracking inline immediately.

**Architecture:** New `Rempost.Shipments.suggest_recipients/2` powers a `phx-keyup` autocomplete in `RempostWeb.ShipmentLive.Index`. New `Rempost.Shipments.lookup_by_recipient/1` replaces `lookup_public_shipments/3`. The `:identify`/`:verify` LiveView steps collapse into one `:lookup` step; the `PortalAccessController` reveal gate and related `Rempost.Access` helpers are deleted. Master password flow stays intact.

**Tech Stack:** Elixir, Phoenix LiveView, Ecto, PostgreSQL (with `unaccent` extension), Tailwind.

**Spec:** `docs/superpowers/specs/2026-05-14-portal-entry-flow-design.md`

---

## File Structure

**Create:**
- `priv/repo/migrations/20260514200000_enable_unaccent_extension.exs`

**Modify:**
- `lib/rempost/shipments.ex` — add `suggest_recipients/2` and `lookup_by_recipient/1`; remove `lookup_public_shipments/3` and helpers it alone used (`verified_customer_names/2`, `public_address_match/3`, `address_dynamic/3`, `public_shipment_scope/1`, `split_address/1`, `normalize_postal_code/1`, `normalize_house_number/1`, `normalized_tracking_number/1`).
- `lib/rempost/access.ex` — delete `portal_verified?/1`, `portal_session_verified?/2`, `portal_session_key/0`, `portal_verified_until/1`, `portal_verification_ttl_seconds/0`, and the `portal_answer/0` private. Keep all master-* functions and helpers they use.
- `lib/rempost_web/router.ex` — delete the `post "/portal/verify"` route.
- `lib/rempost_web/live/shipment_live/index.ex` — full rewrite of state, params, events. Single `:lookup` and `:results` step. Add `suggest`, `pick`, `submit`, drop everything `identify`/`verify`/`switch_verification_mode`/`back_to_verify`.
- `lib/rempost_web/live/shipment_live/index.html.heex` — replace the two-step form with single autocomplete field + suggestions dropdown; keep results layout.
- `test/rempost/shipments_test.exs` — replace the `lookup_public_shipments` tests with `suggest_recipients` + `lookup_by_recipient` tests.
- `test/rempost_web/shipment_live_index_test.exs` — replace the two-step LiveView test with a single-step autocomplete test.

**Delete:**
- `lib/rempost_web/controllers/portal_access_controller.ex`
- `test/rempost/access_test.exs` — review and prune tests for deleted helpers; keep master tests.

---

## Task 1: Add `unaccent` extension migration

**Files:**
- Create: `priv/repo/migrations/20260514200000_enable_unaccent_extension.exs`

- [ ] **Step 1: Write the migration**

```elixir
defmodule Rempost.Repo.Migrations.EnableUnaccentExtension do
  use Ecto.Migration

  def up do
    execute("CREATE EXTENSION IF NOT EXISTS unaccent")
  end

  def down do
    execute("DROP EXTENSION IF EXISTS unaccent")
  end
end
```

- [ ] **Step 2: Run the migration on dev**

Run: `mix ecto.migrate`
Expected: `[info] == Running 20260514200000 Rempost.Repo.Migrations.EnableUnaccentExtension.up/0`

- [ ] **Step 3: Verify the extension is enabled**

Run: `mix ecto.dump`, then check `priv/repo/structure.sql` (or `psql -c "SELECT extname FROM pg_extension WHERE extname = 'unaccent'"`).
Expected: `unaccent` listed.

- [ ] **Step 4: Commit**

```bash
git add priv/repo/migrations/20260514200000_enable_unaccent_extension.exs
git commit -m "feat: enable unaccent extension for portal recipient search"
```

---

## Task 2: Implement `Shipments.suggest_recipients/2`

`customer_name` lives on `Rempost.Orders.Order`. Suggestions group across orders, joining with shipments so recipients with zero shipments aren't suggested.

**Files:**
- Modify: `lib/rempost/shipments.ex`
- Test: `test/rempost/shipments_test.exs`

- [ ] **Step 1: Add failing tests**

Append to `test/rempost/shipments_test.exs` (use the same `insert_order!` / `insert_shipment!` helpers already used in this file):

```elixir
describe "suggest_recipients/2" do
  test "returns recipients matching a prefix, case- and accent-insensitive" do
    anna = insert_order!("ORD-S-1", "XXL Nutrition", %{customer_name: "Anna van Dijk"})
    insert_shipment!(anna, "JVGL000000000000000001", "dhl", :in_transit)

    jose = insert_order!("ORD-S-2", "XXL Nutrition", %{customer_name: "José Martínez"})
    insert_shipment!(jose, "JVGL000000000000000002", "dhl", :in_transit)

    assert [%{name: "Anna van Dijk", shipment_count: 1}] =
             Shipments.suggest_recipients("anna")

    assert [%{name: "José Martínez"}] = Shipments.suggest_recipients("jose")
  end

  test "matches substrings, not just prefixes" do
    order = insert_order!("ORD-S-3", "XXL Nutrition", %{customer_name: "Anna van Dijk"})
    insert_shipment!(order, "JVGL000000000000000003", "dhl", :in_transit)

    assert [%{name: "Anna van Dijk"}] = Shipments.suggest_recipients("dijk")
  end

  test "returns [] for queries shorter than 2 trimmed characters" do
    order = insert_order!("ORD-S-4", "XXL Nutrition", %{customer_name: "Anna van Dijk"})
    insert_shipment!(order, "JVGL000000000000000004", "dhl", :in_transit)

    assert [] = Shipments.suggest_recipients("")
    assert [] = Shipments.suggest_recipients(" ")
    assert [] = Shipments.suggest_recipients("a")
  end

  test "groups by name and counts shipments" do
    order = insert_order!("ORD-S-5", "XXL Nutrition", %{customer_name: "Tom Bakker"})
    insert_shipment!(order, "JVGL000000000000000005", "dhl", :in_transit)
    insert_shipment!(order, "JVGL000000000000000006", "dhl", :shipped)

    assert [%{name: "Tom Bakker", shipment_count: 2}] = Shipments.suggest_recipients("tom")
  end

  test "honours the limit" do
    for i <- 1..10 do
      order =
        insert_order!("ORD-S-LIM-#{i}", "XXL Nutrition", %{
          customer_name: "Recipient #{i}"
        })

      insert_shipment!(order, "JVGL00000000000000LIM#{i}", "dhl", :in_transit)
    end

    assert length(Shipments.suggest_recipients("recipient", 3)) == 3
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/rempost/shipments_test.exs --only describe:"suggest_recipients/2"`
Expected: FAIL (function does not exist).

- [ ] **Step 3: Implement the function**

Add to `lib/rempost/shipments.ex` (anywhere in the public section, alongside `list_shipments/1`):

```elixir
@suggest_default_limit 8

def suggest_recipients(query, limit \\ @suggest_default_limit) do
  trimmed = query |> to_string() |> String.trim()

  if String.length(trimmed) < 2 do
    []
  else
    folded = String.downcase(trimmed)

    Shipment
    |> join(:inner, [s], o in assoc(s, :order))
    |> where(
      [_s, o],
      fragment("unaccent(lower(?)) LIKE '%' || unaccent(?) || '%'", o.customer_name, ^folded)
    )
    |> where([_s, o], not is_nil(o.customer_name) and o.customer_name != "")
    |> group_by([_s, o], o.customer_name)
    |> select([s, o], %{
      name: o.customer_name,
      shipment_count: count(s.id),
      latest_activity_at: max(s.updated_at)
    })
    |> order_by([s, _o], desc: max(s.updated_at))
    |> limit(^limit)
    |> Repo.all()
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/rempost/shipments_test.exs --only describe:"suggest_recipients/2"`
Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/rempost/shipments.ex test/rempost/shipments_test.exs
git commit -m "feat: add Shipments.suggest_recipients for portal autocomplete"
```

---

## Task 3: Implement `Shipments.lookup_by_recipient/1`

This replaces `lookup_public_shipments/3` with a name-only lookup.

**Files:**
- Modify: `lib/rempost/shipments.ex`
- Test: `test/rempost/shipments_test.exs`

- [ ] **Step 1: Add failing tests**

Append to `test/rempost/shipments_test.exs`:

```elixir
describe "lookup_by_recipient/1" do
  test "returns shipments whose order customer_name matches exactly (case and accent insensitive)" do
    iduna =
      insert_order!("ORD-L-1", "XXL Nutrition", %{customer_name: "Iduna Bink"})

    shipment = insert_shipment!(iduna, "JVGL00000000000000L001", "dhl", :in_transit)

    other =
      insert_order!("ORD-L-2", "XXL Nutrition", %{customer_name: "Jane van Dijk"})

    insert_shipment!(other, "JVGL00000000000000L002", "dhl", :in_transit)

    assert [match] = Shipments.lookup_by_recipient("iduna bink")
    assert match.id == shipment.id

    assert [match] = Shipments.lookup_by_recipient("IDUNA BINK")
    assert match.id == shipment.id
  end

  test "folds accents on both sides" do
    order = insert_order!("ORD-L-3", "XXL Nutrition", %{customer_name: "José Martínez"})
    shipment = insert_shipment!(order, "JVGL00000000000000L003", "dhl", :in_transit)

    assert [match] = Shipments.lookup_by_recipient("jose martinez")
    assert match.id == shipment.id
  end

  test "returns [] for an unknown name" do
    order = insert_order!("ORD-L-4", "XXL Nutrition", %{customer_name: "Iduna Bink"})
    insert_shipment!(order, "JVGL00000000000000L004", "dhl", :in_transit)

    assert [] = Shipments.lookup_by_recipient("nobody")
    assert [] = Shipments.lookup_by_recipient("")
    assert [] = Shipments.lookup_by_recipient(nil)
  end

  test "returns all shipments for a recipient with multiple orders" do
    order_a = insert_order!("ORD-L-5", "XXL Nutrition", %{customer_name: "Tom Bakker"})
    shipment_a = insert_shipment!(order_a, "JVGL00000000000000L005", "dhl", :in_transit)

    order_b = insert_order!("ORD-L-6", "XXL Nutrition", %{customer_name: "Tom Bakker"})
    shipment_b = insert_shipment!(order_b, "JVGL00000000000000L006", "dhl", :shipped)

    ids = Shipments.lookup_by_recipient("tom bakker") |> Enum.map(& &1.id) |> Enum.sort()
    assert ids == Enum.sort([shipment_a.id, shipment_b.id])
  end

  test "preloads the order" do
    order = insert_order!("ORD-L-7", "XXL Nutrition", %{customer_name: "Anna van Dijk"})
    insert_shipment!(order, "JVGL00000000000000L007", "dhl", :in_transit)

    [match] = Shipments.lookup_by_recipient("anna van dijk")
    assert %Rempost.Orders.Order{order_number: "ORD-L-7"} = match.order
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/rempost/shipments_test.exs --only describe:"lookup_by_recipient/1"`
Expected: FAIL (function does not exist).

- [ ] **Step 3: Implement the function**

Add to `lib/rempost/shipments.ex`:

```elixir
def lookup_by_recipient(name) when is_binary(name) do
  trimmed = String.trim(name)

  if trimmed == "" do
    []
  else
    folded = String.downcase(trimmed)

    Shipment
    |> join(:inner, [s], o in assoc(s, :order))
    |> where(
      [_s, o],
      fragment("unaccent(lower(?)) = unaccent(?)", o.customer_name, ^folded)
    )
    |> order_by([s], desc: s.updated_at)
    |> preload([_s, o], order: o)
    |> Repo.all()
  end
end

def lookup_by_recipient(_), do: []
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/rempost/shipments_test.exs --only describe:"lookup_by_recipient/1"`
Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/rempost/shipments.ex test/rempost/shipments_test.exs
git commit -m "feat: add Shipments.lookup_by_recipient for portal name-only lookup"
```

---

## Task 4: Remove `lookup_public_shipments/3` and its dead helpers

**Files:**
- Modify: `lib/rempost/shipments.ex`
- Modify: `test/rempost/shipments_test.exs`

- [ ] **Step 1: Delete the old tests for `lookup_public_shipments`**

Open `test/rempost/shipments_test.exs` and remove every `test "..."` block that calls `Shipments.lookup_public_shipments(`. There are several. Leave the new `describe` blocks from Tasks 2 and 3 untouched. Leave the other tests (`search_shipments`, `list_shipments`) alone.

- [ ] **Step 2: Delete the old function and its private helpers from the module**

Open `lib/rempost/shipments.ex` and remove these definitions in full:

- `def lookup_public_shipments(name, mode, value, limit \\ 25)`
- `defp verified_customer_names(term, address_dynamic)`
- `defp normalized_tracking_number(...)`
- `defp public_address_match(mode, value, binding)`
- All three `defp address_dynamic(...)` clauses
- `defp public_shipment_scope(address_dynamic)`
- `defp split_address(value)`
- `defp normalize_postal_code(value)`
- `defp normalize_house_number(value)`

Keep: `normalize_text/1` (still used by other code paths — verify with `grep -n normalize_text lib/rempost/shipments.ex` before deleting; if no other callers remain inside the file, delete it too).

- [ ] **Step 3: Run the full Shipments test suite**

Run: `mix test test/rempost/shipments_test.exs`
Expected: PASS. No compile warnings about unused private functions.

- [ ] **Step 4: Run the compiler with warnings as errors**

Run: `mix compile --warnings-as-errors`
Expected: clean compile.

- [ ] **Step 5: Commit**

```bash
git add lib/rempost/shipments.ex test/rempost/shipments_test.exs
git commit -m "refactor: drop lookup_public_shipments in favour of recipient-name lookup"
```

---

## Task 5: Simplify `Rempost.Access` and delete the reveal gate

**Files:**
- Modify: `lib/rempost/access.ex`
- Modify: `test/rempost/access_test.exs`

- [ ] **Step 1: Delete reveal-gate access tests**

Open `test/rempost/access_test.exs` and remove every test that exercises `portal_verified?/1`, `portal_session_verified?/2`, `portal_verified_until/0`, or `portal_verification_ttl_seconds/0`. Keep tests for `portal_master_verified?/1` and `portal_master_session_verified?/2`.

- [ ] **Step 2: Run the Access tests to confirm the remaining ones pass**

Run: `mix test test/rempost/access_test.exs`
Expected: PASS (only master tests remain).

- [ ] **Step 3: Delete the reveal-gate code from `lib/rempost/access.ex`**

Remove these definitions from `lib/rempost/access.ex`:

- `@portal_session_key "portal_verified_until"` module attribute
- `@default_portal_ttl_seconds 60 * 60` module attribute
- `def portal_session_key/0`
- `def portal_verified?/1` (both clauses)
- `def portal_session_verified?/2` (the public function — the `portal_master_session_verified?/2` definition stays unchanged)
- `def portal_verified_until/1`
- `def portal_verification_ttl_seconds/0`
- `defp portal_answer/0`
- `defp env_integer/1` if it has no other callers (it does not — `parse_positive_integer/1` is only called by `env_integer/1`; remove that too).

Rewrite `portal_master_session_verified?/2` so it no longer references `@portal_session_key`:

```elixir
def portal_master_session_verified?(session, now \\ DateTime.utc_now())
    when is_map(session) do
  session_verified?(session, @portal_master_session_key, now)
end
```

(That clause already reads this way — verify and leave alone.)

The module after this step should contain: `@portal_master_session_key`, `portal_master_session_key/0`, `portal_master_verified?/1` (both clauses), `portal_master_session_verified?/2`, `session_verified?/3`, `portal_master_password/0`, `stored_master_password/0`, `configured_master_password/0`, `normalize/1`, `secure_compare/2` (all three clauses).

- [ ] **Step 4: Compile and run Access tests**

Run: `mix compile --warnings-as-errors && mix test test/rempost/access_test.exs`
Expected: clean compile, all remaining tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/rempost/access.ex test/rempost/access_test.exs
git commit -m "refactor: remove portal reveal-gate from Rempost.Access"
```

---

## Task 6: Delete `PortalAccessController` and its route

**Files:**
- Delete: `lib/rempost_web/controllers/portal_access_controller.ex`
- Modify: `lib/rempost_web/router.ex`

- [ ] **Step 1: Remove the route**

In `lib/rempost_web/router.ex`, find the public browser scope and delete the line:

```elixir
post "/portal/verify", PortalAccessController, :create
```

- [ ] **Step 2: Delete the controller file**

Run: `git rm lib/rempost_web/controllers/portal_access_controller.ex`

- [ ] **Step 3: Compile with warnings as errors**

Run: `mix compile --warnings-as-errors`
Expected: clean. If any LiveView/template still references `PortalAccessController` or `~p"/portal/verify"`, the compiler / route helper will fail — those references are addressed in Tasks 7–8.

- [ ] **Step 4: Commit**

```bash
git add lib/rempost_web/router.ex lib/rempost_web/controllers/portal_access_controller.ex
git commit -m "refactor: drop PortalAccessController and /portal/verify route"
```

---

## Task 7: Rewrite `ShipmentLive.Index` module

The LiveView collapses to two steps (`:lookup`, `:results`) with events `suggest`, `pick`, `submit`, `clear`. Master flow stays.

**Files:**
- Modify: `lib/rempost_web/live/shipment_live/index.ex`

- [ ] **Step 1: Replace `mount/3`, `handle_params/3`, and the relevant `handle_event/3` clauses**

Open `lib/rempost_web/live/shipment_live/index.ex` and replace the top of the module (everything up to but not including the `handle_info` clauses) with:

```elixir
defmodule RempostWeb.ShipmentLive.Index do
  use RempostWeb, :live_view

  @suggest_min_chars 2

  def mount(params, session, socket) do
    if connected?(socket), do: Rempost.Shipments.subscribe()

    name = params |> Map.get("name", "") |> String.trim()

    master_access? =
      Rempost.Access.portal_master_session_verified?(session) && params["step"] != "start"

    {:ok,
     socket
     |> assign(:shipments, [])
     |> assign(:customer_summaries, [])
     |> assign(:selected_customer, params |> Map.get("customer", "") |> String.trim())
     |> assign(:search_query, params |> Map.get("search", "") |> String.trim())
     |> assign(:selected_shipment_id, nil)
     |> assign(:query, name)
     |> assign(:suggestions, [])
     |> assign(:candidates, [])
     |> assign(:lookup_name, name)
     |> assign(:lookup_error, nil)
     |> assign(:master_access?, master_access?)
     |> assign(:step, initial_step(name, master_access?))
     |> maybe_load_initial_shipments()}
  end

  def handle_params(%{"step" => "start"}, _uri, socket) do
    {:noreply,
     socket
     |> assign(:shipments, [])
     |> assign(:customer_summaries, [])
     |> assign(:selected_customer, "")
     |> assign(:search_query, "")
     |> assign(:selected_shipment_id, nil)
     |> assign(:query, "")
     |> assign(:suggestions, [])
     |> assign(:candidates, [])
     |> assign(:lookup_name, "")
     |> assign(:lookup_error, nil)
     |> assign(:master_access?, false)
     |> assign(:step, :lookup)}
  end

  def handle_params(%{"name" => name} = params, _uri, socket) when name != "" do
    {:noreply,
     socket
     |> assign(:query, name)
     |> assign(:lookup_name, name)
     |> assign(:selected_customer, params |> Map.get("customer", "") |> String.trim())
     |> assign(:search_query, params |> Map.get("search", "") |> String.trim())
     |> assign(:lookup_error, nil)
     |> assign(:suggestions, [])
     |> assign(:candidates, [])
     |> assign(:step, :results)
     |> load_public_shipments()}
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  def handle_event("suggest", %{"value" => q}, socket) do
    suggestions = Rempost.Shipments.suggest_recipients(q)
    {:noreply, socket |> assign(:query, q) |> assign(:suggestions, suggestions)}
  end

  def handle_event("pick", %{"name" => name}, socket) do
    name = String.trim(name)

    if name == "" do
      {:noreply, socket}
    else
      {:noreply, push_patch(socket, to: ~p"/portal?#{%{name: name}}")}
    end
  end

  def handle_event("submit", %{"lookup" => %{"name" => name}}, socket) do
    name = String.trim(name)

    cond do
      name == "" ->
        {:noreply,
         socket
         |> assign(:lookup_error, "Vul je naam in om verder te gaan.")
         |> assign(:candidates, [])}

      true ->
        case Rempost.Shipments.suggest_recipients(name) do
          [] ->
            {:noreply,
             socket
             |> assign(:lookup_error,
               "Geen pakketten gevonden onder die naam. Controleer de spelling.")
             |> assign(:candidates, [])}

          [%{name: exact}] ->
            {:noreply, push_patch(socket, to: ~p"/portal?#{%{name: exact}}")}

          [_ | _] = many ->
            {:noreply,
             socket
             |> assign(:lookup_error, nil)
             |> assign(:candidates, Enum.map(many, & &1.name))}
        end
    end
  end

  def handle_event("clear", _params, socket) do
    {:noreply,
     socket
     |> assign(:query, "")
     |> assign(:suggestions, [])
     |> assign(:candidates, [])
     |> assign(:lookup_error, nil)
     |> assign(:step, :lookup)
     |> push_patch(to: ~p"/portal?step=start")}
  end

  def handle_event("select_shipment", %{"id" => id}, socket) do
    {:noreply, assign(socket, :selected_shipment_id, parse_selected_id(id))}
  end

  def handle_event("search_results", %{"filters" => %{"search" => search}}, socket) do
    search = String.trim(search)

    {:noreply,
     socket
     |> assign(:search_query, search)
     |> push_patch(
       to:
         ~p"/portal?#{%{master: "1", customer: socket.assigns.selected_customer, search: search}}"
     )}
  end

  def handle_event("master_access", %{"master" => %{"password" => password}}, socket) do
    password = String.trim(password)

    if Rempost.Access.portal_master_verified?(password) do
      {:noreply,
       socket
       |> assign(:master_access?, true)
       |> assign(:step, :results)
       |> assign(:lookup_error, nil)
       |> assign(:lookup_name, "Alle zendingen")
       |> assign(:selected_customer, "")
       |> assign(:search_query, "")
       |> load_public_shipments()
       |> push_patch(to: ~p"/portal?#{%{master: "1"}}")}
    else
      {:noreply, assign(socket, :lookup_error, "Master password klopt niet.")}
    end
  end
```

- [ ] **Step 2: Replace the private helpers below the event handlers**

In the same file, find `defp initial_step(...)` and `defp maybe_load_initial_shipments(...)` and `defp load_public_shipments(socket)` and replace them with:

```elixir
  defp initial_step(_name, true), do: :results
  defp initial_step("", _master?), do: :lookup
  defp initial_step(_name, false), do: :results

  defp maybe_load_initial_shipments(%{assigns: %{step: :results}} = socket),
    do: load_public_shipments(socket)

  defp maybe_load_initial_shipments(socket), do: socket

  defp load_public_shipments(socket) do
    shipments =
      if socket.assigns.master_access? do
        Rempost.Shipments.list_shipments(
          customer_name: socket.assigns.selected_customer,
          search: socket.assigns.search_query
        )
      else
        Rempost.Shipments.lookup_by_recipient(socket.assigns.lookup_name)
      end

    socket
    |> assign(:shipments, shipments)
    |> assign(:customer_summaries, load_customer_summaries(socket))
    |> assign(
      :selected_shipment_id,
      selected_shipment_id(shipments, socket.assigns.selected_shipment_id)
    )
  end
```

- [ ] **Step 3: Delete obsolete helpers**

In the same file, delete every definition that is no longer referenced. Specifically remove:

- All `defp normalize_mode/1` clauses
- `defp verification_prompt/1` (both clauses)
- `def address_label/1`, `def address_placeholder/1`, `def address_toggle/1`
- `def step_active?/2` (all clauses)
- `def status_feedback/1` (all clauses)
- `def identity_label/2` (kept only if still referenced by the template after Task 8 — for now, leave it; will remove during template rewrite if unused)
- `defp flash_error/1` if no longer called

Use `mix compile --warnings-as-errors` after step 4 to surface anything that's unused.

- [ ] **Step 4: Compile and confirm**

Run: `mix compile --warnings-as-errors`
Expected: template references in the heex will likely still be broken — that's fine for now (the heex is rewritten in Task 8). The `.ex` file itself should compile clean. If the heex compiler complains about a missing assign or function, note it but continue to Task 8 — Task 8 rewrites the template.

- [ ] **Step 5: Commit** (the .ex file alone, even if heex is temporarily broken — it gets fixed next task)

```bash
git add lib/rempost_web/live/shipment_live/index.ex
git commit -m "refactor: collapse portal LiveView to single autocomplete step"
```

---

## Task 8: Rewrite `ShipmentLive.Index` template

The template loses the `:identify`/`:verify` branches and gains a suggestions dropdown.

**Files:**
- Modify: `lib/rempost_web/live/shipment_live/index.html.heex`

- [ ] **Step 1: Replace the lookup section**

Open `lib/rempost_web/live/shipment_live/index.html.heex`. Find the `<%= if @step == :identify do %>` block (starts near line 51) and the following `<%= if @step == :verify do %>` block. Replace **both** blocks (one combined `if`/`elsif` covering identify and verify in the current file) with a single `:lookup` block:

```heex
      <%= if @step == :lookup do %>
        <section class="w-full animate-[rempost-step-in_420ms_cubic-bezier(0.22,1,0.36,1)]">
          <h1 class="font-serif text-5xl leading-[1.05] text-[#241914] sm:text-6xl">
            Hé, wie ben je?<br />
            <em class="font-normal text-[#db8142]">We zoeken je pakket.</em>
          </h1>

          <p class="mt-5 max-w-lg text-lg leading-8 text-[#70645d]">
            Typ je naam zoals die op de bestelling staat.
          </p>

          <.form for={%{}} phx-submit="submit" as={:lookup} class="mt-11" autocomplete="off">
            <div class="relative">
              <label class="mb-3 block text-xs font-semibold uppercase tracking-[0.16em] text-[#6b625c]">
                Naam op bestelling
              </label>

              <div class={[
                "flex h-16 items-center gap-4 rounded-2xl border bg-white/80 px-5 shadow-sm transition-colors",
                @lookup_error && "border-red-300 ring-2 ring-red-100",
                !@lookup_error && "border-[#ded6ca] focus-within:border-[#db8142]"
              ]}>
                <.icon name="hero-magnifying-glass" class="h-5 w-5 shrink-0 text-[#756961]" />
                <input
                  id="lookup_name"
                  type="text"
                  name="lookup[name]"
                  value={@query}
                  phx-keyup="suggest"
                  phx-debounce="200"
                  autocomplete="off"
                  autofocus
                  placeholder="Begin met typen..."
                  class="min-w-0 flex-1 bg-transparent text-lg text-[#2b211c] outline-none placeholder:text-[#aaa39b]"
                />
                <%= if @lookup_error do %>
                  <.icon name="hero-exclamation-circle" class="h-5 w-5 shrink-0 text-red-500" />
                <% end %>
              </div>

              <%= if @suggestions != [] do %>
                <ul class="mt-2 overflow-hidden rounded-2xl border border-[#ded6ca] bg-white/95 shadow-sm">
                  <%= for s <- @suggestions do %>
                    <li>
                      <button
                        type="button"
                        phx-click="pick"
                        phx-value-name={s.name}
                        class="flex w-full items-center justify-between px-5 py-3 text-left text-sm hover:bg-[#f5f0e6]"
                      >
                        <span class="font-medium text-[#2b211c]"><%= s.name %></span>
                        <span class="text-xs text-[#9a8e85]">
                          <%= s.shipment_count %>
                          <%= if s.shipment_count == 1, do: "pakket", else: "pakketten" %>
                        </span>
                      </button>
                    </li>
                  <% end %>
                </ul>
              <% end %>

              <%= if @candidates != [] do %>
                <div class="mt-3 rounded-2xl border border-[#ded6ca] bg-white/85 p-3 text-sm text-[#5f534c]">
                  <p class="px-2 pb-2 text-xs uppercase tracking-[0.16em] text-[#6b625c]">
                    Meerdere matches — kies er een
                  </p>
                  <%= for name <- @candidates do %>
                    <button
                      type="button"
                      phx-click="pick"
                      phx-value-name={name}
                      class="block w-full rounded-xl px-3 py-2 text-left hover:bg-[#f5f0e6]"
                    >
                      <%= name %>
                    </button>
                  <% end %>
                </div>
              <% end %>

              <%= if @lookup_error do %>
                <p class="mt-2 text-sm text-red-600"><%= @lookup_error %></p>
              <% end %>
            </div>

            <div class="mt-7 flex items-center gap-3">
              <button
                type="submit"
                class="group inline-flex h-14 items-center gap-3 rounded-2xl bg-[#4a2c22] px-7 text-base font-semibold text-white shadow-sm transition hover:bg-[#3b231b] disabled:opacity-60"
                phx-disable-with="Zoeken..."
              >
                Zoek pakket
                <span class="transition-transform group-hover:translate-x-0.5">→</span>
              </button>
            </div>
          </.form>

          <details class="mt-10 rounded-2xl border border-[#ded6ca] bg-white/45 p-4 text-sm text-[#70645d]">
            <summary class="cursor-pointer select-none font-semibold text-[#4a2c22]">
              Master toegang
            </summary>

            <.form for={%{}} phx-submit="master_access" as={:master} class="mt-4 flex flex-col gap-3 sm:flex-row">
              <div class="flex h-12 min-w-0 flex-1 items-center gap-3 rounded-xl border border-[#ded6ca] bg-white/80 px-4">
                <.icon name="hero-key" class="h-4 w-4 shrink-0 text-[#756961]" />
                <input
                  id="master_password"
                  type="password"
                  name="master[password]"
                  placeholder={master_access_placeholder()}
                  autocomplete="current-password"
                  class="min-w-0 flex-1 bg-transparent text-sm text-[#2b211c] outline-none placeholder:text-[#aaa39b]"
                />
              </div>

              <button
                type="submit"
                class="inline-flex h-12 items-center justify-center rounded-xl bg-[#4a2c22] px-5 text-sm font-semibold text-white"
              >
                Open
              </button>
            </.form>
          </details>
        </section>
```

- [ ] **Step 2: Update the progress-dot strip in the header**

Find the `<%= for {step_key, label} <- [identify: "Naam", verify: "Controle", results: "Resultaat"] do %>` block near line 23 and replace the loop with two dots only:

```heex
          <%= for {step_key, label} <- [lookup: "Zoek", results: "Resultaat"] do %>
            <span
              title={label}
              class={[
                "h-1 rounded-full transition-all duration-300",
                step_active_dot?(step_key, @step) && "w-9 bg-[#db8142]",
                !step_active_dot?(step_key, @step) && "w-5 bg-[#d8d2c8]"
              ]}
            >
            </span>
          <% end %>
```

Add a small helper at the bottom of `lib/rempost_web/live/shipment_live/index.ex`:

```elixir
def step_active_dot?(:lookup, _step), do: true
def step_active_dot?(:results, :results), do: true
def step_active_dot?(_, _), do: false
```

- [ ] **Step 3: Replace references in the results block**

Find the `<%= if @step == :results do %>` block. Search inside it for any reference to `~p"/portal?step=verify..."`, `back_to_verify`, `verification_mode`, `verification_value`, `edit_lookup`, `identity_label`, or `step_active?`. Replace any "edit" / "back" link or button so it dispatches `phx-click="clear"` (which returns the user to a fresh `:lookup`):

Find and replace:
- `phx-click="edit_lookup"` → `phx-click="clear"`
- `phx-click="back_to_verify"` → `phx-click="clear"`
- `identity_label(@lookup_name, @master_access?)` → `if @master_access?, do: "Alle zendingen", else: @lookup_name`

Remove any block that renders `@verification_mode` / `@verification_value` / `address_label`.

- [ ] **Step 4: Compile**

Run: `mix compile --warnings-as-errors`
Expected: clean compile.

- [ ] **Step 5: Smoke test in browser**

Run: `mix phx.server` (or `./bin/dev`).
Open http://localhost:4000/portal.
Type a name fragment that matches an existing recipient — confirm dropdown appears, click → results page renders. Then `/portal?name=<exact name>` directly → results page. Then master password flow → all shipments.

- [ ] **Step 6: Commit**

```bash
git add lib/rempost_web/live/shipment_live/index.ex lib/rempost_web/live/shipment_live/index.html.heex
git commit -m "feat: single-step portal lookup with recipient autocomplete"
```

---

## Task 9: Rewrite the LiveView test

**Files:**
- Modify: `test/rempost_web/shipment_live_index_test.exs`

- [ ] **Step 1: Replace the existing tests**

Open `test/rempost_web/shipment_live_index_test.exs`. Delete the existing `test "looks up public shipments through name and postcode flow"` and the `test "lookup state is reflected in url params..."` tests. Keep the `setup` block (master-password env restore) and any helpers (`insert_order!`, `insert_shipment!`, `restore_env`) at the bottom of the file.

Add these tests in their place:

```elixir
  test "autocompletes recipients and navigates to results on pick", %{conn: conn} do
    order =
      insert_order!(%{
        order_number: "XXL-PORTAL-1",
        merchant_name: "XXL Nutrition",
        customer_name: "Iduna Bink",
        customer_postal_code: "2035PH"
      })

    insert_shipment!(order, "JVGL06178784002102090726")

    {:ok, view, html} = live(conn, ~p"/portal")
    assert html =~ "Naam op bestelling"

    # typing surfaces a suggestion
    render_keyup(element(view, "#lookup_name"), %{"value" => "iduna"})
    assert render(view) =~ "Iduna Bink"

    # picking it navigates to results
    view |> element("button[phx-click='pick'][phx-value-name='Iduna Bink']") |> render_click()

    html = render(view)
    assert html =~ "Iduna Bink"
    assert html =~ "JVGL06178784002102090726"
  end

  test "submitting an exact-match name goes straight to results", %{conn: conn} do
    order =
      insert_order!(%{
        order_number: "XXL-PORTAL-2",
        merchant_name: "XXL Nutrition",
        customer_name: "Tom Bakker"
      })

    insert_shipment!(order, "JVGL06178784002102090727")

    {:ok, view, _html} = live(conn, ~p"/portal")

    view
    |> form("form[phx-submit='submit']", lookup: %{name: "Tom Bakker"})
    |> render_submit()

    html = render(view)
    assert html =~ "Tom Bakker"
    assert html =~ "JVGL06178784002102090727"
  end

  test "submitting an unknown name shows an inline error", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/portal")

    view
    |> form("form[phx-submit='submit']", lookup: %{name: "Nobody Here"})
    |> render_submit()

    assert render(view) =~ "Geen pakketten gevonden"
  end

  test "submitting a name with multiple matches renders candidate picks", %{conn: conn} do
    a = insert_order!(%{order_number: "ORD-A", merchant_name: "XXL", customer_name: "Tom Bakker"})
    insert_shipment!(a, "JVGL00000000000000A00001")

    b = insert_order!(%{order_number: "ORD-B", merchant_name: "XXL", customer_name: "Tom de Vries"})
    insert_shipment!(b, "JVGL00000000000000B00001")

    {:ok, view, _html} = live(conn, ~p"/portal")

    view
    |> form("form[phx-submit='submit']", lookup: %{name: "Tom"})
    |> render_submit()

    html = render(view)
    assert html =~ "Tom Bakker"
    assert html =~ "Tom de Vries"
    assert html =~ "Meerdere matches"
  end

  test "deep-link with ?name= renders results directly", %{conn: conn} do
    order =
      insert_order!(%{
        order_number: "XXL-PORTAL-DEEP",
        merchant_name: "XXL Nutrition",
        customer_name: "Anna van Dijk"
      })

    insert_shipment!(order, "JVGL06178784002102090728")

    {:ok, _view, html} = live(conn, ~p"/portal?#{%{name: "Anna van Dijk"}}")

    assert html =~ "Anna van Dijk"
    assert html =~ "JVGL06178784002102090728"
  end
```

Add `import Phoenix.LiveViewTest` should already be present — verify near the top of the file.

- [ ] **Step 2: Run the LiveView test**

Run: `mix test test/rempost_web/shipment_live_index_test.exs`
Expected: 5 tests pass.

- [ ] **Step 3: Run the full suite**

Run: `mix test`
Expected: full pass.

- [ ] **Step 4: Commit**

```bash
git add test/rempost_web/shipment_live_index_test.exs
git commit -m "test: portal autocomplete lookup flow"
```

---

## Task 10: Final smoke + cleanup

- [ ] **Step 1: Manual smoke test**

Run: `mix phx.server`
- Visit `http://localhost:4000/portal` — single field, no postcode step.
- Type 2+ chars of a real recipient name — dropdown shows matches with shipment counts.
- Click a suggestion → results page with shipments + tracking inline.
- Visit `http://localhost:4000/portal?name=NoSuchPerson` → results page with empty state (or graceful "geen pakketten" — verify rendering).
- Submit an unknown name from the field → inline error appears.
- Submit a partial name matching multiple recipients → candidate picks render.
- Open the "Master toegang" details, enter master password → all shipments view.

- [ ] **Step 2: Check for orphaned references**

Run:
```bash
grep -rn "lookup_public_shipments\|PortalAccessController\|portal_session_verified\|portal_session_key\|verification_mode\|verification_value\|portal_verified?\|portal_verified_until" lib test
```
Expected: no matches.

- [ ] **Step 3: Strip stale README references**

Open `README.md` and remove or rewrite:
- The bullet "exposes public shipment lookup separately from admin debugging surfaces" stays.
- The `REMPOST_PORTAL_ACCESS_ANSWER` row in the env table — delete (no longer used).
- The `REMPOST_PORTAL_VERIFICATION_TTL_SECONDS` row — delete (no longer used).
- The sentence "If the portal access answer is missing, tracking reveal fails closed." — delete.
- Keep the master password entry and "/portal" route description; update the description to reflect single-step autocomplete.

- [ ] **Step 4: Final commit**

```bash
git add README.md
git commit -m "docs: refresh README for single-step portal lookup"
```

- [ ] **Step 5: Push when ready** (do NOT push without explicit user approval)

---

## Self-review notes

- Spec sections covered: user flow → Tasks 7–9; architecture (`suggest_recipients`, `lookup_by_recipient`) → Tasks 2–3; SQL extension → Task 1; LiveView state/events → Task 7; routes → Task 6; error handling → Task 7 events + Task 9 tests; testing → Tasks 2/3/9; route migration / unknown step fallthrough → Task 7 `handle_params` default clause; out-of-scope (recent-shipments block, bookmark URLs) — correctly omitted.
- `Shipments.normalize_text/1` deletion is conditional on grep — flagged in Task 4 step 2.
- `identity_label/2` removal deferred to Task 8 step 3 (template touch).
- Master flow untouched throughout.
