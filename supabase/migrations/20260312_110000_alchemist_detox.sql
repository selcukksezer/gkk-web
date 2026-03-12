-- Migration: 20260312_110000_alchemist_detox.sql
-- Description: RPC for alchemists to claim a daily free Minor Detox potion

CREATE OR REPLACE FUNCTION claim_alchemist_detox()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_player record;
  v_item_id uuid;
  v_last_claim timestamptz;
  v_now timestamptz := NOW();
BEGIN
  -- 1. Check player class
  EXECUTE 'SELECT * FROM public.users WHERE auth_id = $1' INTO v_player USING v_user_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Player not found');
  END IF;

  IF (v_player).character_class IS DISTINCT FROM 'alchemist' THEN
    RETURN json_build_object('success', false, 'message', 'Only Alchemists can claim this.');
  END IF;

  -- 2. Check cooldown (24 hours) from custom fields or a new field.
  -- We will store the timestamp in the JSONB custom_fields column.
  v_last_claim := (v_player.custom_fields->>'last_alchemist_detox_claim')::timestamptz;
  
  IF v_last_claim IS NOT NULL AND v_now < (v_last_claim + INTERVAL '24 hours') THEN
    RETURN json_build_object('success', false, 'message', 'You can only claim this once per 24 hours. Try again later.');
  END IF;

  -- 3. Get the item_id for Minor Detox Potion
  -- Minor Detox is usually 'item_potion_detox_minor' or 'potion_antidote_minor'
  -- Let's check the items table. If we assume 'potion_antidote_minor' or 'potion_detox_minor'.
  EXECUTE 'SELECT id FROM public.items WHERE item_id = $1 OR item_id = $2 LIMIT 1' INTO v_item_id
    USING 'potion_antidote', 'potion_antidote_minor';
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Detox potion item not found in database.');
  END IF;

  -- 4. Add item to inventory
  PERFORM add_item_to_inventory(v_user_id, v_item_id, 1);

  -- 5. Update last claim time (use dynamic SQL to avoid compile-time dependency)
  EXECUTE 'UPDATE public.users SET custom_fields = jsonb_set(COALESCE(custom_fields, ''{}''::jsonb), ''{last_alchemist_detox_claim}'', to_jsonb($1)) WHERE auth_id = $2'
    USING v_now, v_user_id;

  RETURN json_build_object('success', true, 'message', 'Minor Detox claimed successfully!');
END;
$$;