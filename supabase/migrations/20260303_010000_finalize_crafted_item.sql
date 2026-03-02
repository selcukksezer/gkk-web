-- Migration: finalize crafted item when completes_at is reached
-- Generated: 2026-03-03 01:00:00

-- Create RPC to finalize a craft when its completion time is reached.
-- This decides success/failure based on crafting_recipes.success_rate

DROP FUNCTION IF EXISTS public.finalize_crafted_item(uuid);

CREATE FUNCTION public.finalize_crafted_item(p_queue_item_id uuid)
RETURNS table (processed boolean, message text, success boolean, success_rate double precision, roll double precision)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_queue public.craft_queue%ROWTYPE;
  v_recipe public.crafting_recipes%ROWTYPE;
  v_success_rate double precision;
  v_roll double precision;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Lock the row to avoid race conditions when multiple clients attempt finalize simultaneously
  SELECT * FROM public.craft_queue WHERE id = p_queue_item_id AND user_id = v_user_id FOR UPDATE INTO v_queue;
  IF v_queue.id IS NULL THEN
    RETURN QUERY SELECT false, 'Queue item not found or unauthorized'::text, NULL::boolean, NULL::double precision, NULL::double precision;
    RETURN;
  END IF;

  -- If it's already failed or processed, return as processed
  IF v_queue.failed THEN
    RETURN QUERY SELECT true, 'Already failed'::text, false, NULL::double precision, NULL::double precision;
    RETURN;
  END IF;
  IF v_queue.is_completed THEN
    RETURN QUERY SELECT true, 'Already completed'::text, true, NULL::double precision, NULL::double precision;
    RETURN;
  END IF;

  -- Only finalize if time has passed
  IF v_queue.completes_at > now() THEN
    RETURN QUERY SELECT false, 'Not ready'::text, NULL::boolean, NULL::double precision, NULL::double precision;
    RETURN;
  END IF;

  -- Load recipe to get success_rate
  SELECT * FROM public.crafting_recipes WHERE id = v_queue.recipe_id INTO v_recipe;
  v_success_rate := COALESCE(v_recipe.success_rate, 1.0);
  IF v_success_rate > 1 THEN
    v_success_rate := v_success_rate / 100.0;
  END IF;

  v_roll := random();

  IF v_roll > v_success_rate THEN
    -- Mark failed
    UPDATE public.craft_queue SET failed = true WHERE id = p_queue_item_id;
    RETURN QUERY SELECT true, 'Üretim başarısız'::text, false, v_success_rate, v_roll;
    RETURN;
  ELSE
    -- Mark completed so client can allow claim
    UPDATE public.craft_queue SET is_completed = true WHERE id = p_queue_item_id;
    RETURN QUERY SELECT true, 'Üretim tamamlandı'::text, true, v_success_rate, v_roll;
    RETURN;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.finalize_crafted_item(uuid) TO authenticated;
