import PostalMime from "postal-mime";

export default {
  async email(message, env) {
    const parser = new PostalMime();
    const parsed = await parser.parse(message.raw);

    const payload = {
      id: message.headers.get("message-id") || crypto.randomUUID(),
      from: message.from,
      subject: parsed.subject || "",
      date: new Date().toISOString(),
      text: parsed.text || "",
      html: parsed.html || null,
      headers: Object.fromEntries(message.headers),
      token: env.REMPOST_INBOUND_TOKEN
    };

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
    }
  }
};
