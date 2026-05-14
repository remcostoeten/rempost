#!/usr/bin/env node

const graphBaseUrl = "https://graph.microsoft.com/v1.0";
const tokenCachePath = new URL("../tmp/hotmail-import-token.json", import.meta.url);

const config = {
  clientId: process.env.MICROSOFT_CLIENT_ID,
  tenant: process.env.MICROSOFT_TENANT || "consumers",
  scopes:
    process.env.MICROSOFT_SCOPES ||
    "https://graph.microsoft.com/Mail.Read offline_access",
  query: process.env.HOTMAIL_IMPORT_QUERY || "XXL Nutrition",
  allowedFrom: parseList(
    process.env.HOTMAIL_IMPORT_ALLOWED_FROM ||
      "info@xxlnutrition.com,noreply@dhlecommerce.nl,no-reply@sendcloud.com"
  ),
  maxMessages: parseInteger(process.env.HOTMAIL_IMPORT_MAX, 100),
  pageSize: parseInteger(process.env.HOTMAIL_IMPORT_PAGE_SIZE, 25),
  rempostBaseUrl: process.env.REMPOST_BASE_URL || "http://127.0.0.1:4000",
  rempostToken:
    process.env.REMPOST_INBOUND_TOKEN ||
    (isLocalhost(process.env.REMPOST_BASE_URL) ? "dev-inbound-token" : undefined),
  dryRun: process.env.HOTMAIL_IMPORT_DRY_RUN !== "0",
};

main().catch((error) => {
  console.error(`\nImport failed: ${error.message}`);
  process.exitCode = 1;
});

async function main() {
  validateConfig();

  const accessToken = await getAccessToken();
  const messages = await listMatchingMessages(accessToken);
  const filteredMessages = filterMessages(messages);

  console.log(
    `${config.dryRun ? "Dry run:" : "Importing"} ${filteredMessages.length} of ${messages.length} message(s) matching "${config.query}".`
  );

  let imported = 0;
  let failed = 0;

  for (const message of filteredMessages) {
    const payload = normalizeMessage(message);

    if (config.dryRun) {
      printMessage(payload);
      continue;
    }

    try {
      const result = await postToRempost(payload);
      imported += 1;
      console.log(`queued ${payload.message_id} -> inbound_email:${result.id}`);
    } catch (error) {
      failed += 1;
      console.error(`failed ${payload.message_id}: ${error.message}`);
    }
  }

  if (config.dryRun) {
    console.log("\nSet HOTMAIL_IMPORT_DRY_RUN=0 to post these emails into Rempost.");
  } else {
    console.log(`\nDone. Imported: ${imported}. Failed: ${failed}.`);
  }
}

function validateConfig() {
  if (!config.clientId) {
    throw new Error(
      "MICROSOFT_CLIENT_ID is required. Create a public-client app registration with delegated Mail.Read."
    );
  }

  if (!config.rempostToken) {
    throw new Error("REMPOST_INBOUND_TOKEN is required when REMPOST_BASE_URL is not localhost.");
  }
}

async function getAccessToken() {
  const cached = await readCachedToken();

  if (cached && cached.access_token && cached.expires_at > Date.now() + 60_000) {
    return cached.access_token;
  }

  if (cached && cached.refresh_token) {
    try {
      return await refreshAccessToken(cached.refresh_token);
    } catch (error) {
      console.warn(`Refresh token failed, starting device login: ${error.message}`);
    }
  }

  return await loginWithDeviceCode();
}

async function loginWithDeviceCode() {
  const deviceCodeUrl = microsoftUrl(config.tenant, "/oauth2/v2.0/devicecode");

  const deviceResponse = await postForm(deviceCodeUrl, {
    client_id: config.clientId,
    scope: config.scopes,
  });

  console.log(deviceResponse.message);

  const tokenUrl = microsoftUrl(config.tenant, "/oauth2/v2.0/token");
  const pollIntervalMs = (deviceResponse.interval || 5) * 1000;
  const deadline = Date.now() + deviceResponse.expires_in * 1000;

  while (Date.now() < deadline) {
    await sleep(pollIntervalMs);
    process.stdout.write(".");

    const response = await fetch(tokenUrl, {
      method: "POST",
      headers: {"content-type": "application/x-www-form-urlencoded"},
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:device_code",
        client_id: config.clientId,
        device_code: deviceResponse.device_code,
      }),
    });

    const body = await response.json();

    if (response.ok) {
      process.stdout.write("\n");
      await writeCachedToken(body);
      return body.access_token;
    }

    if (body.error === "authorization_pending") {
      continue;
    }

    if (body.error === "slow_down") {
      await sleep(pollIntervalMs);
      continue;
    }

    process.stdout.write("\n");
    throw new Error(body.error_description || body.error || "device login failed");
  }

  process.stdout.write("\n");
  throw new Error("device login expired before authorization completed");
}

async function refreshAccessToken(refreshToken) {
  const body = await postForm(microsoftUrl(config.tenant, "/oauth2/v2.0/token"), {
    client_id: config.clientId,
    grant_type: "refresh_token",
    refresh_token: refreshToken,
    scope: config.scopes,
  });

  await writeCachedToken(body);
  return body.access_token;
}

async function listMatchingMessages(accessToken) {
  const params = new URLSearchParams({
    "$search": `"${config.query}"`,
    "$top": String(config.pageSize),
    "$select": "id,internetMessageId,subject,from,receivedDateTime,body,bodyPreview",
  });

  let url = `${graphBaseUrl}/me/messages?${params}`;
  const messages = [];

  while (url && messages.length < config.maxMessages) {
    const response = await graphFetch(accessToken, url);
    messages.push(...response.value.slice(0, config.maxMessages - messages.length));
    url = response["@odata.nextLink"];
  }

  return messages;
}

function normalizeMessage(message) {
  const contentType = message.body?.contentType || "text";
  const content = message.body?.content || "";

  return {
    message_id: message.internetMessageId || message.id,
    from_email: message.from?.emailAddress?.address || "unknown@outlook.local",
    subject: message.subject || "",
    received_at: message.receivedDateTime,
    raw_headers: {
      graph_message_id: message.id,
      graph_import_query: config.query,
    },
    raw_text: contentType === "text" ? content : message.bodyPreview || htmlToText(content),
    raw_html: contentType === "html" ? content : null,
  };
}

function filterMessages(messages) {
  if (config.allowedFrom.length === 0) {
    return messages;
  }

  return messages.filter((message) => {
    const from = (message.from?.emailAddress?.address || "").toLowerCase();
    return config.allowedFrom.includes(from);
  });
}

async function postToRempost(payload) {
  const response = await fetch(`${config.rempostBaseUrl}/api/inbound/email`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-rempost-token": config.rempostToken,
    },
    body: JSON.stringify(payload),
  });

  const body = await response.json().catch(() => ({}));

  if (!response.ok) {
    throw new Error(`${response.status} ${JSON.stringify(body)}`);
  }

  return body;
}

async function graphFetch(accessToken, url) {
  const response = await fetch(url, {
    headers: {
      authorization: `Bearer ${accessToken}`,
      consistencyLevel: "eventual",
    },
  });

  const body = await response.json();

  if (!response.ok) {
    throw new Error(body.error?.message || `${response.status} from Microsoft Graph`);
  }

  return body;
}

async function postForm(url, values) {
  const response = await fetch(url, {
    method: "POST",
    headers: {"content-type": "application/x-www-form-urlencoded"},
    body: new URLSearchParams(values),
  });

  const body = await response.json();

  if (!response.ok) {
    throw new Error(body.error_description || body.error || `${response.status} from Microsoft`);
  }

  return body;
}

async function readCachedToken() {
  try {
    const file = await import("node:fs/promises");
    return JSON.parse(await file.readFile(tokenCachePath, "utf8"));
  } catch {
    return null;
  }
}

async function writeCachedToken(token) {
  const file = await import("node:fs/promises");
  await file.mkdir(new URL("../tmp/", import.meta.url), {recursive: true});
  await file.writeFile(
    tokenCachePath,
    JSON.stringify(
      {
        ...token,
        expires_at: Date.now() + token.expires_in * 1000,
      },
      null,
      2
    )
  );
}

function microsoftUrl(tenant, path) {
  return `https://login.microsoftonline.com/${tenant}${path}`;
}

function printMessage(payload) {
  console.log([
    "",
    payload.received_at || "(no date)",
    payload.from_email,
    payload.subject || "(no subject)",
    payload.message_id,
  ].join("\n  "));
}

function htmlToText(html) {
  return html
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function parseInteger(value, fallback) {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function parseList(value) {
  return String(value || "")
    .split(",")
    .map((item) => item.trim().toLowerCase())
    .filter(Boolean);
}

function isLocalhost(value) {
  return !value || /^https?:\/\/(127\.0\.0\.1|localhost)(:\d+)?/i.test(value);
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
