-- Migration: create craft_queue table and crafting RPCs
-- Generated: 2026-03-01 02:00:00
-- Purpose: Complete crafting system - queue, recipes lookup, and claim functionality

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ====================================================================
-- TABLE: craft_queue
-- ====================================================================
DROP TABLE IF EXISTS public.craft_queue;

CREATE TABLE public.craft_queue (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL,
  recipe_id uuid NOT NULL,
  batch_count integer NOT NULL DEFAULT 1,
  started_at timestamp with time zone DEFAULT now(),
  completes_at timestamp with time zone NOT NULL,
  is_completed boolean DEFAULT false,
  claimed boolean DEFAULT false,
  failed boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT craft_queue_pkey PRIMARY KEY (id),
  CONSTRAINT craft_queue_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users (id) ON DELETE CASCADE,
  CONSTRAINT craft_queue_recipe_id_fkey FOREIGN KEY (recipe_id) REFERENCES public.crafting_recipes (id) ON DELETE RESTRICT
);

-- Indexes
CREATE INDEX idx_craft_queue_user_id ON public.craft_queue (user_id);
CREATE INDEX idx_craft_queue_user_completed ON public.craft_queue (user_id, is_completed);
CREATE INDEX idx_craft_queue_user_claimed ON public.craft_queue (user_id, claimed);
CREATE INDEX idx_craft_queue_completes_at ON public.craft_queue (completes_at);

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION public.update_craft_queue_timestamp()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_craft_queue_timestamp ON public.craft_queue;
CREATE TRIGGER trigger_craft_queue_timestamp
  BEFORE UPDATE ON public.craft_queue
  FOR EACH ROW
  EXECUTE FUNCTION public.update_craft_queue_timestamp();

-- ====================================================================
-- RPC: get_craft_queue
-- Returns all craft queue items for authenticated user
-- ====================================================================
DROP FUNCTION IF EXISTS public.get_craft_queue();

CREATE FUNCTION public.get_craft_queue()
RETURNS table (
  id uuid,
  recipe_id uuid,
  recipe_name text,
  recipe_icon text,
  batch_count integer,
  started_at timestamp with time zone,
  completes_at timestamp with time zone,
  is_completed boolean,
  claimed boolean,
  failed boolean,
  xp_reward integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  RETURN QUERY
  SELECT
    cq.id,
    cq.recipe_id,
    COALESCE(ii.name, cr.output_item_id) as recipe_name,
    ii.icon as recipe_icon,
    cq.batch_count,
    cq.started_at,
    cq.completes_at,
    (cq.is_completed OR cq.completes_at <= now()) as is_completed,
    cq.claimed,
    cq.failed,
    COALESCE(cr.xp_reward, 0) as xp_reward
  FROM public.craft_queue cq
  LEFT JOIN public.crafting_recipes cr ON cq.recipe_id = cr.id
  LEFT JOIN public.items ii ON ii.id = cr.output_item_id
  WHERE cq.user_id = v_user_id
  ORDER BY cq.started_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_craft_queue() TO authenticated;

-- ====================================================================
-- RPC: get_craft_recipes
-- Returns craft recipes filtered by user level with item metadata
-- ====================================================================
DROP FUNCTION IF EXISTS public.get_craft_recipes(integer);

CREATE FUNCTION public.get_craft_recipes(p_user_level integer DEFAULT 1)
RETURNS table (
  id uuid,
  recipe_id uuid,
  name text,
  output_item_id text,
  output_name text,
  output_quantity integer,
  output_rarity text,
  item_type text,
  recipe_type text,
  required_level integer,
  production_time_seconds integer,
  success_rate double precision,
  xp_reward integer,
  ingredients jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    cr.id,
    cr.id as recipe_id,
    COALESCE(ii.name, cr.output_item_id) as name,
    cr.output_item_id,
    COALESCE(ii.name, cr.output_item_id) as output_name,
    1 as output_quantity,
    COALESCE(ii.rarity, 'common') as output_rarity,
    COALESCE(ii.type, 'accessory') as item_type,
    COALESCE(ii.production_building_type, 'workbench') as recipe_type,
    cr.required_level,
    COALESCE(cr.production_time_seconds, 30) as production_time_seconds,
    cr.success_rate,
    cr.xp_reward,
    cr.ingredients
  FROM public.crafting_recipes cr
  LEFT JOIN public.items ii ON ii.id = cr.output_item_id
  WHERE cr.required_level <= p_user_level
  ORDER BY cr.required_level ASC, cr.output_item_id ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_craft_recipes(integer) TO authenticated;

DROP FUNCTION IF EXISTS public.craft_item_async(uuid, uuid, integer);
DROP FUNCTION IF EXISTS public.craft_item_async(uuid, integer);

CREATE FUNCTION public.craft_item_async(
  p_recipe_id uuid,
  p_batch_count integer DEFAULT 1
)
RETURNS TABLE (
  success boolean,
  queue_item_id uuid,
  message text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_recipe crafting_recipes%ROWTYPE;
  v_queue_item craft_queue%ROWTYPE;
  v_completes_at timestamp with time zone;
  v_ingredient_item RECORD;
  v_required_qty integer;
  v_owned_qty integer;
BEGIN
  -- Verify user is authenticated
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, NULL::uuid, 'Not authenticated'::text;
    RETURN;
  END IF;

  -- Fetch recipe
  SELECT * FROM public.crafting_recipes WHERE id = p_recipe_id INTO v_recipe;
  IF v_recipe.id IS NULL THEN
    RETURN QUERY SELECT false, NULL::uuid, 'Recipe not found'::text;
    RETURN;
  END IF;

  -- Verify materials exist before deducting
  IF v_recipe.ingredients IS NOT NULL AND v_recipe.ingredients != 'null'::jsonb THEN
    FOR v_ingredient_item IN
      SELECT 
        jsonb_array_elements(v_recipe.ingredients) ->> 'item_id' as item_id,
        (jsonb_array_elements(v_recipe.ingredients) ->> 'quantity')::integer as quantity
    LOOP
      v_required_qty := (v_ingredient_item.quantity * p_batch_count);
      
      SELECT COALESCE(SUM(quantity), 0) INTO v_owned_qty
      FROM public.inventory
      WHERE user_id = v_user_id AND item_id = v_ingredient_item.item_id;
      
      IF v_owned_qty < v_required_qty THEN
        RETURN QUERY SELECT false, NULL::uuid, 
          'Insufficient material: ' || v_ingredient_item.item_id || ' (need ' || v_required_qty || ', have ' || v_owned_qty || ')'::text;
        RETURN;
      END IF;
    END LOOP;
  END IF;

  -- Deduct materials from inventory
  IF v_recipe.ingredients IS NOT NULL AND v_recipe.ingredients != 'null'::jsonb THEN
    FOR v_ingredient_item IN
      SELECT 
        jsonb_array_elements(v_recipe.ingredients) ->> 'item_id' as item_id,
        (jsonb_array_elements(v_recipe.ingredients) ->> 'quantity')::integer as quantity
    LOOP
      v_required_qty := (v_ingredient_item.quantity * p_batch_count);
      
      -- Deduct quantities from inventory in FIFO order (handle stacks)
      DECLARE
        v_remaining integer := v_required_qty;
        v_row RECORD;
        v_take integer;
      BEGIN
        FOR v_row IN
          SELECT row_id, quantity FROM public.inventory
          WHERE user_id = v_user_id AND item_id = v_ingredient_item.item_id
          ORDER BY created_at ASC
        LOOP
          EXIT WHEN v_remaining <= 0;
          v_take := LEAST(v_row.quantity, v_remaining);
          IF v_row.quantity > v_take THEN
            UPDATE public.inventory
            SET quantity = quantity - v_take, updated_at = now()
            WHERE row_id = v_row.row_id;
          ELSE
            DELETE FROM public.inventory WHERE row_id = v_row.row_id;
          END IF;
          v_remaining := v_remaining - v_take;
        END LOOP;
      END;
    END LOOP;
  END IF;

  -- Calculate completion time
  v_completes_at := now() + (v_recipe.production_time_seconds * p_batch_count) * INTERVAL '1 second';

  -- Insert into craft queue — roll will happen in finalize_crafted_item when timer expires
  INSERT INTO public.craft_queue (user_id, recipe_id, batch_count, completes_at, is_completed, claimed, failed)
  VALUES (v_user_id, p_recipe_id, p_batch_count, v_completes_at, false, false, false)
  RETURNING * INTO v_queue_item;

  RETURN QUERY SELECT true, v_queue_item.id, 'Craft started'::text;
END;
$$;

GRANT EXECUTE ON FUNCTION public.craft_item_async(uuid, integer) TO authenticated;

-- ====================================================================
-- RPC: claim_crafted_item
-- Mark craft queue item as claimed and add to inventory
-- ====================================================================
-- DROP both old and new signatures
DROP FUNCTION IF EXISTS public.claim_crafted_item(uuid, uuid);
DROP FUNCTION IF EXISTS public.claim_crafted_item(uuid);

CREATE FUNCTION public.claim_crafted_item(
  p_queue_item_id uuid
)
RETURNS TABLE (
  success boolean,
  message text,
  xp_awarded integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_queue craft_queue%ROWTYPE;
  v_recipe crafting_recipes%ROWTYPE;
  v_final_qty integer;
  v_add_res jsonb;
  v_is_stackable boolean;
  v_free_slots integer;
  v_success_rate double precision;
  v_roll double precision;
  v_xp integer;
BEGIN
  -- Verify user is authenticated
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'Not authenticated'::text, 0;
    RETURN;
  END IF;

  -- Fetch and lock queue item to avoid races
  SELECT * FROM public.craft_queue WHERE id = p_queue_item_id AND user_id = v_user_id FOR UPDATE INTO v_queue;
  IF v_queue.id IS NULL THEN
    RETURN QUERY SELECT false, 'Queue item not found or unauthorized'::text, 0;
    RETURN;
  END IF;

  -- Check if already claimed
  IF v_queue.claimed THEN
    RETURN QUERY SELECT false, 'Already claimed'::text, 0;
    RETURN;
  END IF;

  -- Fetch recipe to get output item
  SELECT * FROM public.crafting_recipes WHERE id = v_queue.recipe_id INTO v_recipe;

  -- Ensure the item is completed (either marked or time has passed)
  IF NOT v_queue.is_completed AND v_queue.completes_at > now() THEN
    RETURN QUERY SELECT false, 'Not ready to claim'::text, 0;
    RETURN;
  END IF;

  -- Validate output_item_id exists before attempting inventory add
  IF v_recipe.output_item_id IS NULL OR trim(v_recipe.output_item_id) = '' THEN
    RETURN QUERY SELECT false, 'Recipe output_item_id is missing'::text, 0;
    RETURN;
  END IF;

  -- Determine if item is stackable from catalog (decide at claim time)
  SELECT is_stackable INTO v_is_stackable FROM public.items WHERE id = v_recipe.output_item_id;
  IF v_is_stackable IS NULL THEN
    v_is_stackable := false;
  END IF;

  -- Compute final quantity to add (use batch_count)
  v_final_qty := COALESCE(v_queue.batch_count, 1);

  -- If the item hasn't been finalized yet but completion time passed, finalize it
  IF NOT v_queue.is_completed AND v_queue.completes_at <= now() THEN
    -- finalize_crafted_item will lock and set failed/is_completed deterministically
    PERFORM public.finalize_crafted_item(p_queue_item_id);
    -- re-load updated queue row
    SELECT * FROM public.craft_queue WHERE id = p_queue_item_id AND user_id = v_user_id INTO v_queue;
  END IF;

  -- If finalized as failed, return failure
  IF v_queue.failed THEN
    RETURN QUERY SELECT false, 'Üretim başarısız'::text, 0;
    RETURN;
  END IF;

  -- Calculate XP reward for successful production
  v_xp := COALESCE(v_recipe.xp_reward, 0) * v_final_qty;

  -- Add produced item to inventory via helper.
  -- If item is stackable, add once (may stack). If not, add one-by-one into separate slots.
  IF v_is_stackable THEN
    v_add_res := public.add_inventory_item_v2(
      jsonb_build_object('item_id', v_recipe.output_item_id, 'quantity', v_final_qty, 'allow_stack', true),
      NULL
    );

    -- Check if inventory add succeeded
    IF v_add_res IS NULL OR (v_add_res->>'success')::boolean IS NOT TRUE THEN
      RETURN QUERY SELECT false, COALESCE(v_add_res->>'error', 'Failed to add to inventory')::text, 0;
      RETURN;
    END IF;
  ELSE
    -- Non-stackable: insert v_final_qty times as separate items
    -- Check free slots first to avoid partial adds
    SELECT COUNT(*) INTO v_free_slots
    FROM generate_series(0, 19) AS s(slot)
    WHERE NOT EXISTS (
      SELECT 1 FROM public.inventory
      WHERE user_id = v_user_id AND slot_position = s.slot AND is_equipped = false
    );

    IF v_free_slots < GREATEST(1, v_final_qty) THEN
      RETURN QUERY SELECT false, 'Envanter dolu'::text, 0;
      RETURN;
    END IF;
    FOR i IN 1..GREATEST(1, v_final_qty) LOOP
      v_add_res := public.add_inventory_item_v2(
        jsonb_build_object('item_id', v_recipe.output_item_id, 'quantity', 1, 'allow_stack', false),
        NULL
      );
      IF v_add_res IS NULL OR (v_add_res->>'success')::boolean IS NOT TRUE THEN
        RETURN QUERY SELECT false, COALESCE(v_add_res->>'error', 'Failed to add non-stackable item to inventory')::text, 0;
        RETURN;
      END IF;
    END LOOP;
  END IF;

  -- Award XP to user if successful and return authoritative total XP
  DECLARE
    v_new_xp integer := NULL;
  BEGIN
    IF v_xp > 0 THEN
      UPDATE public.users
      SET xp = COALESCE(xp, 0) + v_xp
      WHERE auth_id = v_user_id
      RETURNING xp INTO v_new_xp;
    END IF;

    -- If DB returned new total XP, use that as the xp_awarded value
    IF v_new_xp IS NOT NULL THEN
      v_xp := v_new_xp;
    END IF;
  END;

  -- Remove queue item after successful claim
  DELETE FROM public.craft_queue WHERE id = p_queue_item_id;

  RETURN QUERY SELECT true, 'Item claimed and added to inventory'::text, v_xp;
END;
$$;

GRANT EXECUTE ON FUNCTION public.claim_crafted_item(uuid) TO authenticated;

-- ====================================================================
-- RLS Policies for craft_queue
-- ====================================================================
ALTER TABLE public.craft_queue ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_can_read_own_craft_queue" ON public.craft_queue;
CREATE POLICY "users_can_read_own_craft_queue"
  ON public.craft_queue FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "users_can_insert_own_craft_queue" ON public.craft_queue;
CREATE POLICY "users_can_insert_own_craft_queue"
  ON public.craft_queue FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "users_can_update_own_craft_queue" ON public.craft_queue;
CREATE POLICY "users_can_update_own_craft_queue"
  ON public.craft_queue FOR UPDATE
  USING (auth.uid() = user_id);

-- ====================================================================
-- Grant select on crafting_recipes to authenticated users
-- ====================================================================
GRANT SELECT ON public.crafting_recipes TO authenticated;
GRANT SELECT ON public.craft_queue TO authenticated;
