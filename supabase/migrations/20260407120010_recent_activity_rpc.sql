-- Provides a global "recent purchases" feed for the app.
-- Uses SECURITY DEFINER to bypass typical RLS restrictions on orders/certificates.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'orders'
  ) THEN
    RAISE NOTICE 'recent_activity_rpc: public.orders missing, skip';
    RETURN;
  END IF;

  -- Function returns only non-sensitive, display-safe columns.
  CREATE OR REPLACE FUNCTION public.artyug_recent_activity(limit_count integer DEFAULT 8)
  RETURNS TABLE (
    id uuid,
    artwork_id uuid,
    artwork_title text,
    artwork_media_url text,
    buyer_name text,
    amount numeric,
    currency text,
    created_at timestamptz,
    certificate_blockchain_hash text
  )
  LANGUAGE sql
  SECURITY DEFINER
  SET search_path = public
  AS $fn$
    SELECT
      o.id,
      o.artwork_id,
      o.artwork_title,
      o.artwork_media_url,
      o.buyer_name,
      o.amount,
      o.currency,
      o.created_at,
      c.blockchain_hash AS certificate_blockchain_hash
    FROM public.orders o
    LEFT JOIN public.certificates c
      ON c.id = o.certificate_id
    WHERE o.status = 'completed'
    ORDER BY o.created_at DESC
    LIMIT GREATEST(1, LEAST(COALESCE(limit_count, 8), 50));
  $fn$;

  GRANT EXECUTE ON FUNCTION public.artyug_recent_activity(integer) TO anon;
  GRANT EXECUTE ON FUNCTION public.artyug_recent_activity(integer) TO authenticated;
END $$;

