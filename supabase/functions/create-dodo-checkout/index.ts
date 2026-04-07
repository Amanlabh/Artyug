// Deploy: supabase functions deploy create-dodo-checkout
// Secrets: supabase secrets set DODO_PAYMENTS_API_KEY=...
// Optional: DODO_PAYMENTS_MODE=test_mode|live_mode
//
// **Product cart:** Either send `product_cart` from the client, or set
// `DODO_PAYMENTS_DEFAULT_PRODUCT_ID` to a Dodo product. For per-artwork INR
// prices, create a one-time **pay-what-you-want** product in Dodo and set that
// id here; this function will pass `amount` in minor units (paise) from `amount_inr`.
//
// **API key:** Prefer the secret above. For local/dev only, the Flutter app may
// send `api_key` in the JSON body (never ship production web with keys in .env).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function dodoBaseUrl(): string {
  const mode = (Deno.env.get("DODO_PAYMENTS_MODE") ?? "test_mode").toLowerCase();
  return mode === "live_mode" ? "https://live.dodopayments.com" : "https://test.dodopayments.com";
}

/** Map app fields (line1, postal_code) to Dodo's billing_address shape. */
function normalizeBillingAddress(raw: unknown): Record<string, unknown> | undefined {
  if (!raw || typeof raw !== "object") return undefined;
  const b = raw as Record<string, unknown>;
  const line1 = String(b.line1 ?? b.street ?? "").trim();
  const line2 = String(b.line2 ?? "").trim();
  const street = [line1, line2].filter(Boolean).join(", ") || undefined;
  const city = b.city != null ? String(b.city).trim() : undefined;
  const state = b.state != null ? String(b.state).trim() : undefined;
  const zipcode = String(b.zipcode ?? b.postal_code ?? "").trim() || undefined;
  const country = String(b.country ?? "").trim().toUpperCase();
  if (!country || country.length !== 2) return undefined;
  const out: Record<string, unknown> = { country };
  if (street) out.street = street;
  if (city) out.city = city;
  if (state) out.state = state;
  if (zipcode) out.zipcode = zipcode;
  return out;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Authorization" }), {
        status: 401,
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user }, error: userErr } = await supabase.auth.getUser();
    if (userErr || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }

    const body = await req.json().catch(() => ({}));

    const envKey = Deno.env.get("DODO_PAYMENTS_API_KEY")?.trim();
    const bodyKey = typeof body.api_key === "string" ? body.api_key.trim() : "";
    const apiKey = envKey || bodyKey;
    if (!apiKey) {
      return new Response(
        JSON.stringify({
          error:
            "DODO_PAYMENTS_API_KEY missing: set Supabase secret or pass api_key only for local dev",
        }),
        { status: 503, headers: { ...cors, "Content-Type": "application/json" } },
      );
    }

    const returnUrl = typeof body.return_url === "string" ? body.return_url : "";
    if (!returnUrl) {
      return new Response(JSON.stringify({ error: "return_url is required" }), {
        status: 400,
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }

    const defaultProductId = Deno.env.get("DODO_PAYMENTS_DEFAULT_PRODUCT_ID");
    let productCart = body.product_cart;
    if (!Array.isArray(productCart) || productCart.length === 0) {
      if (!defaultProductId) {
        return new Response(
          JSON.stringify({
            error:
              "Provide product_cart or set Supabase secret DODO_PAYMENTS_DEFAULT_PRODUCT_ID (pay-what-you-want product recommended for variable artwork prices)",
          }),
          { status: 400, headers: { ...cors, "Content-Type": "application/json" } },
        );
      }
      const rawAmount = body.amount_inr;
      const amountInr = typeof rawAmount === "number" ? rawAmount : Number(rawAmount);
      if (Number.isFinite(amountInr) && amountInr > 0) {
        // INR minor unit = paise (Dodo expects smallest currency unit)
        const amountPaise = Math.round(amountInr * 100);
        productCart = [{ product_id: defaultProductId, quantity: 1, amount: amountPaise }];
      } else {
        productCart = [{ product_id: defaultProductId, quantity: 1 }];
      }
    }

    const payload: Record<string, unknown> = {
      product_cart: productCart,
      return_url: returnUrl,
    };

    const billing = normalizeBillingAddress(body.billing_address);
    if (billing) {
      payload.billing_address = billing;
    }

    const customer: Record<string, unknown> =
      body.customer && typeof body.customer === "object" && body.customer !== null
        ? { ...(body.customer as Record<string, unknown>) }
        : {};
    if (user.email && customer.email == null) {
      customer.email = user.email;
    }
    if (Object.keys(customer).length > 0) {
      payload.customer = customer;
    }
    payload.metadata = {
      ...(typeof body.metadata === "object" && body.metadata !== null
        ? (body.metadata as Record<string, unknown>)
        : {}),
      artwork_id: body.artwork_id,
      supabase_user_id: user.id,
    };

    const url = `${dodoBaseUrl()}/checkouts`;
    const dodoRes = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify(payload),
    });

    const text = await dodoRes.text();
    let data: unknown;
    try {
      data = text ? JSON.parse(text) : {};
    } catch {
      data = { raw: text };
    }

    if (!dodoRes.ok) {
      return new Response(
        JSON.stringify({ error: "Dodo API error", details: data }),
        {
          status: dodoRes.status >= 400 && dodoRes.status < 600 ? dodoRes.status : 502,
          headers: { ...cors, "Content-Type": "application/json" },
        },
      );
    }

    const d = data as Record<string, unknown>;
    const checkoutUrl =
      (typeof d.checkout_url === "string" && d.checkout_url) ||
      (typeof d.url === "string" && d.url) ||
      (typeof d.hosted_url === "string" && d.hosted_url) ||
      null;

    return new Response(
      JSON.stringify({
        ...d,
        checkout_url: checkoutUrl,
        hosted_url: checkoutUrl,
      }),
      { status: 200, headers: { ...cors, "Content-Type": "application/json" } },
    );
  } catch (e) {
    console.error(e);
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }
});
