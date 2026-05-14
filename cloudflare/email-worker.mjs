function headersToObject(headers) {
  const out = {};

  for (const [key, value] of headers) {
    out[key] = value;
  }

  return out;
}

async function rawToText(raw) {
  if (typeof raw === "string") {
    return raw;
  }

  return new Response(raw).text();
}

export default {
  async email(message, env) {
    if (!env.REMPOST_INBOUND_URL || !env.REMPOST_INBOUND_TOKEN) {
      message.setReject("Rempost inbound endpoint is not configured");
      return;
    }

    const headers = headersToObject(message.headers);
    const raw = await rawToText(message.raw);
    const date = message.headers.get("date");

    const payload = {
      id: message.headers.get("message-id") || crypto.randomUUID(),
      from: message.from,
      subject: message.headers.get("subject") || "",
      date: date ? new Date(date).toISOString() : new Date().toISOString(),
      headers,
      text: raw,
      raw,
      html: null,
      token: env.REMPOST_INBOUND_TOKEN
    };

    try {
      const response = await fetch(env.REMPOST_INBOUND_URL, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-rempost-token": env.REMPOST_INBOUND_TOKEN
        },
        body: JSON.stringify(payload)
      });

      if (!response.ok) {
        const body = await response.text();
        console.error("Failed to forward inbound email", {
          status: response.status,
          body
        });

        message.setReject(`Rempost inbound endpoint returned ${response.status}`);
      }
    } catch (error) {
      console.error("Failed to reach Rempost inbound endpoint", {
        message: error.message
      });

      message.setReject("Rempost inbound endpoint is unreachable");
    }
  }
};
