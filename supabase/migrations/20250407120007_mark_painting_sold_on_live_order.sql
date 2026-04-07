-- When a non-demo order completes, mark the linked painting as sold (single-sale in live mode).
-- Safe to apply only if public.orders and public.paintings exist with expected columns.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'orders'
  ) THEN
    RAISE NOTICE 'mark_painting_sold: public.orders missing, skip';
    RETURN;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'paintings'
  ) THEN
    RAISE NOTICE 'mark_painting_sold: public.paintings missing, skip';
    RETURN;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'artwork_id'
  ) THEN
    RAISE NOTICE 'mark_painting_sold: orders.artwork_id missing, skip';
    RETURN;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'paintings' AND column_name = 'is_sold'
  ) THEN
    RAISE NOTICE 'mark_painting_sold: paintings.is_sold missing, skip';
    RETURN;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'paintings' AND column_name = 'is_for_sale'
  ) THEN
    RAISE NOTICE 'mark_painting_sold: paintings.is_for_sale missing, skip';
    RETURN;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'purchase_mode'
  ) THEN
    RAISE NOTICE 'mark_painting_sold: orders.purchase_mode missing, skip';
    RETURN;
  END IF;

  CREATE OR REPLACE FUNCTION public.artyug_mark_painting_sold_on_live_order()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public
  AS $fn$
  DECLARE
    mode text;
  BEGIN
    IF NEW.status IS DISTINCT FROM 'completed' THEN
      RETURN NEW;
    END IF;
    IF NEW.artwork_id IS NULL THEN
      RETURN NEW;
    END IF;
    mode := lower(coalesce(NEW.purchase_mode::text, ''));
    IF mode = 'demo' OR mode = 'test' THEN
      RETURN NEW;
    END IF;
    UPDATE public.paintings
    SET is_sold = true,
        is_for_sale = false
    WHERE id = NEW.artwork_id;
    RETURN NEW;
  END;
  $fn$;

  DROP TRIGGER IF EXISTS trg_artyug_orders_mark_painting_sold ON public.orders;
  CREATE TRIGGER trg_artyug_orders_mark_painting_sold
    AFTER INSERT OR UPDATE OF status ON public.orders
    FOR EACH ROW
    WHEN (NEW.status = 'completed')
    EXECUTE PROCEDURE public.artyug_mark_painting_sold_on_live_order();
END $$;
