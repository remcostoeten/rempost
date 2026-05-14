Can you please transform these templates to React components:

## `lib/rempost_web/components/layouts/root.html.heex`
```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="csrf-token" content={get_csrf_token()} />
    <link phx-track-static rel="stylesheet" href={~p"/assets/app.css"} />
    <script defer phx-track-static type="text/javascript" src={~p"/assets/app.js"}>
    </script>
  </head>
  <body class="bg-white text-zinc-900">
    <main class="mx-auto max-w-7xl p-6">
      <%= @inner_content %>
    </main>
  </body>
</html>
```

## `lib/rempost_web/live/dashboard_live/index.html.heex`
```html
<section class="space-y-6">
  <div class="rounded-xl border border-zinc-200 bg-white p-5">
    <div class="bg-foreground flex flex-col gap-3 md:flex-row md:items-end md:justify-between">
      <div>
        <h1 class="text-2xl font-semibold tracking-tight">Inbound emails</h1>
        <p class="text-sm text-zinc-500">Ingestion log for the parser. Live-updates as Cloudflare delivers mail.</p>
      </div>

      <form phx-change="search" class="w-full md:w-96">
        <input
          type="text"
          name="q"
          value={@search}
          phx-debounce="300"
          placeholder="Search sender, subject, message ID, status"
          class="w-full rounded-md border border-zinc-300 px-3 py-2 text-sm"
        />
      </form>
    </div>

    <div class="mt-3 text-xs text-zinc-500">
      Showing <span class="font-medium text-zinc-700"><%= @total_count %></span> email<%= if @total_count == 1, do: "", else: "s" %>
      <%= if @search != "" do %>
        for query <span class="font-medium text-zinc-700">"<%= @search %>"</span>
      <% end %>
    </div>
  </div>

  <div class="overflow-x-auto rounded-xl border border-zinc-200 bg-white">
    <table class="min-w-full text-sm">
      <thead class="bg-zinc-50 text-zinc-600">
        <tr>
          <th class="px-3 py-2 text-left">Received</th>
          <th class="px-3 py-2 text-left">From</th>
          <th class="px-3 py-2 text-left">Subject</th>
          <th class="px-3 py-2 text-left">Status</th>
        </tr>
      </thead>
      <tbody>
        <%= if @emails == [] do %>
          <tr class="border-t border-zinc-100">
            <td class="px-3 py-6 text-center text-zinc-500" colspan="4">No emails yet. Post to <code>/api/inbound/email</code> to ingest.</td>
          </tr>
        <% end %>
        <%= for email <- @emails do %>
          <tr class="border-t border-zinc-100 align-top">
            <td class="px-3 py-2 whitespace-nowrap text-zinc-600"><%= Calendar.strftime(email.received_at, "%Y-%m-%d %H:%M") %></td>
            <td class="px-3 py-2"><%= email.from_email %></td>
            <td class="px-3 py-2">
              <.link navigate={~p"/emails/#{email.id}"} class="text-blue-700 hover:underline">
                <%= email.subject || "(no subject)" %>
              </.link>
            </td>
            <td class="px-3 py-2">
              <span class={[
                "inline-flex rounded-md px-2 py-1 text-xs font-medium",
                email.status == :failed && "bg-red-100 text-red-700",
                email.status == :processing && "bg-amber-100 text-amber-700",
                email.status == :parsed && "bg-emerald-100 text-emerald-700",
                email.status == :pending && "bg-zinc-100 text-zinc-700"
              ]}>
                <%= email.status %>
              </span>
            </td>
          </tr>
        <% end %>
      </tbody>
    </table>
  </div>
</section>
```

## `lib/rempost_web/live/shipment_live/index.html.heex`
```html
<section class="relative min-h-[calc(100vh-3rem)] overflow-hidden bg-[#fafafa] text-zinc-950">
  <div class="pointer-events-none absolute inset-0 bg-[linear-gradient(to_right,rgba(24,24,27,0.045)_1px,transparent_1px),linear-gradient(to_bottom,rgba(24,24,27,0.045)_1px,transparent_1px)] bg-[size:56px_56px] [mask-image:radial-gradient(ellipse_at_center,black,transparent_74%)]">
  </div>

  <div class={[
    "relative mx-auto flex min-h-[calc(100vh-3rem)] flex-col px-4 py-7 transition-[max-width] duration-500 sm:px-6 lg:px-8",
    @step == :results && "max-w-6xl",
    @step != :results && "max-w-xl"
  ]}>
    <header class="flex items-center justify-between gap-4">
      <div class="flex items-center gap-2 text-sm font-semibold">
        <div class="grid h-7 w-7 place-items-center rounded-md bg-zinc-950 text-[13px] text-white shadow-sm">
          R
        </div>
        Rempost
      </div>

      <div class="flex items-center gap-1.5" aria-label="Voortgang">
        <%= for {step_key, _label} <- [identify: "Naam", verify: "Controle", results: "Resultaat"] do %>
          <span class={[
            "h-1 rounded-full transition-all duration-500",
            step_active?(step_key, @step) && "w-8 bg-zinc-950",
            !step_active?(step_key, @step) && "w-4 bg-zinc-300"
          ]}>
          </span>
        <% end %>
      </div>
    </header>

    <main class="flex flex-1 items-center justify-center py-10">
      <%= if @step == :identify do %>
        <div class="w-full animate-[rempost-step-in_420ms_cubic-bezier(0.22,1,0.36,1)]">
          <p class="text-sm font-medium text-zinc-500">Hi,</p>
          <h1 class="mt-3 text-5xl font-semibold leading-[1.04] tracking-normal text-zinc-950 sm:text-6xl">
            Dus, weer op zoek naar je <span class="text-zinc-500">pakketje?</span>
          </h1>
          <p class="mt-5 max-w-md text-base leading-7 text-zinc-600">
            Vul je naam in. We zoeken daarna in de doorgestuurde order- en trackingmails.
          </p>

          <.form for={%{}} phx-submit="identify" as={:lookup} class="mt-10 space-y-6">
            <div>
              <label class="mb-2 block text-xs font-semibold uppercase text-zinc-500">
                Naam op bestelling
              </label>
              <div class={[
                "flex items-center gap-3 rounded-xl border bg-white px-4 py-3.5 shadow-sm transition-colors",
                @lookup_status == :error && "border-red-300",
                @lookup_status != :error && "border-zinc-200 focus-within:border-zinc-950"
              ]}>
                <span class="text-zinc-400">Zoek</span>
                <input
                  id="lookup_name"
                  type="text"
                  name="lookup[name]"
                  value={@lookup_name}
                  autocomplete="name"
                  autofocus
                  placeholder="Bijvoorbeeld Iduna Bink"
                  class="min-w-0 flex-1 bg-transparent text-base text-zinc-950 outline-none placeholder:text-zinc-400"
                />
              </div>

              <%= if @lookup_error do %>
                <p class="mt-2 text-sm text-red-600"><%= @lookup_error %></p>
              <% end %>
            </div>

            <button
              class="group inline-flex h-12 items-center gap-2 rounded-xl bg-zinc-950 px-5 text-sm font-semibold text-white shadow-sm transition hover:bg-zinc-800"
              phx-disable-with="Controleren..."
            >
              Ga verder
              <span class="transition-transform group-hover:translate-x-0.5">-></span>
            </button>
          </.form>

          <div class="mt-8 rounded-xl border border-zinc-200 bg-white p-4 shadow-sm">
            <p class="text-xs font-semibold uppercase text-zinc-500">Master toegang</p>
            <p class="mt-1 text-sm text-zinc-600">
              Open alle zendingen zonder klantverificatie.
            </p>

            <.form for={%{}} phx-submit="master_access" as={:master} class="mt-4 flex flex-col gap-3 sm:flex-row">
              <div class={[
                "flex flex-1 items-center gap-3 rounded-xl border px-4 py-3.5 transition-colors",
                @lookup_status == :error && "border-red-300",
                @lookup_status != :error && "border-zinc-200 focus-within:border-zinc-950"
              ]}>
                <span class="text-zinc-400">Slot</span>
                <input
                  id="master_password"
                  type="password"
                  name="master[password]"
                  placeholder={master_access_placeholder()}
                  autocomplete="current-password"
                  class="min-w-0 flex-1 bg-transparent text-base text-zinc-950 outline-none placeholder:text-zinc-400"
                />
              </div>

              <button
                class="inline-flex h-12 items-center justify-center rounded-xl border border-zinc-950 bg-zinc-950 px-5 text-sm font-semibold text-white shadow-sm transition hover:bg-zinc-800"
                phx-disable-with="Openen..."
              >
                Open alle zendingen
              </button>
            </.form>

            <%= if @lookup_error && @step == :identify do %>
              <p class="mt-2 text-sm text-red-600"><%= @lookup_error %></p>
            <% end %>
          </div>
        </div>
      <% end %>

      <%= if @step == :verify do %>
        <% {next_mode, toggle_label} = address_toggle(@verification_mode) %>

        <div class="w-full animate-[rempost-step-in_420ms_cubic-bezier(0.22,1,0.36,1)]">
          <p class="text-sm font-medium text-zinc-500">
            Hi <span class="font-semibold text-zinc-950"><%= @lookup_name %></span>,
          </p>
          <h1 class="mt-3 text-5xl font-semibold leading-[1.04] tracking-normal text-zinc-950 sm:text-6xl">
            Welke <%= String.downcase(address_label(@verification_mode)) %><br />
            <span class="text-zinc-500">hoort erbij?</span>
          </h1>
          <p class="mt-5 max-w-md text-base leading-7 text-zinc-600">
            Nog een korte controle zodat we alleen jouw pakketjes tonen.
          </p>

          <.form for={%{}} phx-submit="verify_address" as={:verification} class="mt-10 space-y-6">
            <input type="hidden" name="verification[mode]" value={@verification_mode} />

            <div>
              <label class="mb-2 block text-xs font-semibold uppercase text-zinc-500">
                <%= address_label(@verification_mode) %>
              </label>
              <div class={[
                "flex items-center gap-3 rounded-xl border bg-white px-4 py-3.5 shadow-sm transition-colors",
                @lookup_status == :error && "border-red-300",
                @lookup_status != :error && "border-zinc-200 focus-within:border-zinc-950"
              ]}>
                <span class="text-zinc-400">Adres</span>
                <input
                  id="verification_value"
                  type="text"
                  name="verification[value]"
                  value={@verification_value}
                  autocomplete="postal-code"
                  autofocus
                  placeholder={address_placeholder(@verification_mode)}
                  class="min-w-0 flex-1 bg-transparent text-base text-zinc-950 outline-none placeholder:text-zinc-400"
                />
              </div>

              <%= if @lookup_error || @verification_error do %>
                <p class="mt-2 text-sm text-red-600">
                  <%= @lookup_error || @verification_error %>
                </p>
              <% end %>
            </div>

            <button
              type="button"
              phx-click="switch_verification_mode"
              phx-value-mode={next_mode}
              class="text-sm text-zinc-500 underline-offset-4 transition hover:text-zinc-950 hover:underline"
            >
              <%= toggle_label %>
            </button>

            <div class="flex items-center gap-3">
              <button
                class="group inline-flex h-12 items-center gap-2 rounded-xl bg-zinc-950 px-5 text-sm font-semibold text-white shadow-sm transition hover:bg-zinc-800"
                phx-disable-with="Zendingen zoeken..."
              >
                Zoek mijn pakketjes
                <span class="transition-transform group-hover:translate-x-0.5">-></span>
              </button>

              <button
                type="button"
                phx-click="edit_lookup"
                class="text-sm font-medium text-zinc-500 transition hover:text-zinc-950"
              >
                Naam wijzigen
              </button>
            </div>
          </.form>
        </div>
      <% end %>

      <%= if @step == :results do %>
        <% selected = selected_shipment(@shipments, @selected_shipment_id) %>

        <div class="w-full animate-[rempost-step-in_420ms_cubic-bezier(0.22,1,0.36,1)] overflow-hidden rounded-xl border border-zinc-200 bg-white shadow-sm">
          <div class="flex flex-col gap-3 border-b border-zinc-200 bg-white px-5 py-4 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <p class="text-xs font-medium uppercase text-zinc-500">
                <%= if @master_access?, do: "Alle zendingen", else: "Pakketstatus" %>
              </p>
              <h1 class="mt-1 text-xl font-semibold text-zinc-950">
                <%= length(@shipments) %> <%= if length(@shipments) == 1, do: "pakket gevonden", else: "pakketten gevonden" %>
              </h1>
            </div>
            <div class="flex items-center gap-2">
              <%= if @master_access? do %>
                <span class="rounded-full border border-zinc-200 bg-zinc-50 px-3 py-1 text-xs text-zinc-600">
                  Master toegang
                </span>
              <% else %>
                <span class="rounded-full border border-zinc-200 bg-zinc-50 px-3 py-1 text-xs text-zinc-600">
                  <%= @lookup_name %>
                </span>
              <% end %>
              <button
                type="button"
                phx-click="back_to_verify"
                class="inline-flex h-9 items-center rounded-lg border border-zinc-200 px-3 text-xs font-semibold text-zinc-700 transition hover:border-zinc-300 hover:bg-zinc-50"
              >
                <%= if @master_access?, do: "Terug", else: "Opnieuw zoeken" %>
              </button>
            </div>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-[360px_1fr]">
            <aside class="max-h-[38rem] overflow-y-auto border-b border-zinc-200 bg-zinc-50/70 p-3 md:border-b-0 md:border-r">
              <%= if @shipments == [] do %>
                <div class="rounded-lg border border-dashed border-zinc-200 bg-white px-5 py-12 text-center">
                  <p class="text-sm font-semibold text-zinc-950">Geen pakketjes gevonden</p>
                  <p class="mt-1 text-sm text-zinc-500">
                    We konden geen zendingen koppelen aan deze naam en controle.
                  </p>
                </div>
              <% end %>

              <div class="space-y-2">
                <%= for {shipment, index} <- Enum.with_index(@shipments) do %>
                  <button
                    type="button"
                    phx-click="select_shipment"
                    phx-value-id={shipment.id}
                    style={"animation-delay: #{index * 45}ms"}
                    class={[
                      "relative block w-full rounded-lg border bg-white p-4 text-left opacity-0 shadow-sm transition [animation:rempost-list-in_320ms_ease_forwards]",
                      shipment.id == @selected_shipment_id && "border-zinc-950",
                      shipment.id != @selected_shipment_id && "border-zinc-200 hover:border-zinc-300"
                    ]}
                  >
                    <div class="flex items-start justify-between gap-3">
                      <div class="flex min-w-0 items-start gap-3">
                        <div class="grid h-10 w-10 shrink-0 place-items-center rounded-lg bg-zinc-950 text-xs font-semibold text-white">
                          <%= merchant_initials(shipment_merchant(shipment)) %>
                        </div>
                        <div class="min-w-0">
                          <p class="truncate text-sm font-semibold text-zinc-950">
                            <%= shipment_title(shipment) %>
                          </p>
                          <p class="mt-1 truncate text-xs text-zinc-500">
                            <%= shipment_subtitle(shipment) %>
                          </p>
                        </div>
                      </div>
                      <span class={[
                        "shrink-0 rounded-md border px-2 py-1 text-[11px] font-semibold",
                        status_classes(shipment.status)
                      ]}>
                        <%= status_label(shipment.status) %>
                      </span>
                    </div>
                    <div class="mt-4 flex items-center justify-between gap-3 border-t border-zinc-100 pt-3">
                      <span class="font-mono text-xs text-zinc-600">
                        ...<%= tracking_tail(shipment.tracking_number) %>
                      </span>
                      <span class="text-xs text-zinc-500">
                        <%= short_date(shipment.last_event_at || shipment.updated_at) %>
                      </span>
                    </div>
                  </button>
                <% end %>
              </div>
            </aside>

            <section class="relative min-h-[38rem] bg-white">
              <%= if selected do %>
                <article class="flex h-full flex-col">
                  <div class="border-b border-zinc-200 px-5 py-5 sm:px-7">
                    <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
                      <div class="min-w-0">
                        <div class="flex flex-wrap items-center gap-2">
                          <span class={[
                            "rounded-md border px-2.5 py-1 text-xs font-semibold",
                            status_classes(selected.status)
                          ]}>
                            <%= status_label(selected.status) %>
                          </span>
                          <span class="text-xs font-medium text-zinc-500">
                            <%= carrier_label(selected.carrier) %>
                          </span>
                        </div>
                        <h2 class="mt-4 text-3xl font-semibold leading-tight text-zinc-950">
                          <%= shipment_title(selected) %>
                        </h2>
                        <p class="mt-2 max-w-xl text-sm leading-6 text-zinc-600">
                          <%= status_description(selected.status) %>
                        </p>
                      </div>
                      <div class="rounded-lg border border-zinc-200 bg-zinc-50 px-3 py-2 text-right">
                        <p class="text-[11px] font-medium uppercase text-zinc-500">Laatste update</p>
                        <p class="mt-1 text-sm font-semibold text-zinc-950">
                          <%= format_datetime(selected.last_event_at || selected.updated_at) %>
                        </p>
                      </div>
                    </div>
                  </div>

                  <div class="flex-1 overflow-y-auto px-5 py-6 sm:px-7">
                    <div class="grid gap-3 sm:grid-cols-3">
                      <div class="rounded-lg border border-zinc-200 px-4 py-3">
                        <p class="text-xs font-medium uppercase text-zinc-500">Tracking</p>
                        <p class="mt-2 break-all font-mono text-sm font-semibold text-zinc-950">
                          <%= tracking_label(selected.tracking_number) %>
                        </p>
                      </div>
                      <div class="rounded-lg border border-zinc-200 px-4 py-3">
                        <p class="text-xs font-medium uppercase text-zinc-500">Referentie</p>
                        <p class="mt-2 text-sm font-semibold text-zinc-950">
                          <%= order_reference(selected) || "Geen ordernummer in deze mail" %>
                        </p>
                      </div>
                      <div class="rounded-lg border border-zinc-200 px-4 py-3">
                        <p class="text-xs font-medium uppercase text-zinc-500">Verwachte levering</p>
                        <p class="mt-2 text-sm font-semibold text-zinc-950">
                          <%= format_datetime(selected.estimated_delivery_at) %>
                        </p>
                      </div>
                    </div>

                    <div class="mt-8">
                      <div class="flex items-center justify-between gap-4">
                        <h3 class="text-sm font-semibold text-zinc-950">Voortgang</h3>
                        <span class="text-xs text-zinc-500">Voor <%= @lookup_name %></span>
                      </div>
                      <div class="mt-4 grid grid-cols-4 gap-0">
                        <%= for {{step_status, label}, index} <- Enum.with_index(timeline_steps()) do %>
                          <div class="relative">
                            <%= if index < 3 do %>
                              <span class={[
                                "absolute left-1/2 top-4 h-0.5 w-full",
                                timeline_line_classes(selected.status, step_status)
                              ]}>
                              </span>
                            <% end %>
                            <div class="relative flex flex-col items-center gap-2 text-center">
                              <span class={[
                                "grid h-8 w-8 place-items-center rounded-full border text-xs font-semibold",
                                timeline_step_classes(selected.status, step_status)
                              ]}>
                                <%= index + 1 %>
                              </span>
                              <span class="text-xs font-medium text-zinc-700"><%= label %></span>
                            </div>
                          </div>
                        <% end %>
                      </div>
                    </div>

                    <%= if selected.tracking_url do %>
                      <a
                        href={selected.tracking_url}
                        target="_blank"
                        rel="noreferrer"
                        class="mt-7 inline-flex h-11 items-center justify-center rounded-xl bg-zinc-950 px-5 text-sm font-semibold text-white transition hover:bg-zinc-800"
                      >
                        Open tracking bij vervoerder
                      </a>
                    <% end %>
                  </div>
                </article>
              <% else %>
                <div class="flex min-h-[38rem] items-center justify-center p-6 text-center">
                  <div>
                    <p class="text-sm font-semibold text-zinc-950">Geen zending geselecteerd</p>
                    <p class="mt-1 text-sm text-zinc-500">
                      Kies links een pakketje om de details te bekijken.
                    </p>
                  </div>
                </div>
              <% end %>
            </section>
          </div>
        </div>
      <% end %>
    </main>

    <footer class="text-xs text-zinc-500">
      Testdata uit geimporteerde XXL, Sendcloud en DHL mails.
    </footer>
  </div>
</section>
```

## `lib/rempost_web/live/shipment_live/show.html.heex`
```html
<section class="space-y-6">
  <div class="rounded-xl border border-zinc-200 bg-white p-5">
    <p class="text-xs font-semibold uppercase tracking-wide text-zinc-500">Shipment</p>
    <h1 class="text-2xl font-semibold">
      <%= if @verified?, do: @shipment.tracking_number, else: "Tracking hidden" %>
    </h1>
    <p class="mt-1 text-sm text-zinc-500">
      <%= @shipment.order && @shipment.order.order_number %> / <%= @shipment.carrier %> / <%= @shipment.status %>
    </p>
  </div>

  <%= unless @verified? do %>
    <div class="rounded-xl border border-amber-200 bg-amber-50 p-5">
      <h2 class="font-semibold text-amber-950">Answer to reveal tracking</h2>
      <p class="mt-1 text-sm text-amber-900">
        Answer the security question to see the tracking number and open the carrier link.
      </p>
      <.form for={%{}} action={~p"/portal/verify"} method="post" class="mt-4 flex flex-col gap-2 sm:flex-row">
        <input type="hidden" name="return_to" value={~p"/shipments/#{@shipment.id}"} />
        <input
          type="password"
          name="answer"
          placeholder="Your answer"
          aria-label="Security answer"
          class="rounded-md border border-amber-300 px-3 py-2 text-sm sm:w-80"
        />
        <button class="rounded-md bg-amber-950 px-4 py-2 text-sm font-medium text-white">
          Reveal tracking
        </button>
      </.form>

      <%= if @verification_error do %>
        <p class="mt-2 text-sm text-red-700"><%= @verification_error %></p>
      <% end %>
    </div>
  <% end %>

  <%= if @verified? && @shipment.tracking_url do %>
    <a href={@shipment.tracking_url} target="_blank" rel="noreferrer" class="inline-flex rounded-md bg-blue-700 px-4 py-2 text-sm font-medium text-white">
      Open carrier tracking
    </a>
  <% end %>

  <ol class="space-y-3">
    <%= for event <- @shipment.tracking_events do %>
      <li class="rounded-lg border border-zinc-200 bg-white p-3">
        <p class="font-medium"><%= event.status %></p>
        <p class="text-xs text-zinc-500"><%= event.occurred_at %></p>
      </li>
    <% end %>
  </ol>
</section>
```

## `lib/rempost_web/live/email_debug_live/show.html.heex`
```html
<section class="space-y-4">
  <div class="flex items-center justify-between">
    <h1 class="text-2xl font-semibold">Raw Email Debug</h1>
    <button
      phx-click="retry_parse"
      class="rounded-md bg-black px-3 py-2 text-sm font-semibold text-white hover:bg-zinc-800"
      type="button"
    >
      Retry parsing
    </button>
  </div>

  <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
    <div class="rounded-lg bg-zinc-100 p-3">
      <p class="text-xs uppercase tracking-wide text-zinc-500">Status</p>
      <p class="text-sm font-semibold"><%= @email.status %></p>
    </div>
    <div class="rounded-lg bg-zinc-100 p-3">
      <p class="text-xs uppercase tracking-wide text-zinc-500">Message ID</p>
      <p class="text-sm break-all"><%= @email.message_id %></p>
    </div>
    <div class="rounded-lg bg-zinc-100 p-3">
      <p class="text-xs uppercase tracking-wide text-zinc-500">From</p>
      <p class="text-sm break-all"><%= @email.from_email %></p>
    </div>
  </div>

  <%= if @retry_error do %>
    <p class="rounded-lg bg-red-50 p-3 text-sm text-red-700">Retry failed: <%= @retry_error %></p>
  <% end %>

  <%= if @email.parse_error do %>
    <div class="rounded-lg bg-amber-50 p-3 text-sm text-amber-800">
      <p class="font-semibold">Last parse error</p>
      <p><%= @email.parse_error %></p>
    </div>
  <% end %>

  <div>
    <p class="mb-2 text-sm font-semibold text-zinc-600">Raw text</p>
    <pre class="rounded-lg bg-zinc-100 p-4 overflow-auto"><%= @email.raw_text %></pre>
  </div>
</section>
```
