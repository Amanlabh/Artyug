// Deploy: supabase functions deploy create-stripe-checkout
// Secrets: supabase secrets set STRIPE_SECRET_KEY=sk_live_... or sk_test_...

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

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

    const secret = Deno.env.get("STRIPE_SECRET_KEY");
    if (!secret) {
      return new Response(
        JSON.stringify({ error: "STRIPE_SECRET_KEY secret is not set" }),
        { status: 503, headers: { ...cors, "Content-Type": "application/json" } },
      );
    }

    const body = await req.json().catch(() => ({}));
    const artworkTitle = typeof body.artwork_title === "string"
      ? body.artwork_title.trim()
      : "";
    const artworkId = typeof body.artwork_id === "string" ? body.artwork_id.trim() : "";
    const amountInr = typeof body.amount_inr === "number" && Number.isFinite(body.amount_inr)
      ? body.amount_inr
      : NaN;

    if (!artworkTitle || !artworkId || !(amountInr > 0)) {
      return new Response(
        JSON.stringify({ error: "artwork_id, artwork_title, and amount_inr are required" }),
        { status: 400, headers: { ...cors, "Content-Type": "application/json" } },
      );
    }

    const successUrl =
      typeof body.success_url === "string" && body.success_url.length > 0
        ? body.success_url
        : typeof body.redirect_url === "string"
        ? body.redirect_url
        : "";
    const cancelUrl =
      typeof body.cancel_url === "string" && body.cancel_url.length > 0
        ? body.cancel_url
        : successUrl;

    if (!successUrl) {
      return new Response(JSON.stringify({ error: "success_url or redirect_url is required" }), {
        status: 400,
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }

    const unitAmountPaise = Math.round(amountInr * 100);
    if (unitAmountPaise < 50) {
      return new Response(JSON.stringify({ error: "amount too small for Stripe (min ~₹0.50)" }), {
        status: 400,
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }

    const form = new URLSearchParams();
    form.set("mode", "payment");
    form.set("success_url", successUrl);
    form.set("cancel_url", cancelUrl || successUrl);
    form.set("client_reference_id", artworkId);
    form.set("metadata[artwork_id]", artworkId);
    form.set("metadata[supabase_user_id]", user.id);
    form.set("line_items[0][quantity]", "1");
    form.set("line_items[0][price_data][currency]", "inr");
    form.set("line_items[0][price_data][product_data][name]", artworkTitle.slice(0, 120));
    form.set("line_items[0][price_data][unit_amount]", String(unitAmountPaise));

    const stripeRes = await fetch("https://api.stripe.com/v1/checkout/sessions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${secret}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: form,
    });

    const data = await stripeRes.json().catch(() => ({}));

    if (!stripeRes.ok) {
      return new Response(
        JSON.stringify({ error: "Stripe API error", details: data }),
        {
          status: stripeRes.status >= 400 && stripeRes.status < 600 ? stripeRes.status : 502,
          headers: { ...cors, "Content-Type": "application/json" },
        },
      );
    }

    const url = (data as { url?: string }).url;
    return new Response(
      JSON.stringify({
        ...data,
        hosted_url: url,
        checkout_url: url,
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
