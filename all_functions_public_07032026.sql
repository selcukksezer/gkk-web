


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE OR REPLACE FUNCTION "public"."_facility_resource_index"("p_seed" bigint, "p_i" integer, "p_pool_len" integer) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_index_rng double precision;
    v_idx int;
BEGIN
    -- Use a second LCG to decorrelate index selection from rarity RNG.
    -- Constants: multiplier 48271 (Park-Miller), modulus 2147483647 (2^31-1)
    v_index_rng := ((p_seed + (p_i * 7)) * 48271.0 % 2147483647.0) / 2147483647.0;

    IF p_pool_len <= 0 THEN
        RETURN 0;
    END IF;

    v_idx := floor(v_index_rng * p_pool_len)::INT;

    IF v_idx < 0 THEN
        v_idx := 0;
    ELSIF v_idx >= p_pool_len THEN
        v_idx := p_pool_len - 1;
    END IF;

    RETURN v_idx;
END;
$$;


ALTER FUNCTION "public"."_facility_resource_index"("p_seed" bigint, "p_i" integer, "p_pool_len" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."_jsonb_to_int"("val" "jsonb", "default_val" integer DEFAULT 0) RETURNS integer
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
declare
    text_val text;
begin
    -- Check for null
    if val is null or val = 'null'::jsonb then
        return default_val;
    end if;
    
    -- Try direct cast first (for integer JSONB values)
    begin
        return (val)::int;
    exception when others then
        -- Try as numeric first (handles float JSONB like 1.0)
        begin
            return (val::numeric)::int;
        exception when others then
            -- Try as text first, then numeric, then int (handles string "1.0")
            begin
                text_val := val::text;
                -- Remove quotes if present
                text_val := trim(both '"' from text_val);
                return (text_val::numeric)::int;
            exception when others then
                return default_val;
            end;
        end;
    end;
end;
$$;


ALTER FUNCTION "public"."_jsonb_to_int"("val" "jsonb", "default_val" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."acknowledge_crafted_item"("p_queue_item_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid;
  v_row_count integer;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN false;
  END IF;

  DELETE FROM public.craft_queue WHERE id = p_queue_item_id AND user_id = v_user_id;
  GET DIAGNOSTICS v_row_count = ROW_COUNT;
  RETURN v_row_count > 0;
END;
$$;


ALTER FUNCTION "public"."acknowledge_crafted_item"("p_queue_item_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."add_inventory_item"("item_data" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
    v_item_id text;
    v_user_id uuid;
    v_quantity int;
    v_new_row jsonb;
begin
    -- Get User ID
    v_user_id := auth.uid();
    if v_user_id is null then
        return '{"success": false, "error": "Not authenticated"}'::jsonb;
    end if;

    -- Extract Key Data
    v_item_id := item_data->>'id';
    if v_item_id is null or v_item_id = '' then
        return '{"success": false, "error": "item_id is required"}'::jsonb;
    end if;
    
    -- Safe CAST for quantity (handles "1.0" string from JSON, floats, and integers)
    v_quantity := public._jsonb_to_int(item_data->'quantity', 1);

    -- 1. Upsert Item Definition (Ensure item exists in DB)
    -- We update the definition to match the client's latest data
    insert into public.items (
        id, name, description, icon, type, rarity, equip_slot,
        weapon_type, armor_type, material_type, potion_type,
        attack, defense, health, power, energy_restore, heal_amount,
        base_price, vendor_sell_price, can_enhance, max_enhancement,
        is_tradeable, is_stackable, max_stack,
        required_level, required_class, tolerance_increase, overdose_risk, production_building_type
    ) values (
        v_item_id,
        item_data->>'name',
        item_data->>'description',
        item_data->>'icon',
        item_data->>'item_type',
        item_data->>'rarity',
        item_data->>'equip_slot',
        item_data->>'weapon_type',
        item_data->>'armor_type',
        item_data->>'material_type',
        item_data->>'potion_type',
        public._jsonb_to_int(item_data->'attack', 0),
        public._jsonb_to_int(item_data->'defense', 0),
        public._jsonb_to_int(item_data->'health', 0),
        public._jsonb_to_int(item_data->'power', 0),
        public._jsonb_to_int(item_data->'energy_restore', 0),
        public._jsonb_to_int(item_data->'heal_amount', 0),
        public._jsonb_to_int(item_data->'base_price', 0),
        public._jsonb_to_int(item_data->'vendor_sell_price', 0),
        coalesce((item_data->>'can_enhance')::boolean, false),
        public._jsonb_to_int(item_data->'max_enhancement', 0),
        coalesce((item_data->>'is_tradeable')::boolean, true),
        coalesce((item_data->>'is_stackable')::boolean, true),
        public._jsonb_to_int(item_data->'max_stack', 999),
        public._jsonb_to_int(item_data->'required_level', 1),
        item_data->>'required_class',
        public._jsonb_to_int(item_data->'tolerance_increase', 0),
        coalesce((item_data->>'overdose_risk')::numeric, 0),
        item_data->>'production_building_type'
    )
    on conflict (id) do update set
        name = excluded.name,
        description = excluded.description,
        icon = excluded.icon,
        attack = excluded.attack,
        defense = excluded.defense,
        health = excluded.health,
        power = excluded.power,
        energy_restore = excluded.energy_restore,
        heal_amount = excluded.heal_amount,
        base_price = excluded.base_price,
        vendor_sell_price = excluded.vendor_sell_price,
        required_level = excluded.required_level,
        required_class = excluded.required_class,
        tolerance_increase = excluded.tolerance_increase,
        overdose_risk = excluded.overdose_risk,
        production_building_type = excluded.production_building_type
    where items.id = excluded.id;  -- Ensure we only update the matching row

    -- 2. Upsert Inventory Record
    -- Ensure required columns exist (migration checks)
    -- Note: ALTER TABLE cannot be executed inside a function transaction, so we handle this before the function
    -- For now, we'll ensure the insert works by using only columns that should exist
    
    -- Validate that item_id is not null (extracted above)
    if v_item_id is null or v_item_id = '' then
        return '{"success": false, "error": "item_id cannot be null or empty"}'::jsonb;
    end if;
    
    -- Check if item is stackable from items definition
    declare
        v_is_stackable boolean;
    begin
        select coalesce(is_stackable, true) into v_is_stackable
        from public.items
        where id = v_item_id;
        
        -- If item is stackable AND player already has it, increase quantity
        -- If item is NOT stackable (equipment), always insert new row
        if v_is_stackable and exists (select 1 from public.inventory where user_id = v_user_id and item_id = v_item_id) then
            update public.inventory
            set quantity = quantity + v_quantity,
                updated_at = now()
            where user_id = v_user_id and item_id = v_item_id
            returning to_jsonb(inventory.*) into v_new_row;
        else
            -- Insert new item (for non-stackable items or first-time stackable items)
            -- Handle case where old 'id' column might exist and need a value
            declare
                v_has_old_id_column boolean;
            begin
                -- Check if old 'id' text column exists
                select exists (
                    select 1 from information_schema.columns 
                    where table_schema = 'public' 
                    and table_name = 'inventory' 
                    and column_name = 'id' 
                    and data_type = 'text'
                ) into v_has_old_id_column;
                
                if v_has_old_id_column then
                    -- Insert with old 'id' column set to item_id value
                    insert into public.inventory (
                        user_id, item_id, id, quantity, enhancement_level, is_equipped, obtained_at
                    ) values (
                        v_user_id,
                        v_item_id,
                        v_item_id,  -- Set old 'id' column to item_id value
                        v_quantity,
                        public._jsonb_to_int(item_data->'enhancement_level', 0),
                        false,
                        extract(epoch from now())::bigint
                    )
                    returning to_jsonb(inventory.*) into v_new_row;
                else
                    -- Standard insert without old 'id' column
                    insert into public.inventory (
                        user_id, item_id, quantity, enhancement_level, is_equipped, obtained_at
                    ) values (
                        v_user_id,
                        v_item_id,
                        v_quantity,
                        public._jsonb_to_int(item_data->'enhancement_level', 0),
                        false,
                        extract(epoch from now())::bigint
                    )
                    returning to_jsonb(inventory.*) into v_new_row;
                end if;
            end;
        end if;
    end;

    return jsonb_build_object('success', true, 'data', v_new_row);
end;
$$;


ALTER FUNCTION "public"."add_inventory_item"("item_data" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."add_inventory_item_v2"("item_data" "jsonb", "p_slot_position" integer DEFAULT NULL::integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_auth_id UUID;
  v_item_id TEXT;
  v_quantity INTEGER;
  v_is_stackable BOOLEAN;
  v_catalog_stack BOOLEAN;
  v_slot INTEGER;
  v_existing RECORD;
  v_row_id UUID;
BEGIN
  v_auth_id := auth.uid();
  IF v_auth_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  v_item_id := item_data->>'item_id';
  v_quantity := COALESCE((item_data->>'quantity')::INTEGER, 1);

  -- Allow caller (claim) to control stacking via item_data.allow_stack (default true)
  v_is_stackable := COALESCE((item_data->>'allow_stack')::boolean, true);

  -- Enforce catalog: if item is not stackable in items table, do NOT stack regardless of caller flag
  SELECT is_stackable INTO v_catalog_stack FROM public.items WHERE id = v_item_id;
  IF v_catalog_stack IS NULL THEN
    v_catalog_stack := false;
  END IF;

  v_is_stackable := v_is_stackable AND v_catalog_stack;

  IF v_item_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'item_id required');
  END IF;
  -- Stack behavior respecting catalog.max_stack:
  IF v_is_stackable THEN
    -- Get max stack size for item from catalog
    DECLARE
      v_max_stack INTEGER := 0;
      v_existing_space INTEGER := 0;
      v_space INTEGER := 0;
      v_add INTEGER := 0;
      v_required_slots INTEGER := 0;
      v_free_slots INTEGER := 0;
      v_rows RECORD;
    BEGIN
      SELECT COALESCE(max_stack, 999999) INTO v_max_stack FROM public.items WHERE id = v_item_id;
      IF v_max_stack IS NULL OR v_max_stack <= 0 THEN
        v_max_stack := 999999;
      END IF;

      -- Total available space in existing stacks for this item
      SELECT COALESCE(SUM(GREATEST(0, v_max_stack - quantity)), 0) INTO v_existing_space
      FROM public.inventory
      WHERE user_id = v_auth_id AND item_id = v_item_id AND is_equipped = false;

      -- If all quantity fits into existing stacks, just fill them
      IF v_quantity <= v_existing_space THEN
        FOR v_rows IN
          SELECT row_id, quantity FROM public.inventory
          WHERE user_id = v_auth_id AND item_id = v_item_id AND is_equipped = false
          ORDER BY created_at ASC
        LOOP
          EXIT WHEN v_quantity <= 0;
          v_space := v_max_stack - v_rows.quantity;
          IF v_space > 0 THEN
            v_add := LEAST(v_space, v_quantity);
            UPDATE public.inventory
            SET quantity = quantity + v_add, updated_at = NOW()
            WHERE row_id = v_rows.row_id;
            v_quantity := v_quantity - v_add;
          END IF;
        END LOOP;
        RETURN jsonb_build_object('success', true, 'action', 'stacked');
      END IF;

      -- Need new slots as well. Compute required new slots and ensure enough free slots exist
      v_required_slots := CEIL( (v_quantity - v_existing_space)::numeric / v_max_stack::numeric )::integer;
      SELECT COUNT(*) INTO v_free_slots FROM generate_series(0,19) AS s(slot)
      WHERE NOT EXISTS (
        SELECT 1 FROM public.inventory WHERE user_id = v_auth_id AND slot_position = s.slot AND is_equipped = false
      );

      IF v_free_slots < v_required_slots THEN
        RETURN jsonb_build_object('success', false, 'error', 'Envanter dolu');
      END IF;

      -- Fill existing stacks first
      FOR v_rows IN
        SELECT row_id, quantity FROM public.inventory
        WHERE user_id = v_auth_id AND item_id = v_item_id AND is_equipped = false
        ORDER BY created_at ASC
      LOOP
        EXIT WHEN v_quantity <= 0;
        v_space := v_max_stack - v_rows.quantity;
        IF v_space > 0 THEN
          v_add := LEAST(v_space, v_quantity);
          UPDATE public.inventory
          SET quantity = quantity + v_add, updated_at = NOW()
          WHERE row_id = v_rows.row_id;
          v_quantity := v_quantity - v_add;
        END IF;
      END LOOP;

      -- Insert new rows for remaining quantity
      WHILE v_quantity > 0 LOOP
        v_add := LEAST(v_max_stack, v_quantity);
        SELECT s.slot INTO v_slot FROM generate_series(0,19) AS s(slot)
        WHERE NOT EXISTS (
          SELECT 1 FROM public.inventory WHERE user_id = v_auth_id AND slot_position = s.slot AND is_equipped = false
        ) ORDER BY s.slot LIMIT 1;

        INSERT INTO public.inventory (user_id, item_id, quantity, slot_position, obtained_at)
        VALUES (v_auth_id, v_item_id, v_add, v_slot, EXTRACT(EPOCH FROM NOW())::BIGINT)
        RETURNING row_id INTO v_row_id;

        v_quantity := v_quantity - v_add;
      END LOOP;

      RETURN jsonb_build_object('success', true, 'action', 'stacked_inserted');
    END;
  END IF;

  -- Boş slot bul
  v_slot := p_slot_position;
  IF v_slot IS NULL THEN
    SELECT s.slot INTO v_slot
    FROM generate_series(0, 19) AS s(slot)
    WHERE NOT EXISTS (
      SELECT 1 FROM public.inventory
      WHERE user_id = v_auth_id AND slot_position = s.slot AND is_equipped = false
    )
    ORDER BY s.slot LIMIT 1;
  END IF;

  IF v_slot IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Envanter dolu');
  END IF;

  INSERT INTO public.inventory (user_id, item_id, quantity, slot_position, obtained_at)
  VALUES (v_auth_id, v_item_id, v_quantity, v_slot, EXTRACT(EPOCH FROM NOW())::BIGINT)
  RETURNING row_id INTO v_row_id;

  RETURN jsonb_build_object('success', true, 'row_id', v_row_id, 'slot_position', v_slot, 'action', 'inserted');
END;
$$;


ALTER FUNCTION "public"."add_inventory_item_v2"("item_data" "jsonb", "p_slot_position" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admit_to_hospital"("p_auth_id" "uuid", "p_duration_minutes" integer, "p_reason" "text") RETURNS TABLE("success" boolean, "hospital_until" timestamp without time zone, "release_time" bigint)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_release_time TIMESTAMP;
BEGIN
  v_release_time := NOW() + (p_duration_minutes || ' minutes')::INTERVAL;
  
  UPDATE public.users
  SET 
    hospital_until = v_release_time,
    hospital_reason = p_reason,
    updated_at = NOW()
  WHERE auth_id = p_auth_id;
  
  RETURN QUERY
  SELECT 
    TRUE,
    v_release_time,
    EXTRACT(EPOCH FROM v_release_time)::BIGINT;
END;
$$;


ALTER FUNCTION "public"."admit_to_hospital"("p_auth_id" "uuid", "p_duration_minutes" integer, "p_reason" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admit_to_prison"("p_facility_id" "uuid", "p_suspicion_level" integer DEFAULT 80) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
    v_sentence_hours INT;
    v_release_time TIMESTAMPTZ;
    v_prison_record_id UUID;
BEGIN
    v_user_id := auth.uid();

    IF NOT EXISTS (
        SELECT 1 FROM public.facilities 
        WHERE id = p_facility_id AND user_id = v_user_id
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Facility not found');
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.prison_records
        WHERE user_id = v_user_id AND released_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Already in prison');
    END IF;

    v_sentence_hours := 2 + (p_suspicion_level / 10);
    v_release_time := NOW() + (v_sentence_hours || ' hours')::INTERVAL;

    INSERT INTO public.prison_records (
        user_id, facility_id, reason, sentence_hours, admitted_at, released_at
    ) VALUES (
        v_user_id, p_facility_id, 'High suspicion at facility operations', v_sentence_hours, NOW(), v_release_time
    ) RETURNING id INTO v_prison_record_id;

    UPDATE public.facilities
    SET suspicion_level = 0
    WHERE id = p_facility_id;

    UPDATE public.users
    SET in_prison = true,
        prison_until = v_release_time
    WHERE auth_id = v_user_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Admitted to prison',
        'prison_record_id', v_prison_record_id,
        'sentence_hours', v_sentence_hours,
        'release_time', v_release_time
    );
END;
$$;


ALTER FUNCTION "public"."admit_to_prison"("p_facility_id" "uuid", "p_suspicion_level" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."bribe_officials"("p_facility_type" "text", "p_amount_gems" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
    v_user_uuid UUID;
    v_current_gems INT;
    v_global_suspicion INT;
    v_bribe_time TIMESTAMPTZ;
BEGIN
    v_user_id := auth.uid();
    
    RAISE LOG '[bribe_officials] User: %, Facility Type: %, Gems: %', v_user_id, p_facility_type, p_amount_gems;
    
    -- Get user's actual UUID from users table using auth_id
    SELECT id, gems, global_suspicion_level 
    INTO v_user_uuid, v_current_gems, v_global_suspicion
    FROM public.users 
    WHERE auth_id = v_user_id;
    
    IF v_user_uuid IS NULL THEN
        RAISE LOG '[bribe_officials] User not found with auth_id: %', v_user_id;
        RETURN jsonb_build_object('success', false, 'error', 'User not found');
    END IF;
    
    IF v_current_gems < p_amount_gems THEN
        RETURN jsonb_build_object('success', false, 'error', 'Insufficient gems');
    END IF;
    
    -- Check if there's any global suspicion to bribe away
    IF v_global_suspicion <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'No suspicion to bribe away');
    END IF;
    
    -- Capture bribe timestamp
    v_bribe_time := NOW();
    
    -- Deduct gems, reset global_suspicion to 0, and set last_bribe_at to current time
    UPDATE public.users
    SET gems = gems - p_amount_gems,
        global_suspicion_level = 0,
        last_bribe_at = v_bribe_time,
        updated_at = NOW()
    WHERE auth_id = v_user_id;
    
    RAISE LOG '[bribe_officials] Successfully bribed at %. Last bribe timestamp: %, gems spent: %', v_bribe_time, v_bribe_time, p_amount_gems;
    
    RETURN jsonb_build_object(
        'success', true, 
        'message', 'Bribed successfully',
        'new_suspicion', 0,
        'gems_spent', p_amount_gems,
        'last_bribe_at', v_bribe_time,
        'global_suspicion_before', v_global_suspicion,
        'global_suspicion_after', 0
    );
END;
$$;


ALTER FUNCTION "public"."bribe_officials"("p_facility_type" "text", "p_amount_gems" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."buy_shop_item"("p_item_id" "text", "p_currency" "text" DEFAULT 'gold'::"text", "p_price" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_auth_id UUID;
  v_user_row RECORD;
  v_new_balance INTEGER;
  v_inv_row_id UUID;
  v_slot INTEGER;
BEGIN
  -- 1) Kimlik doğrula
  v_auth_id := auth.uid();
  IF v_auth_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- 2) public.users'tan bakiye al (auth_id ile)
  SELECT id, gold, gems INTO v_user_row
  FROM public.users
  WHERE auth_id = v_auth_id
  LIMIT 1;

  IF v_user_row IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  -- 3) Bakiye kontrolü ve düşüşü
  IF p_currency = 'gems' THEN
    IF v_user_row.gems < p_price THEN
      RETURN jsonb_build_object('success', false, 'error', 'Yetersiz gem');
    END IF;
    v_new_balance := v_user_row.gems - p_price;
    UPDATE public.users SET gems = v_new_balance WHERE auth_id = v_auth_id;
  ELSIF p_currency = 'gold' THEN
    IF v_user_row.gold < p_price THEN
      RETURN jsonb_build_object('success', false, 'error', 'Yetersiz altın');
    END IF;
    v_new_balance := v_user_row.gold - p_price;
    UPDATE public.users SET gold = v_new_balance WHERE auth_id = v_auth_id;
  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'Unknown currency: ' || p_currency);
  END IF;

  -- 4) İlk boş slot bul (0-19)
  SELECT s.slot
  INTO v_slot
  FROM generate_series(0, 19) AS s(slot)
  WHERE NOT EXISTS (
    SELECT 1 FROM public.inventory
    WHERE user_id = v_auth_id
      AND slot_position = s.slot
      AND is_equipped = false
  )
  ORDER BY s.slot
  LIMIT 1;

  -- v_slot NULL ise envanter dolu
  IF v_slot IS NULL THEN
    -- Bakiye geri al
    IF p_currency = 'gems' THEN
      UPDATE public.users SET gems = v_user_row.gems WHERE auth_id = v_auth_id;
    ELSE
      UPDATE public.users SET gold = v_user_row.gold WHERE auth_id = v_auth_id;
    END IF;
    RETURN jsonb_build_object('success', false, 'error', 'Envanter dolu');
  END IF;

  -- 5) Envantere ekle — user_id = Auth UUID (auth.uid())
  INSERT INTO public.inventory (user_id, item_id, quantity, slot_position, obtained_at)
  VALUES (v_auth_id, p_item_id, 1, v_slot, EXTRACT(EPOCH FROM NOW())::BIGINT)
  RETURNING row_id INTO v_inv_row_id;

  RETURN jsonb_build_object(
    'success', true,
    'row_id', v_inv_row_id,
    'item_id', p_item_id,
    'slot_position', v_slot,
    'new_balance', v_new_balance,
    'currency', p_currency
  );
END;
$$;


ALTER FUNCTION "public"."buy_shop_item"("p_item_id" "text", "p_currency" "text", "p_price" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."buy_shop_item"("p_item_id" "text", "p_currency" "text", "p_price" bigint, "p_quantity" integer DEFAULT 1) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
    v_item RECORD;
    v_current_gold BIGINT;
    v_current_gems BIGINT;
    v_old_gold BIGINT;
    v_old_gems BIGINT;
    v_inventory_slot INT;
    v_existing_row RECORD;
    v_new_quantity INT;
    v_capacity INT := 20;
    v_occupied INT;
BEGIN
    -- Auth check
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    -- Validate quantity
    IF p_quantity < 1 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid quantity');
    END IF;

    -- Validate item exists
    SELECT id, name, base_price, is_stackable, max_stack, type AS item_type,
           rarity, description, icon, equip_slot, attack, defense, health, power,
           energy_restore, health_restore, can_enhance, max_enhancement, required_level,
           is_tradeable, vendor_sell_price, tolerance_increase
    INTO v_item
    FROM public.items
    WHERE id = p_item_id;

    IF v_item.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Item not found');
    END IF;

    -- Get current currency balance
    SELECT gold, gems INTO v_current_gold, v_current_gems
    FROM public.users
    WHERE auth_id = v_user_id OR id = v_user_id
    LIMIT 1;

    v_old_gold := v_current_gold;
    v_old_gems := v_current_gems;

    -- Check balance
    IF p_currency = 'gold' THEN
        IF v_current_gold < p_price THEN
            RETURN jsonb_build_object('success', false, 'error', 'Insufficient gold');
        END IF;
    ELSIF p_currency = 'gems' THEN
        IF v_current_gems < p_price THEN
            RETURN jsonb_build_object('success', false, 'error', 'Insufficient gems');
        END IF;
    ELSE
        RETURN jsonb_build_object('success', false, 'error', 'Invalid currency');
    END IF;

    -- Deduct currency — Godot: State.gold -= price
    IF p_currency = 'gold' THEN
        UPDATE public.users
        SET gold = gold - p_price
        WHERE auth_id = v_user_id OR id = v_user_id;
    ELSE
        UPDATE public.users
        SET gems = gems - p_price
        WHERE auth_id = v_user_id OR id = v_user_id;
    END IF;

    -- Try to add item to inventory with stacking — Godot: inventory_manager.add_item(purchase_item)
    BEGIN
        IF v_item.is_stackable THEN
            -- Check if player already has this item (for stacking)
            SELECT row_id, quantity INTO v_existing_row
            FROM public.inventory
            WHERE user_id = v_user_id AND item_id = p_item_id AND NOT is_equipped
            LIMIT 1;

            IF v_existing_row.row_id IS NOT NULL THEN
                -- Stack: update quantity of existing row
                v_new_quantity := LEAST(
                    v_existing_row.quantity + p_quantity,
                    COALESCE(v_item.max_stack, 999)
                );
                UPDATE public.inventory
                SET quantity = v_new_quantity,
                    updated_at = NOW()
                WHERE row_id = v_existing_row.row_id;
            ELSE
                -- No existing stack — find free slot
                SELECT COUNT(*) INTO v_occupied
                FROM public.inventory
                WHERE user_id = v_user_id AND NOT is_equipped;

                IF v_occupied >= v_capacity THEN
                    -- Revert currency — Godot: State.gold = old_gold
                    IF p_currency = 'gold' THEN
                        UPDATE public.users SET gold = v_old_gold WHERE auth_id = v_user_id OR id = v_user_id;
                    ELSE
                        UPDATE public.users SET gems = v_old_gems WHERE auth_id = v_user_id OR id = v_user_id;
                    END IF;
                    RETURN jsonb_build_object('success', false, 'error', 'Inventory full');
                END IF;

                -- Find first empty slot
                SELECT s INTO v_inventory_slot
                FROM generate_series(0, v_capacity - 1) s
                WHERE s NOT IN (
                    SELECT slot_position FROM public.inventory
                    WHERE user_id = v_user_id AND slot_position IS NOT NULL
                )
                LIMIT 1;

                INSERT INTO public.inventory (
                    user_id, item_id, quantity, slot_position, is_equipped
                ) VALUES (
                    v_user_id, p_item_id, p_quantity, COALESCE(v_inventory_slot, 0), false
                );
            END IF;
        ELSE
            -- Non-stackable: insert new row per unit
            SELECT COUNT(*) INTO v_occupied
            FROM public.inventory
            WHERE user_id = v_user_id AND NOT is_equipped;

            IF v_occupied + p_quantity > v_capacity THEN
                -- Revert currency
                IF p_currency = 'gold' THEN
                    UPDATE public.users SET gold = v_old_gold WHERE auth_id = v_user_id OR id = v_user_id;
                ELSE
                    UPDATE public.users SET gems = v_old_gems WHERE auth_id = v_user_id OR id = v_user_id;
                END IF;
                RETURN jsonb_build_object('success', false, 'error', 'Inventory full');
            END IF;

            FOR i IN 1..p_quantity LOOP
                SELECT s INTO v_inventory_slot
                FROM generate_series(0, v_capacity - 1) s
                WHERE s NOT IN (
                    SELECT slot_position FROM public.inventory
                    WHERE user_id = v_user_id AND slot_position IS NOT NULL
                )
                LIMIT 1;

                INSERT INTO public.inventory (
                    user_id, item_id, quantity, slot_position, is_equipped
                ) VALUES (
                    v_user_id, p_item_id, 1, COALESCE(v_inventory_slot, i - 1), false
                );
            END LOOP;
        END IF;

    EXCEPTION WHEN OTHERS THEN
        -- Revert currency on any inventory error — Godot: _show_error + revert
        IF p_currency = 'gold' THEN
            UPDATE public.users SET gold = v_old_gold WHERE auth_id = v_user_id OR id = v_user_id;
        ELSE
            UPDATE public.users SET gems = v_old_gems WHERE auth_id = v_user_id OR id = v_user_id;
        END IF;
        RETURN jsonb_build_object('success', false, 'error', 'Failed to add item to inventory: ' || SQLERRM);
    END;

    RETURN jsonb_build_object('success', true, 'item_id', p_item_id, 'quantity', p_quantity);
END;
$$;


ALTER FUNCTION "public"."buy_shop_item"("p_item_id" "text", "p_currency" "text", "p_price" bigint, "p_quantity" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calculate_global_suspicion"("p_user_id" "uuid") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_active_count INT;
    v_level_sum INT;
    v_immunity TIMESTAMPTZ;
    v_risk FLOAT;
BEGIN
    -- Check Immunity
    SELECT suspicion_immunity_until INTO v_immunity FROM public.users WHERE id = p_user_id;
    
    IF v_immunity > NOW() THEN
        RETURN 0;
    END IF;

    -- Calculate Active Facilities (Production started less than 1 hour ago)
    SELECT 
        COUNT(*),
        COALESCE(SUM(level), 0)
    INTO 
        v_active_count,
        v_level_sum
    FROM public.facilities
    WHERE user_id = p_user_id
        AND production_started_at IS NOT NULL
        AND production_started_at > NOW() - INTERVAL '1 hour';
        
    -- Formula: (Active Count * 5) + (Level Sum * 0.5)
    -- Example: 4 Active (Lvl 1) -> 20 + 2 = 22%
    -- Example: 10 Active (Lvl 5) -> 50 + 25 = 75%
    
    v_risk := (v_active_count * 5.0) + (v_level_sum * 0.5);
    
    -- Clamp and Return
    IF v_risk > 100 THEN v_risk := 100; END IF;
    IF v_risk < 0 THEN v_risk := 0; END IF;
    
    RETURN CAST(v_risk AS INT);
END;
$$;


ALTER FUNCTION "public"."calculate_global_suspicion"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calculate_offline_production"("p_facility_id" "uuid") RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_facility public.facilities%ROWTYPE;
  v_queue_count INT;
  v_offline_hours INT;
  v_production_per_hour INT;
  v_total_production INT;
BEGIN
  -- Facility verisini al
  SELECT * INTO v_facility 
  FROM public.facilities 
  WHERE id = p_facility_id;
  
  IF NOT FOUND THEN
    RETURN 0;
  END IF;
  
  -- Queue'deki aktif işleri say
  SELECT COUNT(*) INTO v_queue_count
  FROM public.facility_queue
  WHERE facility_id = p_facility_id 
    AND (status = 'in_progress' OR status IS NULL);
  
  -- Queue dolu mu kontrol et
  IF v_queue_count >= 10 THEN
    RETURN 0;
  END IF;
  
  -- Offline saat hesapla (max 24 saat)
  v_offline_hours := LEAST(24, 
    EXTRACT(EPOCH FROM (NOW() - v_facility.last_production_collected_at)) / 3600
  );
  
  -- Production per hour: level * 50 + workers * 10
  v_production_per_hour := (v_facility.level * 50) + (v_facility.workers * 10);
  
  -- Toplam offline production
  v_total_production := v_production_per_hour * v_offline_hours;
  
  RETURN LEAST(v_total_production, v_facility.offline_production_cap);
END;
$$;


ALTER FUNCTION "public"."calculate_offline_production"("p_facility_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cancel_craft_item"("p_queue_item_id" "uuid") RETURNS TABLE("success" boolean, "message" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid;
  v_queue craft_queue%ROWTYPE;
BEGIN
  -- Verify user is authenticated
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'Not authenticated'::text;
    RETURN;
  END IF;

  -- Fetch queue item - ensure it belongs to authenticated user
  SELECT * FROM public.craft_queue WHERE id = p_queue_item_id AND user_id = v_user_id INTO v_queue;
  IF v_queue.id IS NULL THEN
    RETURN QUERY SELECT false, 'Queue item not found or unauthorized'::text;
    RETURN;
  END IF;

  -- Check if already completed or claimed
  IF v_queue.is_completed OR v_queue.claimed THEN
    RETURN QUERY SELECT false, 'Cannot cancel completed or claimed item'::text;
    RETURN;
  END IF;

  -- Delete from queue (NO REFUND - as per requirement)
  DELETE FROM public.craft_queue WHERE id = p_queue_item_id;

  RETURN QUERY SELECT true, 'Craft cancelled (items NOT refunded)'::text;
END;
$$;


ALTER FUNCTION "public"."cancel_craft_item"("p_queue_item_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cancel_sell_order"("p_order_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
    v_order_record RECORD;
    v_slot INT;
BEGIN
    v_user_id := auth.uid();
    
    -- 1. Find Order
    SELECT * INTO v_order_record
    FROM public.market_orders
    WHERE id = p_order_id AND seller_id = v_user_id;
    
    IF v_order_record IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Order not found');
    END IF;
    
    -- 2. Check Inventory Space using Helper
    -- We'll assume the helper handles finding a slot
    -- If we support stacking on return (optional for v1), we'd check that here.
    
    v_slot := public._find_first_empty_slot(v_user_id);
    
    IF v_slot IS NULL THEN
         RETURN jsonb_build_object('success', false, 'error', 'Inventory full');
    END IF;

    -- 3. Restore Item
    INSERT INTO public.inventory (
       user_id, item_id, quantity, slot_position, 
       enhancement_level, obtained_at, is_equipped, row_id
    ) VALUES (
       v_user_id, 
       v_order_record.item_id, 
       v_order_record.quantity, 
       v_slot, 
       (v_order_record.item_data->>'enhancement_level')::int,
       (v_order_record.item_data->>'obtained_at')::bigint,
       FALSE,
       gen_random_uuid()
    );

    -- 4. Delete Order
    DELETE FROM public.market_orders WHERE id = p_order_id;
    
    RETURN jsonb_build_object('success', true);
END;
$$;


ALTER FUNCTION "public"."cancel_sell_order"("p_order_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_and_release_from_prison"("p_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_today TIMESTAMPTZ := NOW();
    v_prison_record RECORD;
    v_released_count INT := 0;
BEGIN
    FOR v_prison_record IN
        SELECT id, user_id FROM public.prison_records
        WHERE user_id = p_user_id
          AND released_at IS NOT NULL
          AND released_at <= v_today
          AND released_at > (SELECT COALESCE(MAX(released_at), '1900-01-01'::TIMESTAMPTZ) FROM public.prison_records 
                          WHERE user_id = p_user_id AND released_at < v_today)
    LOOP
        v_released_count := v_released_count + 1;
    END LOOP;
    
    IF v_released_count > 0 THEN
        UPDATE public.users
        SET in_prison = false,
            hospital_until = NULL
        WHERE id = p_user_id
          AND NOT EXISTS (
              SELECT 1 FROM public.prison_records
              WHERE user_id = p_user_id AND released_at IS NULL
          );
    END IF;
    
    RETURN jsonb_build_object(
        'success', true,
        'released', v_released_count > 0,
        'message', CASE WHEN v_released_count > 0 
            THEN 'Released from prison' 
            ELSE 'Still in prison' 
        END
    );
END;
$$;


ALTER FUNCTION "public"."check_and_release_from_prison"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."claim_crafted_item"("p_queue_item_id" "uuid") RETURNS TABLE("success" boolean, "message" "text", "xp_awarded" integer)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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


ALTER FUNCTION "public"."claim_crafted_item"("p_queue_item_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."collect_facility_production"("p_facility_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
    v_facility RECORD;
    v_now BIGINT;
    v_queue_item RECORD;
    v_recipe RECORD;
    v_raid_roll INT;
    v_burn_roll INT;
    v_success_count INT := 0;
    v_raid_occurred BOOLEAN := FALSE;
    v_burn_occurred BOOLEAN := FALSE;
    v_final_qty INT;
    v_prison_duration INT;
BEGIN
    v_user_id := auth.uid();
    v_now := EXTRACT(EPOCH FROM NOW())::BIGINT;
    
    -- Check Prison Status on game.users
    IF EXISTS (SELECT 1 FROM public.users WHERE id = v_user_id AND prison_until > NOW()) THEN
        RETURN jsonb_build_object('success', false, 'error', 'You are in prison!');
    END IF;
    
    SELECT * INTO v_facility FROM public.facilities WHERE id = p_facility_id AND user_id = v_user_id;
    
    FOR v_queue_item IN 
        SELECT * FROM public.facility_queue 
        WHERE facility_id = p_facility_id AND completed_at <= v_now AND status = 'in_progress'
    LOOP
        SELECT * INTO v_recipe FROM public.facility_recipes WHERE id = v_queue_item.recipe_id;
        
        -- Raid Check
        v_raid_roll := floor(random() * 100);
        IF v_raid_roll < v_facility.suspicion_level THEN
            UPDATE public.facility_queue SET status = 'raided', is_raided = TRUE WHERE id = v_queue_item.id;
            v_raid_occurred := TRUE;
            
            -- PRISON LOGIC (50% Chance)
            IF floor(random() * 100) < 50 THEN
                v_prison_duration := GREATEST(10, v_facility.suspicion_level * 2); 
                
                -- Update game.users
                UPDATE game.users 
                SET prison_until = NOW() + (v_prison_duration || ' minutes')::INTERVAL,
                    prison_reason = 'Facility Raid: ' || v_facility.type
                WHERE id = v_user_id;
                
                UPDATE public.facilities SET suspicion = 0 WHERE id = p_facility_id;
                
                RETURN jsonb_build_object(
                    'success', true, 'raid', true, 'prison', true, 
                    'prison_time', v_prison_duration,
                    'collected_count', v_success_count
                );
            ELSE
                 UPDATE public.facilities SET suspicion = GREATEST(0, suspicion - 30) WHERE id = p_facility_id;
            END IF;
            
            CONTINUE; 
        END IF;
        
        -- Burn Check
        v_burn_roll := floor(random() * 100);
        IF v_burn_roll > v_recipe.success_rate THEN
            UPDATE public.facility_queue SET status = 'burned', is_burned = TRUE WHERE id = v_queue_item.id;
            v_burn_occurred := TRUE;
            CONTINUE;
        END IF;
        
        v_final_qty := v_recipe.output_quantity * v_queue_item.quantity;
        
        INSERT INTO public.inventory (user_id, item_id, quantity, obtained_at)
        VALUES (v_user_id, v_recipe.output_item_id, v_final_qty, v_now);
        
        UPDATE public.facility_queue SET status = 'completed' WHERE id = v_queue_item.id;
        v_success_count := v_success_count + 1;
        
    END LOOP;
    
    RETURN jsonb_build_object(
        'success', true, 
        'raid', v_raid_occurred, 
        'burn', v_burn_occurred, 
        'collected_count', v_success_count
    );
END;
$$;


ALTER FUNCTION "public"."collect_facility_production"("p_facility_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."collect_facility_resources"("p_facility_id" "uuid", "p_resources" "jsonb" DEFAULT '[]'::"jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
    v_facility RECORD;
    v_resources_generated JSONB := '[]'::jsonb;
    v_item RECORD;
    v_existing_item RECORD;
    v_items_inserted INT := 0;
    v_items_updated INT := 0;
    v_items_skipped INT := 0;
    v_to_add JSONB := '{}'::jsonb;
    v_required_slots INT := 0;
    v_available_slots INT := 0;
        v_available_slot_list INT[] := ARRAY[]::int[];
        v_slot_idx INT := 1;
    v_qty_to_add INT := 0;
    v_qty_remaining INT := 0;
    v_max_stack INT := 999;
    v_is_stackable BOOLEAN := true;
    v_existing_space INT := 0;
    v_item_id TEXT;
    v_add_qty INT := 0;
    
    -- Time Logic
    v_now TIMESTAMP WITH TIME ZONE := NOW();
    v_last_collected TIMESTAMP WITH TIME ZONE;
    v_started_at TIMESTAMP WITH TIME ZONE;
    v_hours_elapsed FLOAT;
    v_production_rate INT;
    v_total_qty INT;
    v_offline_cap INT := 720;
    v_production_duration_seconds NUMERIC := 120;  -- 2 minutes for testing (originally 3600 = 1 hour)
    v_calc_end TIMESTAMP WITH TIME ZONE;
    v_elapsed_since_start NUMERIC;
    
    -- Drop Rate Variables
    v_level INT;
    v_base_rate INT := 10;
    v_roll FLOAT;
    v_rarity TEXT;
    
    -- Weights (Base Level 1 - Matched with FacilityManager.gd)
    v_w_common FLOAT := 700.0;
    v_w_uncommon FLOAT := 200.0;
    v_w_rare FLOAT := 80.0;
    v_w_epic FLOAT := 15.0;
    v_w_legendary FLOAT := 5.0;
    v_total_weight FLOAT;
    
BEGIN
    -- Get authenticated user
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    -- CHECK IF PLAYER IS IN PRISON
    IF EXISTS (
        SELECT 1 FROM public.prison_records 
        WHERE user_id = v_user_id AND released_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Player is imprisoned and cannot collect resources');
    END IF;

    -- Verify facility ownership
    SELECT * INTO v_facility
    FROM public.facilities
    WHERE id = p_facility_id AND user_id = v_user_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Facility not found or not owned');
    END IF;

    v_level := COALESCE(v_facility.level, 1);
    v_started_at := v_facility.production_started_at;
    v_last_collected := COALESCE(v_facility.last_production_collected_at, v_started_at);

    -- Production Validation
    IF v_started_at IS NULL THEN
         RETURN jsonb_build_object('success', false, 'error', 'Production not started');
    END IF;
    
    -- CRITICAL: If last_collected is same as started, use started time (first collection from production start)
    -- Otherwise use the actual last collection time
    IF v_last_collected IS NULL THEN
        v_last_collected := v_started_at;
    END IF;
    IF v_last_collected < v_started_at THEN
        v_last_collected := v_started_at;
    END IF;
    
    -- Cap calculation to production duration window
    v_calc_end := LEAST(v_now, v_started_at + (v_production_duration_seconds || ' seconds')::interval);
    IF v_last_collected >= v_calc_end THEN
        RETURN jsonb_build_object(
            'success', true,
            'message', 'No resources accumulated yet',
            'count', 0,
            'items_inserted', 0,
            'items_updated', 0,
            'items_skipped', 0,
            'debug_started_at', v_started_at,
            'debug_last_collected', v_last_collected,
            'debug_calc_end', v_calc_end
        );
    END IF;
    
    -- Calculate hours elapsed since last collection
    v_hours_elapsed := EXTRACT(EPOCH FROM (v_calc_end - v_last_collected)) / 3600.0;
    
    RAISE NOTICE '[collect_facility_resources] DEBUG: started_at=%, last_collected=%, calc_end=%, hours_elapsed=%, now=%', v_started_at, v_last_collected, v_calc_end, v_hours_elapsed, v_now;
    
    -- Resources accumulate continuously: (hours_elapsed * base_rate * level * 10x multiplier)
    v_production_rate := v_base_rate * v_level * 10;  -- 10x for testing
    v_total_qty := GREATEST(0, (v_hours_elapsed * v_production_rate)::INT);
    
    RAISE NOTICE '[collect_facility_resources] CALC: hours_elapsed=%, rate=%, total_qty=%', v_hours_elapsed, v_production_rate, v_total_qty;
    
    -- If no time has passed, no resources
    IF v_total_qty <= 0 THEN
        RETURN jsonb_build_object('success', true, 'message', 'No resources accumulated yet', 'count', 0);
    END IF;
    
    -- Cap by offline production cap
    v_total_qty := LEAST(v_total_qty, v_offline_cap);
    
    -- Adjust Weights Scaling by Level (Sync with FacilityManager.gd)
    IF v_level > 1 THEN
        v_w_uncommon := v_w_uncommon + ((v_level - 1) * 15.0);
        v_w_rare := v_w_rare + ((v_level - 1) * 8.0);
        v_w_epic := v_w_epic + ((v_level - 1) * 3.0);
        v_w_legendary := v_w_legendary + ((v_level - 1) * 1.5);
    END IF;
    
    v_total_weight := v_w_common + v_w_uncommon + v_w_rare + v_w_epic + v_w_legendary;

    RAISE NOTICE '[collect_facility_resources] Start: user_id=%, facility_type=%, level=%, total_qty=%', v_user_id, v_facility.type, v_level, v_total_qty;
    
    -- Generate Items loop
    FOR i IN 1..v_total_qty LOOP
        v_roll := random() * v_total_weight;
        
        IF v_roll < v_w_common THEN v_rarity := 'common';
        ELSIF v_roll < (v_w_common + v_w_uncommon) THEN v_rarity := 'uncommon';
        ELSIF v_roll < (v_w_common + v_w_uncommon + v_w_rare) THEN v_rarity := 'rare';
        ELSIF v_roll < (v_w_common + v_w_uncommon + v_w_rare + v_w_epic) THEN v_rarity := 'epic';
        ELSE v_rarity := 'legendary';
        END IF;
        
                -- Select Item based on Facility Type & Rarity (case-insensitive)
                SELECT * INTO v_item
                FROM public.items
                WHERE production_building_type = v_facility.type
                    AND lower(rarity) = v_rarity
                ORDER BY random()
                LIMIT 1;
        
                -- Fallback if not found
                IF NOT FOUND THEN
                        RAISE NOTICE '[collect_facility_resources] No item found for type=% rarity=%, trying common', v_facility.type, v_rarity;
                        SELECT * INTO v_item
                        FROM public.items
                        WHERE production_building_type = v_facility.type
                            AND lower(rarity) = 'common'
                        ORDER BY random()
                        LIMIT 1;
                END IF;

                -- Final fallback: any item for this facility type
                IF NOT FOUND THEN
                    RAISE NOTICE '[collect_facility_resources] No rarity match, picking any item for type=%', v_facility.type;
                    SELECT * INTO v_item
                    FROM public.items
                    WHERE production_building_type = v_facility.type
                    ORDER BY random()
                    LIMIT 1;
                END IF;

                -- Last resort: pick any item at all (prevents zero inserts if type mapping is missing)
                IF NOT FOUND THEN
                    RAISE NOTICE '[collect_facility_resources] No item found for type=%, picking any item globally', v_facility.type;
                    SELECT * INTO v_item
                    FROM public.items
                    ORDER BY random()
                    LIMIT 1;
                END IF;
        
        IF FOUND THEN
            RAISE NOTICE '[collect_facility_resources] Item found: id=%, name=%, stackable=%, rarity=%', v_item.id, v_item.name, v_item.is_stackable, v_item.rarity;
            v_to_add := jsonb_set(
                v_to_add,
                ARRAY[v_item.id::text],
                to_jsonb(COALESCE((v_to_add->>v_item.id::text)::int, 0) + 1),
                true
            );
        ELSE
            v_items_skipped := v_items_skipped + 1;
            RAISE NOTICE '[collect_facility_resources] WARNING: No item found even in fallback for type=%', v_facility.type;
        END IF;
    END LOOP;
    
    RAISE NOTICE '[collect_facility_resources] Loop complete: processed % items', v_total_qty;

    -- ===== Inventory capacity check (20 slots) =====
    -- Count only valid slot positions (0-19)
    SELECT COUNT(*) INTO v_available_slots
    FROM public.inventory
    WHERE user_id = v_user_id
      AND slot_position BETWEEN 0 AND 19;
    v_available_slots := 20 - v_available_slots;
    IF v_available_slots < 0 THEN
        v_available_slots := 0;
    END IF;

    -- Calculate required slots based on stacking rules
    FOR v_item_id, v_qty_to_add IN
        SELECT key, value::int FROM jsonb_each_text(v_to_add)
    LOOP
        -- FACILITY ITEMS: All facility-produced items MUST stack with max=500
        -- Do NOT read from database - use fixed values
        v_is_stackable := true;
        v_max_stack := 500;

        IF v_is_stackable THEN
            SELECT COALESCE(SUM(GREATEST(v_max_stack - quantity, 0)), 0)
            INTO v_existing_space
            FROM public.inventory
            WHERE user_id = v_user_id AND item_id = v_item_id;

            v_qty_remaining := GREATEST(v_qty_to_add - v_existing_space, 0);
            IF v_qty_remaining > 0 THEN
                v_required_slots := v_required_slots + CEIL(v_qty_remaining::numeric / v_max_stack::numeric)::int;
            END IF;
        ELSE
            v_required_slots := v_required_slots + v_qty_to_add;
        END IF;
    END LOOP;

    -- Build available slot list (0-19)
    SELECT ARRAY_AGG(slot_num ORDER BY slot_num)
    INTO v_available_slot_list
    FROM generate_series(0, 19) slot_num
    WHERE NOT EXISTS (
        SELECT 1 FROM public.inventory
        WHERE user_id = v_user_id AND slot_position = slot_num
    );

    -- Recalculate available slots based on actual free positions
    v_available_slots := COALESCE(array_length(v_available_slot_list, 1), 0);

    IF v_required_slots > v_available_slots THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Inventory is full',
            'required_slots', v_required_slots,
            'available_slots', v_available_slots,
            'count', v_total_qty,
            'items_inserted', 0,
            'items_updated', 0,
            'items_skipped', v_items_skipped,
            'debug_started_at', v_started_at,
            'debug_last_collected', v_last_collected,
            'debug_calc_end', v_calc_end,
            'debug_hours_elapsed', v_hours_elapsed,
            'debug_rate', v_production_rate
        );
    END IF;

    -- ===== Apply additions =====
    FOR v_item_id, v_qty_to_add IN
        SELECT key, value::int FROM jsonb_each_text(v_to_add)
    LOOP

        -- FACILITY ITEMS: Force max_stack=500 for all facility-produced items
        v_is_stackable := true;
        v_max_stack := 500;

        RAISE NOTICE '[collect_facility_resources] Item %: stackable=%, max_stack=%', v_item_id, v_is_stackable, v_max_stack;

        IF v_is_stackable THEN
            v_qty_remaining := v_qty_to_add;

            -- Fill existing stacks first
            FOR v_existing_item IN
                SELECT row_id, quantity, slot_position
                FROM public.inventory
                WHERE user_id = v_user_id AND item_id = v_item_id
                ORDER BY quantity ASC
            LOOP
                v_add_qty := LEAST(v_max_stack - v_existing_item.quantity, v_qty_remaining);
                IF v_add_qty > 0 THEN
                    UPDATE public.inventory
                    SET quantity = quantity + v_add_qty, updated_at = NOW()
                    WHERE row_id = v_existing_item.row_id;
                    v_qty_remaining := v_qty_remaining - v_add_qty;
                    v_items_updated := v_items_updated + 1;
                END IF;
                IF v_qty_remaining <= 0 THEN
                    EXIT;
                END IF;
            END LOOP;

            -- Insert new stacks if needed
            WHILE v_qty_remaining > 0 LOOP
                v_add_qty := LEAST(v_max_stack, v_qty_remaining);
                INSERT INTO public.inventory (
                    user_id, item_id, quantity, enhancement_level, is_equipped, obtained_at, slot_position
                ) VALUES (
                    v_user_id, v_item_id, v_add_qty, 0, false, EXTRACT(EPOCH FROM NOW())::BIGINT,
                    v_available_slot_list[v_slot_idx]
                );
                v_items_inserted := v_items_inserted + 1;
                v_slot_idx := v_slot_idx + 1;
                v_qty_remaining := v_qty_remaining - v_add_qty;
            END LOOP;
        ELSE
            -- Non-stackable: each needs its own slot
            FOR i IN 1..v_qty_to_add LOOP
                INSERT INTO public.inventory (
                    user_id, item_id, quantity, enhancement_level, is_equipped, obtained_at, slot_position
                ) VALUES (
                    v_user_id, v_item_id, 1, 0, false, EXTRACT(EPOCH FROM NOW())::BIGINT,
                    v_available_slot_list[v_slot_idx]
                );
                v_items_inserted := v_items_inserted + 1;
                v_slot_idx := v_slot_idx + 1;
            END LOOP;
        END IF;
    END LOOP;

    -- Update Facility
    -- Update last_production_collected_at to NOW
    -- Reset production_started_at ONLY if 120 seconds have passed (status=expired)
    -- Otherwise keep production_started_at so production continues from where it left off
    
    BEGIN
        v_elapsed_since_start := EXTRACT(EPOCH FROM (v_now - v_started_at));
        RAISE NOTICE '[collect_facility_resources] Updating facility: elapsed_since_start=%, duration=%', v_elapsed_since_start, v_production_duration_seconds;
        
        IF v_elapsed_since_start >= v_production_duration_seconds THEN
            -- Production expired (120 seconds passed), reset for next cycle
            RAISE NOTICE '[collect_facility_resources] Production expired, resetting production_started_at';
            UPDATE public.facilities
            SET last_production_collected_at = v_now,
                production_started_at = NULL,
                suspicion_level = GREATEST(0, suspicion_level - GREATEST(5, (suspicion_level * 0.15)::INT))
            WHERE id = p_facility_id;
        ELSE
            -- Production still active (under 120 seconds), keep production_started_at
            RAISE NOTICE '[collect_facility_resources] Production still active, keeping production_started_at';
            UPDATE public.facilities
            SET last_production_collected_at = v_now,
                suspicion_level = GREATEST(0, suspicion_level - GREATEST(5, (suspicion_level * 0.15)::INT))
            WHERE id = p_facility_id;
        END IF;
    END;

    RAISE NOTICE '[collect_facility_resources] SUCCESS: collected %, inserted=%, updated=%', v_total_qty, v_items_inserted, v_items_updated;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Resources collected',
        'count', v_total_qty,
        'items_inserted', v_items_inserted,
        'items_updated', v_items_updated,
        'items_skipped', v_items_skipped,
        'debug_started_at', v_started_at,
        'debug_last_collected', v_last_collected,
        'debug_calc_end', v_calc_end,
        'debug_hours_elapsed', v_hours_elapsed,
        'debug_rate', v_production_rate,
        'new_suspicion', GREATEST(0, v_facility.suspicion_level - GREATEST(5, (v_facility.suspicion_level * 0.15)::INT))
    );

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '[collect_facility_resources] ERROR: %', SQLERRM;
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;


ALTER FUNCTION "public"."collect_facility_resources"("p_facility_id" "uuid", "p_resources" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."collect_facility_resources"("p_facility_id" "uuid", "p_seed" bigint, "p_debug" boolean DEFAULT false) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
    v_message TEXT;
BEGIN
    v_user_id := auth.uid();
    
    -- This function is deprecated in favor of collect_facility_resources_v2
    -- It should not be used anymore. Redirecting to v2.
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Use collect_facility_resources_v2 instead',
        'message', 'This function is deprecated. Use collect_facility_resources_v2 with p_total_count parameter.'
    );
END;
$$;


ALTER FUNCTION "public"."collect_facility_resources"("p_facility_id" "uuid", "p_seed" bigint, "p_debug" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."collect_facility_resources_v2"("p_facility_id" "uuid", "p_seed" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
    v_facility RECORD;
    v_level INT;
    v_type TEXT;
    v_started_at TIMESTAMPTZ;
    v_now TIMESTAMPTZ := NOW();
    v_total_qty INT;
    v_base_rate INT := 10;
    
    v_production_duration INT := 120;
    v_end_time TIMESTAMPTZ;
    v_calc_time TIMESTAMPTZ;
    v_last_collected TIMESTAMPTZ;
    v_elapsed_seconds NUMERIC;
    
    v_items_breakdown JSONB := '{}'::jsonb;
    v_generated_items JSONB := '[]'::jsonb;
    
    v_i INT;
    v_item_id TEXT;
    v_item_name TEXT;
    v_qty_for_item INT;
    v_rarity TEXT;
    v_resource_index INT;
    v_rng_val FLOAT;
    v_cumulative FLOAT;
    
    v_available_slots INT := 0;
    v_available_slot_list INT[] := ARRAY[]::int[];
    v_max_stack INT := 500;
    v_existing_space INT;
    v_qty_remaining INT;
    v_required_slots INT := 0;
    v_slot_idx INT;
    v_add_qty INT;
    v_existing_item RECORD;
    
    v_items_inserted INT := 0;
    v_items_updated INT := 0;
    
    v_new_global_suspicion INT;
    v_prison_roll FLOAT;
    v_prison_chance INT;
    
    v_resources_pool TEXT[];
    v_weights JSONB;
    v_total_weight NUMERIC;
    v_unlocked_rarities TEXT[];
    
BEGIN
    v_user_id := auth.uid();
    
    SELECT * INTO v_facility FROM public.facilities
    WHERE id = p_facility_id AND user_id = v_user_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Facility not found');
    END IF;
    
    v_type := v_facility.type;
    v_level := COALESCE(v_facility.level, 1);
    v_started_at := v_facility.production_started_at;
    
    IF v_started_at IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Production not started');
    END IF;
    
    -- Calculate resources using same formula as preview:
    -- Production duration: 120 seconds for testing (matches client-side preview)
    -- hours_elapsed * (base_rate * level * 10multiplier)
    -- Calculate from when production was last collected to either now or when production expired
    v_end_time := v_started_at + (v_production_duration || ' seconds')::INTERVAL;
    v_calc_time := LEAST(v_now, v_end_time);  -- Cap calc time to end_time
    v_last_collected := COALESCE(v_facility.last_production_collected_at, v_started_at);
    v_elapsed_seconds := EXTRACT(EPOCH FROM (v_calc_time - v_last_collected));
    
    v_total_qty := LEAST(
        GREATEST(0, ((v_elapsed_seconds / 3600.0) * (v_base_rate * v_level * 10))::INT),
        100
    );
    
    -- DEBUG: Log calculation details
    RAISE LOG '[RPC_DEBUG] facility_type=%, level=%, started_at=%, last_collected=%, now=%, end_time=%, calc_time=%, elapsed_seconds=%, base_calc=%, total_qty=%',
        v_type, v_level, v_started_at, v_last_collected, v_now, v_end_time, v_calc_time,
        v_elapsed_seconds, ((v_elapsed_seconds / 3600.0) * (v_base_rate * v_level * 10))::numeric, v_total_qty;
    
    IF v_total_qty <= 0 THEN
        RETURN jsonb_build_object('success', true, 'message', 'No resources yet', 'count', 0, 'items_generated', '[]'::jsonb);
    END IF;
    
    -- Resource pools
    v_resources_pool := CASE v_type
        WHEN 'mining' THEN ARRAY['iron_ore', 'copper_ore', 'silver_ore', 'gold_ore', 'mithril_ore']
        WHEN 'clay_pit' THEN ARRAY['ceramic_clay', 'brick_clay', 'enchanted_clay', 'dragon_clay', 'primordial_clay']
        WHEN 'quarry' THEN ARRAY['granite', 'marble', 'crystal_shard', 'obsidian', 'moonstone']
        WHEN 'lumber_mill' THEN ARRAY['oak_wood', 'pine_wood', 'bamboo', 'elder_wood', 'world_tree_sap']
        WHEN 'sand_quarry' THEN ARRAY['glass_sand', 'crystal_sand', 'star_dust', 'void_sand', 'infinity_sand']
        WHEN 'farming' THEN ARRAY['wheat', 'vegetables', 'cotton', 'magical_grain', 'golden_wheat']
        WHEN 'herb_garden' THEN ARRAY['healing_herb', 'poison_herb', 'rare_flower', 'dragon_root', 'phoenix_petal']
        WHEN 'ranch' THEN ARRAY['leather', 'bone', 'wool', 'monster_hide', 'dragon_scale']
        WHEN 'apiary' THEN ARRAY['honey', 'beeswax', 'bee_venom', 'royal_jelly', 'celestial_honey']
        WHEN 'mushroom_farm' THEN ARRAY['healing_mushroom', 'poison_mushroom', 'glowing_mushroom', 'ghost_mushroom', 'immortality_shroom']
        WHEN 'rune_mine' THEN ARRAY['raw_rune', 'magic_crystal', 'energy_shard', 'power_rune', 'ancient_rune']
        WHEN 'holy_spring' THEN ARRAY['holy_water', 'mana_crystal', 'purification_water', 'blessed_essence', 'divine_tear']
        WHEN 'shadow_pit' THEN ARRAY['dark_essence', 'shadow_crystal', 'curse_dust', 'void_fragment', 'abyss_core']
        WHEN 'elemental_forge' THEN ARRAY['fire_essence', 'ice_crystal', 'lightning_core', 'storm_shard', 'primordial_flame']
        WHEN 'time_well' THEN ARRAY['time_crystal', 'aging_dust', 'eternity_essence', 'temporal_shard', 'infinity_stone']
        ELSE ARRAY[]::TEXT[]
    END;
    
    IF array_length(v_resources_pool, 1) IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unknown facility type');
    END IF;
    
    -- Calculate rarity weights for this level (same as preview)
    -- Base: COMMON=700, UNCOMMON=200, RARE=80, EPIC=15, LEGENDARY=5
    -- Per level increase: UNCOMMON +15, RARE +8, EPIC +3, LEGENDARY +1.5
    v_weights := jsonb_build_object(
        'COMMON', 700.0,
        'UNCOMMON', 200.0 + ((v_level - 1) * 15.0),
        'RARE', 80.0 + ((v_level - 1) * 8.0),
        'EPIC', 15.0 + ((v_level - 1) * 3.0),
        'LEGENDARY', 5.0 + ((v_level - 1) * 1.5)
    );
    
    -- Calculate total weight
    SELECT SUM(value::NUMERIC)::NUMERIC INTO v_total_weight FROM jsonb_each_text(v_weights);
    v_total_weight := COALESCE(v_total_weight, 0);
    
    -- Determine which rarities are unlocked at this level
    v_unlocked_rarities := ARRAY[]::TEXT[];
    IF v_level >= 1 THEN v_unlocked_rarities := array_append(v_unlocked_rarities, 'COMMON'); END IF;
    IF v_level >= 3 THEN v_unlocked_rarities := array_append(v_unlocked_rarities, 'UNCOMMON'); END IF;
    IF v_level >= 5 THEN v_unlocked_rarities := array_append(v_unlocked_rarities, 'RARE'); END IF;
    IF v_level >= 7 THEN v_unlocked_rarities := array_append(v_unlocked_rarities, 'EPIC'); END IF;
    IF v_level >= 10 THEN v_unlocked_rarities := array_append(v_unlocked_rarities, 'LEGENDARY'); END IF;
    
    -- Generate items with rarity-based distribution
    FOR v_i IN 1..v_total_qty LOOP
        -- Use seed-based deterministic RNG to pick rarity
        v_rng_val := ((p_seed + v_i) * 16807.0 % 2147483647.0) / 2147483647.0;
        v_cumulative := 0.0;
        v_rarity := 'COMMON';  -- default
        
        -- Pick rarity based on weights
        IF (v_weights->>'COMMON')::NUMERIC / v_total_weight <= v_rng_val THEN
            v_cumulative := (v_weights->>'COMMON')::NUMERIC / v_total_weight;
            IF v_cumulative + (v_weights->>'UNCOMMON')::NUMERIC / v_total_weight > v_rng_val THEN
                v_rarity := 'UNCOMMON';
            ELSIF v_cumulative + (v_weights->>'RARE')::NUMERIC / v_total_weight > v_rng_val THEN
                v_rarity := 'RARE';
            ELSIF v_cumulative + (v_weights->>'EPIC')::NUMERIC / v_total_weight > v_rng_val THEN
                v_rarity := 'EPIC';
            ELSE
                v_rarity := 'LEGENDARY';
            END IF;
        END IF;
        
        -- Downgrade if not unlocked
        IF NOT (v_rarity = ANY(v_unlocked_rarities)) THEN
            IF 'EPIC' = ANY(v_unlocked_rarities) AND v_rarity = 'LEGENDARY' THEN
                v_rarity := 'EPIC';
            ELSIF 'RARE' = ANY(v_unlocked_rarities) AND (v_rarity = 'LEGENDARY' OR v_rarity = 'EPIC') THEN
                v_rarity := 'RARE';
            ELSIF 'UNCOMMON' = ANY(v_unlocked_rarities) AND (v_rarity IN ('LEGENDARY', 'EPIC', 'RARE')) THEN
                v_rarity := 'UNCOMMON';
            ELSE
                v_rarity := 'COMMON';
            END IF;
        END IF;
        
        -- Pick resource based on rarity tier
        -- Index 0,1 = COMMON | 2 = UNCOMMON | 3 = RARE | 4 = LEGENDARY
        v_resource_index := CASE v_rarity
            WHEN 'COMMON' THEN ((p_seed + v_i) % 2)
            WHEN 'UNCOMMON' THEN 2
            WHEN 'RARE' THEN 3
            WHEN 'EPIC' THEN 3
            WHEN 'LEGENDARY' THEN 4
            ELSE 0
        END;
        
        IF v_resource_index >= array_length(v_resources_pool, 1) THEN
            v_resource_index := array_length(v_resources_pool, 1) - 1;
        END IF;
        
        v_item_id := v_resources_pool[v_resource_index + 1];
        IF v_item_id IS NULL THEN v_item_id := v_resources_pool[1]; END IF;
        
        v_qty_for_item := COALESCE((v_items_breakdown->>v_item_id)::INT, 0) + 1;
        v_items_breakdown := jsonb_set(v_items_breakdown, ARRAY[v_item_id], to_jsonb(v_qty_for_item));
    END LOOP;
    
    -- Build items array for response (before inventory operations)
    FOR v_item_id IN SELECT key FROM jsonb_each(v_items_breakdown) LOOP
        v_qty_for_item := (v_items_breakdown->>v_item_id)::INT;
        SELECT name INTO v_item_name FROM public.items WHERE id = v_item_id LIMIT 1;
        v_generated_items := v_generated_items || jsonb_build_object(
            'item_id', v_item_id,
            'item_name', v_item_name,
            'quantity', v_qty_for_item
        );
    END LOOP;
    
    -- Inventory checks
    SELECT COUNT(*) INTO v_available_slots
    FROM public.inventory WHERE user_id = v_user_id AND slot_position BETWEEN 0 AND 19;
    v_available_slots := 20 - v_available_slots;
    
    -- Calculate slots needed
    FOR v_item_id, v_qty_for_item IN SELECT key, value::int FROM jsonb_each_text(v_items_breakdown) LOOP
        SELECT COALESCE(SUM(GREATEST(v_max_stack - quantity, 0)), 0)
        INTO v_existing_space FROM public.inventory
        WHERE user_id = v_user_id AND item_id = v_item_id;
        
        v_qty_remaining := GREATEST(v_qty_for_item - v_existing_space, 0);
        IF v_qty_remaining > 0 THEN
            v_required_slots := v_required_slots + CEIL(v_qty_remaining::numeric / v_max_stack::numeric)::int;
        END IF;
    END LOOP;
    
    -- Get available slots
    SELECT ARRAY_AGG(s ORDER BY s) INTO v_available_slot_list
    FROM generate_series(0, 19) s
    WHERE NOT EXISTS (SELECT 1 FROM public.inventory WHERE user_id = v_user_id AND slot_position = s);
    
    IF v_required_slots > COALESCE(array_length(v_available_slot_list, 1), 0) THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Inventory full',
            'count', v_total_qty,
            'items_generated', v_generated_items
        );
    END IF;
    
    -- Add to inventory - FIXED to count correctly
    v_slot_idx := 1;
    FOR v_item_id, v_qty_for_item IN SELECT key, value::int FROM jsonb_each_text(v_items_breakdown) LOOP
        v_qty_remaining := v_qty_for_item;
        
        -- Update existing stacks
        FOR v_existing_item IN
            SELECT row_id, quantity FROM public.inventory
            WHERE user_id = v_user_id AND item_id = v_item_id AND quantity < v_max_stack
            ORDER BY quantity DESC
        LOOP
            v_add_qty := LEAST(v_max_stack - v_existing_item.quantity, v_qty_remaining);
            UPDATE public.inventory SET quantity = quantity + v_add_qty, updated_at = NOW()
            WHERE row_id = v_existing_item.row_id;
            v_qty_remaining := v_qty_remaining - v_add_qty;
            v_items_updated := v_items_updated + 1;
            
            IF v_qty_remaining <= 0 THEN EXIT; END IF;
        END LOOP;
        
        -- Insert new stacks
        WHILE v_qty_remaining > 0 LOOP
            v_add_qty := LEAST(v_max_stack, v_qty_remaining);
            INSERT INTO public.inventory (user_id, item_id, quantity, enhancement_level, is_equipped, obtained_at, slot_position)
            VALUES (v_user_id, v_item_id, v_add_qty, 0, false, EXTRACT(EPOCH FROM NOW())::BIGINT, v_available_slot_list[v_slot_idx]);
            v_items_inserted := v_items_inserted + 1;
            v_slot_idx := v_slot_idx + 1;
            v_qty_remaining := v_qty_remaining - v_add_qty;
        END LOOP;
    END LOOP;
    
    -- Update facility
    UPDATE public.facilities SET
        last_production_collected_at = v_now,
        production_started_at = NULL,
        suspicion_level = GREATEST(0, suspicion_level - 10)
    WHERE id = p_facility_id;
    
    -- NOTE: Don't update global_suspicion_level here!
    -- Client handles risk calculation and syncs via update_global_suspicion_level RPC
    -- This keeps risk sync centralized and prevents conflicts
    
    -- Get current facility suspicion for prison check
    SELECT COALESCE(suspicion_level, 0) INTO v_new_global_suspicion
    FROM public.facilities WHERE id = p_facility_id;
    
    -- PROBABILISTIC prison admission based on global suspicion %
    IF v_new_global_suspicion >= 50 THEN
        v_prison_chance := 50 + v_new_global_suspicion;  -- At 50% = 100%, at 100% = 150%
        v_prison_roll := (((p_seed + 19) * 16807) % 2147483647) / 2147483647.0 * 100;
        
        IF v_prison_roll < v_prison_chance AND NOT EXISTS (
            SELECT 1 FROM public.prison_records WHERE user_id = v_user_id AND released_at IS NULL
        ) THEN
            PERFORM admit_to_prison(p_facility_id, v_new_global_suspicion);
        END IF;
    END IF;
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Resources collected successfully',
        'count', v_total_qty,
        'total_added', v_total_qty,
        'items_generated', v_generated_items,
        'items_breakdown', v_items_breakdown,
        'items_inserted', v_items_inserted,
        'items_updated', v_items_updated
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;


ALTER FUNCTION "public"."collect_facility_resources_v2"("p_facility_id" "uuid", "p_seed" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."collect_facility_resources_v2"("p_facility_id" "uuid", "p_seed" bigint, "p_total_count" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_facility RECORD;
    v_now TIMESTAMPTZ := NOW();
    v_generated_items JSONB := '[]'::jsonb;
    v_new_global_suspicion INT;
    v_prison_roll FLOAT;
    v_prison_chance INT;
    v_prison_log TEXT := '';
    v_admission_occurs BOOLEAN := false;
BEGIN
    -- Facility lookup uses auth.uid() directly (facilities.user_id stores auth.uid())
    SELECT * INTO v_facility FROM public.facilities
    WHERE id = p_facility_id AND user_id = v_user_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Facility not found');
    END IF;

    -- Keep production & item generation behavior unchanged (omitted here)

    UPDATE public.facilities SET
        last_production_collected_at = v_now,
        production_started_at = NULL,
        suspicion_level = GREATEST(0, suspicion_level - 10)
    WHERE id = p_facility_id;

    SELECT COALESCE(global_suspicion_level, 0) INTO v_new_global_suspicion
    FROM public.users WHERE auth_id = v_user_id;

    v_prison_chance := 20 + v_new_global_suspicion;
    v_prison_roll := (((p_seed + 19) * 16807) % 2147483647) / 2147483647.0 * 100;

    v_prison_log := '[collect_facility_resources_v2] PRISON CHECK: global_suspicion=' || v_new_global_suspicion
        || ', prison_chance=' || v_prison_chance
        || ', roll=' || (ROUND(v_prison_roll::NUMERIC, 2))::TEXT
        || ', within_chance=' || (CASE WHEN v_prison_roll < v_prison_chance THEN 'true' ELSE 'false' END);

    v_admission_occurs := (v_prison_roll < v_prison_chance) AND NOT EXISTS (
        SELECT 1 FROM public.prison_records WHERE user_id = v_user_id AND released_at IS NULL
    );

    RAISE LOG '%', v_prison_log;
    RAISE LOG '[collect_facility_resources_v2] ADMISSION OCCURS: %', v_admission_occurs;

    IF v_admission_occurs THEN
        PERFORM admit_to_prison(p_facility_id, v_new_global_suspicion);
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Resources collected successfully',
        'count', COALESCE(p_total_count, 0),
        'items_generated', v_generated_items,
        'prison_check', jsonb_build_object(
            'global_suspicion', v_new_global_suspicion,
            'prison_chance', v_prison_chance,
            'prison_roll', ROUND(v_prison_roll::NUMERIC, 2),
            'admission_occurred', v_admission_occurs,
            'prison_log', v_prison_log
        )
    );
END;
$$;


ALTER FUNCTION "public"."collect_facility_resources_v2"("p_facility_id" "uuid", "p_seed" bigint, "p_total_count" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."craft_item_async"("p_recipe_id" "uuid", "p_batch_count" integer DEFAULT 1) RETURNS TABLE("success" boolean, "queue_item_id" "uuid", "message" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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


ALTER FUNCTION "public"."craft_item_async"("p_recipe_id" "uuid", "p_batch_count" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."decrement_facility_suspicion"("p_facility_id" "uuid", "p_amount" integer DEFAULT 10) RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_new_suspicion INT;
BEGIN
  UPDATE public.facilities
  SET suspicion_level = GREATEST(suspicion_level - p_amount, 0),
      updated_at = NOW()
  WHERE id = p_facility_id
  RETURNING suspicion_level INTO v_new_suspicion;
  
  RETURN v_new_suspicion;
END;
$$;


ALTER FUNCTION "public"."decrement_facility_suspicion"("p_facility_id" "uuid", "p_amount" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."deduct_materials_from_inventory"("p_user_id" "uuid", "p_ingredients" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_ingredient jsonb;
    v_item_id TEXT;
    v_quantity INT;
BEGIN
    FOR v_ingredient IN SELECT jsonb_array_elements(p_ingredients) LOOP
        v_item_id := v_ingredient->>'item_id';
        v_quantity := (v_ingredient->>'quantity')::INT;
        
        UPDATE inventory
        SET quantity = quantity - v_quantity
        WHERE user_id = p_user_id AND item_id = v_item_id;
        
        -- Delete if quantity = 0
        DELETE FROM inventory
        WHERE user_id = p_user_id AND item_id = v_item_id AND quantity <= 0;
    END LOOP;
END;
$$;


ALTER FUNCTION "public"."deduct_materials_from_inventory"("p_user_id" "uuid", "p_ingredients" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."deposit_to_bank"("p_item_row_ids" "uuid"[], "p_quantities" integer[] DEFAULT NULL::integer[]) RETURNS TABLE("success" boolean, "message" "text", "items_deposited" integer, "new_used_slots" integer)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid;
  v_deposit_count integer := 0;
  v_used_slots integer;
  v_max_slots integer;
  v_item_row uuid;
  v_quantity integer;
  v_idx integer := 1;
  v_inv_quantity integer;
  v_max_stack integer;
  v_existing_bank_qty integer;
  v_can_stack integer;
  v_will_deposit integer;
  v_will_remain integer;
  v_item_id text;
  v_item_category text;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'Not authenticated'::text, 0::integer, 0::integer;
    RETURN;
  END IF;

  -- Ensure bank account exists
  INSERT INTO public.user_bank_account (user_id) 
  VALUES (v_user_id)
  ON CONFLICT (user_id) DO NOTHING;

  -- Get current bank status
  SELECT total_slots, used_slots 
  INTO v_max_slots, v_used_slots
  FROM public.user_bank_account
  WHERE user_id = v_user_id;

  -- Move each inventory item to bank (respecting max_stack)
  FOREACH v_item_row IN ARRAY p_item_row_ids
  LOOP
    -- Get inventory item details
    SELECT inv.item_id, inv.quantity INTO v_item_id, v_inv_quantity
    FROM public.inventory inv
    WHERE inv.row_id = v_item_row AND inv.user_id = v_user_id;

    IF v_item_id IS NULL THEN
      CONTINUE; -- Skip if not found
    END IF;

    -- Get item max_stack and category
    SELECT max_stack, 
      CASE
        WHEN type = 'equipment' THEN 'equipment'
        WHEN type = 'consumable' THEN 'consumable'
        WHEN type = 'special' THEN 'special'
        ELSE 'material'
      END
    INTO v_max_stack, v_item_category
    FROM public.items
    WHERE id = v_item_id;

    -- Default max_stack to 1 if not set (equipment, non-stackable)
    v_max_stack := COALESCE(v_max_stack, 1);

    -- Get quantity to deposit: use p_quantities[v_idx] if available, else use all
    v_quantity := COALESCE(p_quantities[v_idx], v_inv_quantity);
    v_quantity := LEAST(v_quantity, v_inv_quantity); -- Can't deposit more than we have

    -- Check existing bank quantity for this item
    SELECT COALESCE(SUM(quantity), 0) INTO v_existing_bank_qty
    FROM public.bank_items
    WHERE user_id = v_user_id AND item_id = v_item_id;

    -- Calculate how much we can deposit (respecting max_stack)
    v_can_stack := v_max_stack - v_existing_bank_qty;
    
    IF v_can_stack <= 0 THEN
      -- Bank stack is full, skip this item
      v_idx := v_idx + 1;
      CONTINUE;
    END IF;

    -- Determine how much to actually deposit
    v_will_deposit := LEAST(v_quantity, v_can_stack);
    v_will_remain := v_inv_quantity - v_will_deposit;

    -- Check bank slot capacity (only count if we're creating a new slot)
    IF v_existing_bank_qty = 0 AND v_used_slots >= v_max_slots THEN
      -- No existing bank item and bank is full
      v_idx := v_idx + 1;
      CONTINUE;
    END IF;

    -- Deposit: either update existing bank item or insert new one
    IF v_existing_bank_qty > 0 THEN
      -- Item exists in bank, just update quantity
      UPDATE public.bank_items
      SET quantity = quantity + v_will_deposit,
          updated_at = now()
      WHERE user_id = v_user_id AND item_id = v_item_id;
    ELSE
      -- New item in bank
      INSERT INTO public.bank_items (user_id, item_id, category, slot_position, quantity)
      VALUES (v_user_id, v_item_id, v_item_category,
        (SELECT COUNT(*) FROM public.bank_items WHERE user_id = v_user_id),
        v_will_deposit);
      v_deposit_count := v_deposit_count + 1;
    END IF;

    -- Update inventory quantity or delete if none remaining
    UPDATE public.inventory
    SET quantity = v_will_remain
    WHERE row_id = v_item_row;

    -- Delete if quantity now 0
    DELETE FROM public.inventory
    WHERE row_id = v_item_row AND quantity <= 0;

    v_idx := v_idx + 1;
  END LOOP;

  -- Update bank used slots (only count new items, not quantity updates)
  UPDATE public.user_bank_account
  SET used_slots = used_slots + v_deposit_count,
      updated_at = now()
  WHERE user_id = v_user_id;

  RETURN QUERY SELECT true, 
    'Deposited successfully'::text, 
    v_deposit_count::integer, 
    (v_used_slots + v_deposit_count)::integer;
END;
$$;


ALTER FUNCTION "public"."deposit_to_bank"("p_item_row_ids" "uuid"[], "p_quantities" integer[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."determine_rarity_outcome"("p_facility_level" integer, "p_suspicion_level" integer, "p_rarity_distribution" "jsonb") RETURNS character varying
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_roll FLOAT;
  v_facility_bonus FLOAT;
  v_suspicion_penalty FLOAT;
  v_adjusted_common FLOAT;
  v_adjusted_uncommon FLOAT;
  v_adjusted_rare FLOAT;
  v_adjusted_epic FLOAT;
  v_adjusted_legendary FLOAT;
BEGIN
  -- Random roll 0-100
  v_roll := RANDOM() * 100.0;
  
  -- Level bonus: +0.5% per level
  v_facility_bonus := p_facility_level * 0.5;
  
  -- Suspicion penalty: -0.5% per suspicion
  v_suspicion_penalty := p_suspicion_level * 0.5;
  
  -- Base probabilities
  v_adjusted_common := (p_rarity_distribution->>'COMMON')::FLOAT + v_facility_bonus - v_suspicion_penalty;
  v_adjusted_uncommon := (p_rarity_distribution->>'UNCOMMON')::FLOAT + v_facility_bonus - v_suspicion_penalty;
  v_adjusted_rare := (p_rarity_distribution->>'RARE')::FLOAT + v_facility_bonus - v_suspicion_penalty;
  v_adjusted_epic := (p_rarity_distribution->>'EPIC')::FLOAT + v_facility_bonus - v_suspicion_penalty;
  v_adjusted_legendary := (p_rarity_distribution->>'LEGENDARY')::FLOAT + v_facility_bonus - v_suspicion_penalty;
  
  -- Rarity belirle
  IF v_roll < v_adjusted_common THEN
    RETURN 'COMMON';
  ELSIF v_roll < (v_adjusted_common + v_adjusted_uncommon) THEN
    RETURN 'UNCOMMON';
  ELSIF v_roll < (v_adjusted_common + v_adjusted_uncommon + v_adjusted_rare) THEN
    RETURN 'RARE';
  ELSIF v_roll < (v_adjusted_common + v_adjusted_uncommon + v_adjusted_rare + v_adjusted_epic) THEN
    RETURN 'EPIC';
  ELSIF v_roll < (v_adjusted_common + v_adjusted_uncommon + v_adjusted_rare + v_adjusted_epic + v_adjusted_legendary) THEN
    RETURN 'LEGENDARY';
  ELSE
    RETURN 'MYTHIC';
  END IF;
END;
$$;


ALTER FUNCTION "public"."determine_rarity_outcome"("p_facility_level" integer, "p_suspicion_level" integer, "p_rarity_distribution" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."equip_item"("p_row_id" "uuid", "p_slot" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
    v_item_record RECORD;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    -- Get the item to equip
    SELECT row_id, item_id INTO v_item_record
    FROM public.inventory
    WHERE row_id = p_row_id AND user_id = v_user_id
    LIMIT 1;

    IF v_item_record IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Item not found or not owned by player');
    END IF;

    -- Unequip any item currently in this slot
    UPDATE public.inventory
    SET is_equipped = FALSE, equip_slot = NULL, slot_position = NULL, updated_at = NOW()
    WHERE user_id = v_user_id 
      AND lower(COALESCE(equip_slot, '')) = lower(COALESCE(p_slot, '')) 
      AND is_equipped = TRUE
      AND row_id != p_row_id;

    -- Equip the new item
    UPDATE public.inventory
    SET is_equipped = TRUE, equip_slot = p_slot, slot_position = NULL, updated_at = NOW()
    WHERE row_id = p_row_id;

    RETURN jsonb_build_object('success', true, 'row_id', p_row_id, 'slot', p_slot);
END;
$$;


ALTER FUNCTION "public"."equip_item"("p_row_id" "uuid", "p_slot" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."expand_bank_slots"("p_num_expansions" integer DEFAULT 1) RETURNS TABLE("success" boolean, "message" "text", "total_gems_spent" integer, "new_total_slots" integer, "player_gems_remaining" integer)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid;
  v_current_slots integer;
  v_total_cost integer := 0;
  v_new_slots integer;
  v_current_gems integer;
  i integer;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'Not authenticated'::text, 0::integer, 0::integer, 0::integer;
    RETURN;
  END IF;

  -- Get current bank and player gem status
  SELECT total_slots INTO v_current_slots
  FROM public.user_bank_account
  WHERE user_id = v_user_id;

  SELECT gems INTO v_current_gems
  FROM public.users
  WHERE auth_id = v_user_id;

  -- Check if at max capacity
  IF v_current_slots >= 200 THEN
    RETURN QUERY SELECT false, 'Bank at maximum capacity (200 slots)'::text, 0::integer, 200::integer, v_current_gems;
    RETURN;
  END IF;

  -- Calculate total cost for all expansions
  -- Each 25 slots: 50 gems (125-100), 100 gems (150-125), 200 gems (175-150), 500 gems (200-175)
  FOR i IN 1..p_num_expansions LOOP
    EXIT WHEN v_current_slots + (i * 25) >= 200;
    
    v_total_cost := v_total_cost + CASE 
      WHEN v_current_slots + (i * 25) = 125 THEN 50
      WHEN v_current_slots + (i * 25) = 150 THEN 100
      WHEN v_current_slots + (i * 25) = 175 THEN 200
      WHEN v_current_slots + (i * 25) = 200 THEN 500
      ELSE 50
    END;
  END LOOP;

  -- Check if player has enough gems
  IF v_total_cost > v_current_gems THEN
    RETURN QUERY SELECT false, 
      'Insufficient gems. Need ' || v_total_cost || ', have ' || v_current_gems::text, 
      0::integer, 
      v_current_slots::integer, 
      v_current_gems;
    RETURN;
  END IF;

  -- Deduct gems from player profile
  UPDATE public.users
  SET gems = gems - v_total_cost
  WHERE auth_id = v_user_id;

  -- Update bank slots
  v_new_slots := LEAST(v_current_slots + (p_num_expansions * 25), 200);
  UPDATE public.user_bank_account
  SET total_slots = v_new_slots,
      paid_slots_purchased = paid_slots_purchased + (v_new_slots - v_current_slots),
      updated_at = now()
  WHERE user_id = v_user_id;

  -- Log transaction
  INSERT INTO public.bank_transactions 
    (user_id, transaction_type, gem_cost, gems_before, gems_after, slots_before, slots_after, success)
  VALUES (v_user_id, 'expand', v_total_cost, v_current_gems, v_current_gems - v_total_cost, v_current_slots, v_new_slots, true);

  RETURN QUERY SELECT true,
    'Expanded by ' || (v_new_slots - v_current_slots) || ' slots for ' || v_total_cost || ' gems'::text,
    v_total_cost::integer,
    v_new_slots::integer,
    (v_current_gems - v_total_cost)::integer;
END;
$$;


ALTER FUNCTION "public"."expand_bank_slots"("p_num_expansions" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."finalize_crafted_item"("p_queue_item_id" "uuid") RETURNS TABLE("processed" boolean, "message" "text", "success" boolean, "success_rate" double precision, "roll" double precision)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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
    -- Mark failed and completed (so finalize is not called again)
    UPDATE public.craft_queue SET failed = true, is_completed = true WHERE id = p_queue_item_id;
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


ALTER FUNCTION "public"."finalize_crafted_item"("p_queue_item_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_referral_code"() RETURNS "text"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    result TEXT := '';
    i INT;
BEGIN
    FOR i IN 1..8 LOOP
        result := result || substr(chars, floor(random() * length(chars) + 1)::int, 1);
    END LOOP;
    RETURN result;
END;
$$;


ALTER FUNCTION "public"."generate_referral_code"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_bank_account"() RETURNS TABLE("account_id" "uuid", "total_slots" integer, "used_slots" integer, "free_slots_remaining" integer, "paid_slots_purchased" integer, "expansion_cost_next" integer, "can_expand" boolean, "last_accessed_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid;
  v_bank_id uuid;
  v_total integer;
  v_used integer;
  v_expansion_cost integer;
  v_free_slots_remaining integer;
  v_paid_slots_purchased integer;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Ensure bank account exists
  INSERT INTO public.user_bank_account (user_id) 
  VALUES (v_user_id)
  ON CONFLICT (user_id) DO NOTHING;

  -- Get current account status
  SELECT 
    uba.id, uba.total_slots, uba.used_slots, uba.free_slots_remaining, uba.paid_slots_purchased,
    CASE 
      WHEN uba.total_slots >= 200 THEN 0
      WHEN uba.total_slots >= 175 THEN 500
      WHEN uba.total_slots >= 150 THEN 300
      WHEN uba.total_slots >= 125 THEN 200
      ELSE 50
    END
  INTO v_bank_id, v_total, v_used, v_free_slots_remaining, v_paid_slots_purchased, v_expansion_cost
  FROM public.user_bank_account uba
  WHERE uba.user_id = v_user_id;

  -- Update last accessed
  UPDATE public.user_bank_account
  SET last_accessed_at = now()
  WHERE user_id = v_user_id;

  RETURN QUERY SELECT
    v_bank_id,
    v_total,
    v_used,
    v_free_slots_remaining,
    v_paid_slots_purchased,
    v_expansion_cost,
    (v_total < 200)::boolean,
    now();
END;
$$;


ALTER FUNCTION "public"."get_bank_account"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_bank_items"("p_category" "text" DEFAULT NULL::"text") RETURNS TABLE("items" "jsonb", "categories" "jsonb")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid;
  v_items jsonb;
  v_categories jsonb;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Get items (filter by category if provided)
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', bi.id::text,
    'item_id', bi.item_id,
    'name', i.name,
    'type', i.type,
    'rarity', bi.rarity,
    'icon', i.icon,
    'quantity', bi.quantity,
    'category', bi.category,
    'is_pinned', bi.is_pinned,
    'slot_position', bi.slot_position
  ) ORDER BY bi.is_pinned DESC, bi.stored_at DESC), '[]'::jsonb)
  INTO v_items
  FROM public.bank_items bi
  LEFT JOIN public.items i ON bi.item_id = i.id
  WHERE bi.user_id = v_user_id
    AND (p_category IS NULL OR bi.category = p_category);

  -- Get category summary
  SELECT jsonb_object_agg(category, cnt)
  INTO v_categories
  FROM (
    SELECT category, COUNT(*) as cnt
    FROM public.bank_items
    WHERE user_id = v_user_id
    GROUP BY category
  ) cat_counts;

  IF v_categories IS NULL THEN
    v_categories := '{"equipment": 0, "material": 0, "consumable": 0, "special": 0}'::jsonb;
  END IF;

  RETURN QUERY SELECT v_items, v_categories;
END;
$$;


ALTER FUNCTION "public"."get_bank_items"("p_category" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_craft_queue"() RETURNS TABLE("id" "uuid", "recipe_id" "uuid", "recipe_name" "text", "recipe_icon" "text", "batch_count" integer, "started_at" timestamp with time zone, "completes_at" timestamp with time zone, "is_completed" boolean, "claimed" boolean, "failed" boolean, "xp_reward" integer)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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


ALTER FUNCTION "public"."get_craft_queue"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_craft_recipes"("p_user_level" integer DEFAULT 1) RETURNS TABLE("id" "uuid", "recipe_id" "uuid", "name" "text", "output_item_id" "text", "output_name" "text", "output_quantity" integer, "output_rarity" "text", "item_type" "text", "recipe_type" "text", "required_level" integer, "production_time_seconds" integer, "success_rate" double precision, "xp_reward" integer, "ingredients" "jsonb")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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


ALTER FUNCTION "public"."get_craft_recipes"("p_user_level" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_current_user"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
    v_user JSONB;
BEGIN
    v_user_id := auth.uid();
    
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;
    
    SELECT jsonb_build_object(
        'id', id,
        'auth_id', auth_id,
        'username', username,
        'email', email,
        'display_name', display_name,
        'avatar_url', avatar_url,
        'level', level,
        'experience', experience,
        'gold', gold,
        'energy', energy,
        'max_energy', max_energy,
        'attack', attack,
        'defense', defense,
        'health', health,
        'max_health', max_health,
        'power', power,
        'tutorial_completed', tutorial_completed,
        'guild_id', guild_id,
        'guild_role', guild_role,
        'referral_code', referral_code,
        'created_at', created_at,
        'last_login_at', last_login_at
    )
    INTO v_user
    FROM game.users
    WHERE auth_id = v_user_id;
    
    IF v_user IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'User profile not found');
    END IF;
    
    RETURN jsonb_build_object('success', true, 'data', v_user);
END;
$$;


ALTER FUNCTION "public"."get_current_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_equipped_items"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
    v_equipped_items JSONB;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    SELECT jsonb_agg(
        jsonb_build_object(
            'row_id', inv.row_id,
            'item_id', inv.item_id,
            'equip_slot', inv.equip_slot,
            'enhancement_level', COALESCE(inv.enhancement_level, 0),
            'quantity', inv.quantity,
            'obtained_at', inv.obtained_at,
            'name', it.name,
            'description', it.description,
            'icon', it.icon,
            'item_type', it.type,
            'rarity', it.rarity,
            'attack', it.attack,
            'defense', it.defense,
            'health', it.health,
            'power', it.power,
            'required_level', COALESCE(it.required_level, 1),
            'required_class', it.required_class
        )
    )
    INTO v_equipped_items
    FROM public.inventory inv
    LEFT JOIN public.items it ON inv.item_id = it.id
    WHERE inv.user_id = v_user_id AND inv.is_equipped = TRUE;

    IF v_equipped_items IS NULL THEN
        v_equipped_items := '[]'::jsonb;
    END IF;

    RETURN jsonb_build_object('success', true, 'items', v_equipped_items);
END;
$$;


ALTER FUNCTION "public"."get_equipped_items"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_facility_recipes_rpc"("p_facility_type" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
    v_recipes JSONB := '[]'::jsonb;
    v_recipe RECORD;
    v_recipe_count INT := 0;
BEGIN
    v_user_id := auth.uid();
    
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;
    
    IF p_facility_type IS NULL OR p_facility_type = '' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Facility type required');
    END IF;
    
    -- Get recipes for this facility type - uses required_level (correct column name)
    FOR v_recipe IN 
        SELECT 
            id, 
            facility_type, 
            output_item_id, 
            output_quantity, 
            input_materials, 
            gold_cost, 
            duration_seconds, 
            required_level,
            success_rate, 
            base_suspicion_increase,
            production_speed_bonus,
            rarity_distribution,
            created_at
        FROM public.facility_recipes 
        WHERE facility_type = p_facility_type
        ORDER BY required_level ASC
    LOOP
        v_recipe_count := v_recipe_count + 1;
        
        v_recipes := v_recipes || jsonb_build_object(
            'id', v_recipe.id,
            'facility_type', v_recipe.facility_type,
            'output_item_id', v_recipe.output_item_id,
            'output_quantity', v_recipe.output_quantity,
            'input_materials', v_recipe.input_materials,
            'gold_cost', v_recipe.gold_cost,
            'duration_seconds', v_recipe.duration_seconds,
            'required_level', v_recipe.required_level,
            'success_rate', v_recipe.success_rate,
            'base_suspicion_increase', v_recipe.base_suspicion_increase,
            'production_speed_bonus', v_recipe.production_speed_bonus,
            'rarity_distribution', v_recipe.rarity_distribution,
            'created_at', v_recipe.created_at
        );
    END LOOP;
    
    RETURN jsonb_build_object(
        'success', true,
        'recipes', v_recipes,
        'count', v_recipe_count,
        'facility_type', p_facility_type
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;


ALTER FUNCTION "public"."get_facility_recipes_rpc"("p_facility_type" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_hospital_status"("p_auth_id" "uuid") RETURNS TABLE("in_hospital" boolean, "release_time" bigint, "hospital_reason" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COALESCE(u.hospital_until > NOW(), FALSE),
    EXTRACT(EPOCH FROM u.hospital_until)::BIGINT,
    u.hospital_reason
  FROM public.users u
  WHERE u.auth_id = p_auth_id
  LIMIT 1;
END;
$$;


ALTER FUNCTION "public"."get_hospital_status"("p_auth_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_inventory"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_auth_id UUID;
  v_items JSONB;
BEGIN
  v_auth_id := auth.uid();
  IF v_auth_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- SELECT inventory, dönen veriler:
  -- - Inventory satırı: row_id, item_id, quantity, slot_position, is_equipped, equip_slot, ...
  -- - Item catalog (items tablosundan LEFT JOIN varsa, yoksa NULL/default)
  SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb)
  INTO v_items
  FROM (
    SELECT
      i.row_id,
      i.item_id,
      i.quantity,
      i.slot_position,
      i.is_equipped,
      i.equip_slot AS equipped_slot,
      i.enhancement_level,
      i.is_favorite,
      i.pending_sync,
      i.obtained_at,
      i.created_at,
      i.updated_at,
      -- Item catalog data — items tablosu varsa join et, yoksa item_id'yi fallback olarak kullan
      COALESCE(it.name, i.item_id) AS name,
      COALESCE(it.description, '') AS description,
      COALESCE(it.icon, '📦') AS icon,
      COALESCE(it.type, 'misc') AS item_type,
      COALESCE(it.rarity, 'common') AS rarity,
      COALESCE(it.base_price, 0) AS base_price,
      COALESCE(it.vendor_sell_price, 0) AS vendor_sell_price,
      COALESCE(it.attack, 0) AS attack,
      COALESCE(it.defense, 0) AS defense,
      COALESCE(it.health, 0) AS health,
      COALESCE(it.power, 0) AS power,
      COALESCE(it.mana_restore, 0) AS mana,
      COALESCE(it.equip_slot, '') AS equip_slot,
      COALESCE(it.weapon_type, '') AS weapon_type,
      COALESCE(it.armor_type, '') AS armor_type,
      COALESCE(it.required_level, 1) AS required_level,
      COALESCE(it.can_enhance, false) AS can_enhance,
      COALESCE(it.max_enhancement, 0) AS max_enhancement,
      COALESCE(it.is_stackable, true) AS is_stackable
    FROM public.inventory i
    LEFT JOIN public.items it ON it.id = i.item_id
    WHERE i.user_id = v_auth_id
    ORDER BY i.slot_position NULLS LAST, i.created_at DESC
  ) t;

  RETURN jsonb_build_object('success', true, 'items', v_items);
END;
$$;


ALTER FUNCTION "public"."get_inventory"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_player_facilities_with_queue"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
    v_facilities JSONB;
    v_facility RECORD;
    v_queue_item RECORD;
    v_facility_obj JSONB;
    v_queue_array JSONB;
    v_facility_count INT := 0;
    v_queue_count INT := 0;
BEGIN
    v_user_id := auth.uid();
    RAISE NOTICE '[RPC] get_player_facilities_with_queue started. User: %', v_user_id;
    
    IF v_user_id IS NULL THEN
        RAISE NOTICE '[RPC] ERROR: User not authenticated';
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;
    
    v_facilities := '[]'::jsonb;
    
    -- Get all facilities for this user
    RAISE NOTICE '[RPC] Fetching facilities for user: %', v_user_id;
    FOR v_facility IN 
        SELECT * FROM public.facilities 
        WHERE user_id = v_user_id 
        ORDER BY type ASC
    LOOP
        v_facility_count := v_facility_count + 1;
        RAISE NOTICE '[RPC] Processing facility #%: id=%, type=%', v_facility_count, v_facility.id, v_facility.type;
        
        -- Build queue array for this facility
        v_queue_array := '[]'::jsonb;
        v_queue_count := 0;
        
        RAISE NOTICE '[RPC] Fetching queue items for facility %', v_facility.id;
        FOR v_queue_item IN 
            SELECT * FROM public.facility_queue 
            WHERE facility_id = v_facility.id 
            ORDER BY started_at ASC
        LOOP
            v_queue_count := v_queue_count + 1;
            RAISE NOTICE '[RPC] Queue item #%: id=%, recipe=%, completed_at=%', 
                v_queue_count, v_queue_item.id, v_queue_item.recipe_id, v_queue_item.completed_at;
            
            v_queue_array := v_queue_array || jsonb_build_object(
                'id', v_queue_item.id,
                'facility_id', v_queue_item.facility_id,
                'recipe_id', v_queue_item.recipe_id,
                'quantity', v_queue_item.quantity,
                'started_at', v_queue_item.started_at,
                'completed_at', v_queue_item.completed_at,
                'status', v_queue_item.status,
                'is_raided', v_queue_item.is_raided,
                'is_burned', v_queue_item.is_burned
            );
        END LOOP;
        
        RAISE NOTICE '[RPC] Facility % has % queue items', v_facility.id, v_queue_count;
        
        -- Build facility object with queue
        RAISE NOTICE '[RPC] Building facility object for: %', v_facility.type;
        v_facility_obj := jsonb_build_object(
            'id', v_facility.id,
            'user_id', v_facility.user_id,
            'type', v_facility.type,
            'level', v_facility.level,
            'suspicion', v_facility.suspicion_level,
            'is_active', v_facility.is_active,
            'production_started_at', v_facility.production_started_at,
            'created_at', v_facility.created_at,
            'updated_at', v_facility.updated_at,
            'facility_queue', v_queue_array
        );
        
        v_facilities := v_facilities || jsonb_build_array(v_facility_obj);
    END LOOP;
    
    RAISE NOTICE '[RPC] Completed. Total facilities: %, facilities_json_keys: %', 
        v_facility_count, jsonb_array_length(v_facilities);
    RAISE NOTICE '[RPC] Final response data: %', v_facilities;
    
    RETURN jsonb_build_object('success', true, 'data', v_facilities);
END;
$$;


ALTER FUNCTION "public"."get_player_facilities_with_queue"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'game'
    AS $$
BEGIN
    INSERT INTO public.users (auth_id, email, username, display_name)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
        COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1))
    )
    ON CONFLICT (auth_id) DO NOTHING;
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Failed to create game profile for user %: %', NEW.id, SQLERRM;
        RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."increment_facility_suspicion"("p_facility_id" "uuid", "p_amount" integer DEFAULT 5) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
    v_new_suspicion INT;
    v_global_suspicion INT;
BEGIN
    v_user_id := auth.uid();
    
    UPDATE public.facilities
    SET suspicion_level = LEAST(suspicion_level + p_amount, 100)
    WHERE id = p_facility_id AND user_id = v_user_id
    RETURNING suspicion_level INTO v_new_suspicion;
    
    IF v_new_suspicion IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Facility not found or not owned');
    END IF;
    
    -- NOTE: Don't update global_suspicion_level here!
    -- Client handles risk calculation and syncs via update_global_suspicion_level RPC
    -- This keeps risk sync centralized and prevents conflicts
    
    RETURN jsonb_build_object(
        'success', true,
        'facility_suspicion', v_new_suspicion,
        'global_suspicion', 0,
        'message', CASE WHEN v_new_suspicion >= 80 THEN 'High suspicion! Risk of prison!' ELSE 'OK' END
    );
END;
$$;


ALTER FUNCTION "public"."increment_facility_suspicion"("p_facility_id" "uuid", "p_amount" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."organize_bank"("p_item_id" "uuid", "p_pin" boolean) RETURNS TABLE("success" boolean, "message" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'Not authenticated'::text;
    RETURN;
  END IF;

  UPDATE public.bank_items
  SET is_pinned = p_pin,
      pinned_at = CASE WHEN p_pin THEN now() ELSE NULL END,
      updated_at = now()
  WHERE id = p_item_id AND user_id = v_user_id;

  RETURN QUERY SELECT true, 
    CASE WHEN p_pin THEN 'Item pinned' ELSE 'Item unpinned' END::text;
END;
$$;


ALTER FUNCTION "public"."organize_bank"("p_item_id" "uuid", "p_pin" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."place_sell_order"("p_item_row_id" "uuid", "p_quantity" integer, "p_price" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
    v_item_record RECORD;
    v_item_data JSONB;
BEGIN
    v_user_id := auth.uid();
    
    -- 1. Verify item ownership and quantity
    SELECT * INTO v_item_record
    FROM public.inventory
    WHERE row_id = p_item_row_id AND user_id = v_user_id;
    
    IF v_item_record IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Item not found');
    END IF;
    
    IF v_item_record.quantity < p_quantity THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not enough quantity');
    END IF;

    IF v_item_record.is_equipped = TRUE THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cannot sell equipped item');
    END IF;

    -- 2. Prepare Item Data (Snapshot stats, enhancement, etc.)
    -- Note: inventory table uses enhancement_level, not upgrade_level
    v_item_data := jsonb_build_object(
        'enhancement_level', v_item_record.enhancement_level, 
        'obtained_at', v_item_record.obtained_at
    );

    -- 3. Create Market Order
    INSERT INTO public.market_orders (
        seller_id, item_id, quantity, price, item_data
    ) VALUES (
        v_user_id, v_item_record.item_id, p_quantity, p_price, v_item_data
    );

    -- 4. Update Inventory
    IF v_item_record.quantity = p_quantity THEN
        -- Sold all -> Delete row
        DELETE FROM public.inventory WHERE row_id = p_item_row_id;
    ELSE
        -- Sold partial -> Decrease quantity
        UPDATE public.inventory 
        SET quantity = quantity - p_quantity 
        WHERE row_id = p_item_row_id;
    END IF;

    RETURN jsonb_build_object('success', true);
END;
$$;


ALTER FUNCTION "public"."place_sell_order"("p_item_row_id" "uuid", "p_quantity" integer, "p_price" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."purchase_market_listing"("p_order_id" "uuid", "p_quantity" integer DEFAULT 1, "p_is_stackable" boolean DEFAULT false) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_order RECORD;
    v_buyer_id UUID;
    v_seller_id UUID;
    v_total_price BIGINT;
    v_buyer_gold BIGINT;
    v_item_data JSONB;
    v_commission_rate NUMERIC := 0.05; -- 5% commission
    v_commission_amount BIGINT;
    v_seller_revenue BIGINT;
    v_seller_gold BIGINT;
    v_remaining_qty INT;
    v_transfer_qty INT;
    v_dest_slot INT;
    v_dest_qty INT;
    v_space INT;
    v_enhancement_level INT;
BEGIN
    -- Get current user (buyer)
    v_buyer_id := auth.uid();
    IF v_buyer_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    -- Get Order
    SELECT * INTO v_order FROM public.market_orders WHERE id = p_order_id AND status = 'active' FOR UPDATE;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Listing not found or no longer active');
    END IF;

    v_seller_id := v_order.seller_id;
    
    -- Prevent self-trading
    IF v_seller_id = v_buyer_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cannot buy your own listing');
    END IF;
    
    -- Check Quantity
    IF p_quantity <= 0 THEN
         RETURN jsonb_build_object('success', false, 'error', 'Invalid quantity');
    END IF;
    
    IF v_order.quantity < p_quantity THEN
         RETURN jsonb_build_object('success', false, 'error', 'Not enough quantity available (Stock: ' || v_order.quantity || ')');
    END IF;

    -- Calculate Total Price
    v_total_price := v_order.price * p_quantity;
    
    -- Check Buyer Gold
    SELECT gold INTO v_buyer_gold FROM public.users WHERE auth_id = v_buyer_id OR id = v_buyer_id;
    
    IF v_buyer_gold < v_total_price THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not enough gold');
    END IF;

    -- Transaction
    -- 1. Deduct Gold from Buyer
    UPDATE public.users 
    SET gold = gold - v_total_price 
    WHERE auth_id = v_buyer_id OR id = v_buyer_id
    RETURNING gold INTO v_buyer_gold;
    
    -- 2. Add Gold to Seller (minus commission)
    v_commission_amount := FLOOR(v_total_price * v_commission_rate);
    v_seller_revenue := v_total_price - v_commission_amount;
    
    UPDATE public.users 
    SET gold = gold + v_seller_revenue 
    WHERE auth_id = v_seller_id OR id = v_seller_id
    RETURNING gold INTO v_seller_gold;
    
    -- 3. Transfer Item to Buyer with Stacking Logic
    v_item_data := v_order.item_data;
    v_enhancement_level := COALESCE((v_item_data->>'enhancement_level')::int, 0);
    v_remaining_qty := p_quantity;
    
    -- Handling Logic based on Stackability
    IF p_is_stackable THEN
        -- Legacy Stackable Logic (Potion, etc)
        WHILE v_remaining_qty > 0 LOOP
            v_dest_slot := NULL;
            v_dest_qty := 0;
            
            -- Try to find existing partial stack
            SELECT slot_position, quantity INTO v_dest_slot, v_dest_qty
            FROM public.inventory
            WHERE user_id = v_buyer_id 
              AND item_id = v_order.item_id
              AND enhancement_level = v_enhancement_level
              AND quantity < 50
            ORDER BY quantity DESC 
            LIMIT 1;
            
            IF v_dest_slot IS NOT NULL THEN
                -- Fill Existing Stack
                v_space := 50 - v_dest_qty;
                v_transfer_qty := LEAST(v_remaining_qty, v_space);
                
                UPDATE public.inventory 
                SET quantity = quantity + v_transfer_qty
                WHERE user_id = v_buyer_id AND slot_position = v_dest_slot;
                
                v_remaining_qty := v_remaining_qty - v_transfer_qty;
            ELSE
                -- New Slot
                SELECT MIN(slot_num) INTO v_dest_slot
                FROM generate_series(0, 19) slot_num
                WHERE NOT EXISTS (SELECT 1 FROM public.inventory WHERE user_id = v_buyer_id AND slot_position = slot_num);
                
                IF v_dest_slot IS NULL THEN
                    RAISE EXCEPTION 'Inventory full';
                END IF;
                
                v_transfer_qty := LEAST(v_remaining_qty, 50);
                
                INSERT INTO public.inventory (
                    user_id, item_id, quantity, slot_position, 
                    enhancement_level, is_equipped, obtained_at
                )
                VALUES (
                    v_buyer_id, 
                    v_order.item_id, 
                    v_transfer_qty, 
                    v_dest_slot, 
                    v_enhancement_level,
                    false,
                    EXTRACT(EPOCH FROM NOW())::bigint
                );
                
                v_remaining_qty := v_remaining_qty - v_transfer_qty;
            END IF;
        END LOOP;
        
    ELSE
        -- Non-Stackable Logic (Equipment)
        -- Must find separate slots for EACH item if p_quantity > 1 (unlikely for equip, but safe to handle)
        FOR i IN 1..p_quantity LOOP
             -- Find ONE empty slot
             v_dest_slot := NULL;
             SELECT MIN(slot_num) INTO v_dest_slot
             FROM generate_series(0, 19) slot_num
             WHERE NOT EXISTS (SELECT 1 FROM public.inventory WHERE user_id = v_buyer_id AND slot_position = slot_num);
             
             IF v_dest_slot IS NULL THEN
                 RAISE EXCEPTION 'Inventory full';
             END IF;
             
             INSERT INTO public.inventory (
                user_id, item_id, quantity, slot_position, 
                enhancement_level, is_equipped, obtained_at
            )
            VALUES (
                v_buyer_id, 
                v_order.item_id, 
                1, -- Always 1 for non-stackable
                v_dest_slot, 
                v_enhancement_level,
                false,
                EXTRACT(EPOCH FROM NOW())::bigint
            );
        END LOOP;
    END IF;
    
    -- 4. Update or Delete Order
    IF v_order.quantity = p_quantity THEN
        DELETE FROM public.market_orders WHERE id = p_order_id;
    ELSE
        UPDATE public.market_orders SET quantity = quantity - p_quantity WHERE id = p_order_id;
    END IF;
    
    -- 5. Track History
    INSERT INTO public.market_history (item_id, seller_id, buyer_id, price, quantity, sold_at)
    VALUES (v_order.item_id, v_seller_id, v_buyer_id, v_order.price, p_quantity, NOW());
    
    RETURN jsonb_build_object(
        'success', true, 
        'message', 'Item purchased',
        'new_buyer_gold', v_buyer_gold,
        'new_seller_gold', v_seller_gold
    );

EXCEPTION 
    WHEN OTHERS THEN
         IF SQLERRM = 'Inventory full' THEN
             RETURN jsonb_build_object('success', false, 'error', 'Inventory full');
         END IF;
         RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;


ALTER FUNCTION "public"."purchase_market_listing"("p_order_id" "uuid", "p_quantity" integer, "p_is_stackable" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."refund_partial_materials"("p_user_id" "uuid", "p_ingredients" "jsonb", "p_refund_rate" double precision) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_ingredient jsonb;
    v_item_id TEXT;
    v_quantity INT;
    v_refund_quantity INT;
BEGIN
    FOR v_ingredient IN SELECT jsonb_array_elements(p_ingredients) LOOP
        v_item_id := v_ingredient->>'item_id';
        v_quantity := (v_ingredient->>'quantity')::INT;
        v_refund_quantity := FLOOR(v_quantity * p_refund_rate)::INT;
        
        IF v_refund_quantity > 0 THEN
            INSERT INTO inventory (user_id, item_id, quantity)
            VALUES (p_user_id, v_item_id, v_refund_quantity)
            ON CONFLICT (user_id, item_id) DO UPDATE
            SET quantity = inventory.quantity + v_refund_quantity;
        END IF;
    END LOOP;
END;
$$;


ALTER FUNCTION "public"."refund_partial_materials"("p_user_id" "uuid", "p_ingredients" "jsonb", "p_refund_rate" double precision) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."release_from_hospital"("p_auth_id" "uuid", "p_method" "text", "p_cost" integer DEFAULT 0) RETURNS TABLE("success" boolean, "new_gems" integer)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_current_gems INT;
BEGIN
  -- Get current gems
  SELECT gems INTO v_current_gems
  FROM public.users
  WHERE auth_id = p_auth_id;
  
  -- Check if player has enough gems
  IF p_method = 'gems' AND v_current_gems < p_cost THEN
    RETURN QUERY SELECT FALSE, v_current_gems;
    RETURN;
  END IF;
  
  -- Update user
  UPDATE public.users
  SET 
    hospital_until = NULL,
    hospital_reason = NULL,
    gems = CASE WHEN p_method = 'gems' THEN gems - p_cost ELSE gems END,
    updated_at = NOW()
  WHERE auth_id = p_auth_id;
  
  -- Return success with new gems count
  SELECT gems INTO v_current_gems
  FROM public.users
  WHERE auth_id = p_auth_id;
  
  RETURN QUERY SELECT TRUE, v_current_gems;
END;
$$;


ALTER FUNCTION "public"."release_from_hospital"("p_auth_id" "uuid", "p_method" "text", "p_cost" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."release_from_prison"("p_use_bail" boolean DEFAULT false) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
    v_user RECORD;
    v_now TIMESTAMPTZ;
    v_bail_gems INT;
    v_remaining_mins INT;
BEGIN
    v_user_id := auth.uid();
    v_now := NOW();

    -- Use public.users with auth_id
    SELECT * INTO v_user FROM public.users WHERE auth_id = v_user_id;

    IF v_user IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'User not found in public.users'); END IF;

    IF v_user.prison_until IS NULL OR v_user.prison_until <= v_now THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not in prison');
    END IF;

    IF p_use_bail THEN
        v_remaining_mins := CEIL(EXTRACT(EPOCH FROM (v_user.prison_until - v_now)) / 60);
        v_bail_gems := GREATEST(1, v_remaining_mins);

        IF v_user.gems < v_bail_gems THEN
            RETURN jsonb_build_object('success', false, 'error', 'Insufficient gems', 'cost', v_bail_gems);
        END IF;

        -- Deduct gems and release
        UPDATE public.users SET
            gems = gems - v_bail_gems,
            in_prison = false,
            prison_until = NULL,
            prison_reason = NULL,
            updated_at = v_now
        WHERE auth_id = v_user_id;

        RETURN jsonb_build_object('success', true, 'message', 'Released from prison via bail', 'gems_spent', v_bail_gems);
    ELSE
        -- Time-based release
        UPDATE public.users SET
            in_prison = false,
            prison_until = NULL,
            prison_reason = NULL,
            updated_at = v_now
        WHERE auth_id = v_user_id;

        RETURN jsonb_build_object('success', true, 'message', 'Prison time served');
    END IF;
END;
$$;


ALTER FUNCTION "public"."release_from_prison"("p_use_bail" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."remove_inventory_item"("p_item_id" "text", "p_quantity" integer DEFAULT 1) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
    v_user_id uuid;
    v_current_quantity int;
    v_row_id uuid;
begin
    -- Get User ID
    v_user_id := auth.uid();
    if v_user_id is null then
        return jsonb_build_object('success', false, 'error', 'Not authenticated');
    end if;

    -- Validate quantity
    if p_quantity <= 0 then
        return jsonb_build_object('success', false, 'error', 'Quantity must be positive');
    end if;

    -- Find the inventory item and get current quantity
    select inv.row_id, inv.quantity
    into v_row_id, v_current_quantity
    from public.inventory inv
    where inv.user_id = v_user_id
      and inv.item_id = p_item_id
    limit 1;

    -- Check if item exists
    if v_row_id is null then
        return jsonb_build_object('success', false, 'error', 'Item not found in inventory');
    end if;

    -- Check if enough quantity
    if v_current_quantity < p_quantity then
        return jsonb_build_object(
            'success', false, 
            'error', format('Not enough items (have: %s, trying to remove: %s)', v_current_quantity, p_quantity)
        );
    end if;

    -- Remove or update quantity
    if v_current_quantity = p_quantity then
        -- Delete the entire row
        delete from public.inventory
        where row_id = v_row_id
          and user_id = v_user_id;
    else
        -- Decrease quantity
        update public.inventory
        set quantity = quantity - p_quantity,
            updated_at = now()
        where row_id = v_row_id
          and user_id = v_user_id;
    end if;

    return jsonb_build_object(
        'success', true, 
        'item_id', p_item_id,
        'removed_quantity', p_quantity,
        'remaining_quantity', greatest(0, v_current_quantity - p_quantity)
    );
end;
$$;


ALTER FUNCTION "public"."remove_inventory_item"("p_item_id" "text", "p_quantity" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."remove_inventory_item_by_row"("p_row_id" "uuid", "p_quantity" integer DEFAULT 1) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_user uuid := auth.uid();
  v_current_qty int;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT quantity INTO v_current_qty
  FROM public.inventory
  WHERE row_id = p_row_id AND user_id = v_user;

  IF v_current_qty IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Item not found or not owned');
  END IF;

  IF p_quantity >= v_current_qty THEN
    DELETE FROM public.inventory
    WHERE row_id = p_row_id AND user_id = v_user;
    RETURN jsonb_build_object('success', true);
  END IF;

  UPDATE public.inventory
  SET quantity = quantity - p_quantity, updated_at = NOW()
  WHERE row_id = p_row_id AND user_id = v_user;

  RETURN jsonb_build_object('success', true);
END;
$$;


ALTER FUNCTION "public"."remove_inventory_item_by_row"("p_row_id" "uuid", "p_quantity" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."reset_all_facility_production"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
    v_deleted_queue INT := 0;
    v_reset_count INT := 0;
BEGIN
    v_user_id := auth.uid();
    
    -- Clear all production queues for this user
    DELETE FROM public.facility_queue
    WHERE facility_id IN (
        SELECT id FROM public.facilities WHERE user_id = v_user_id
    ) AND status = 'in_progress';
    
    GET DIAGNOSTICS v_deleted_queue = ROW_COUNT;
    
    -- Reset all facilities for this user
    UPDATE public.facilities
    SET 
        production_started_at = NULL,
        last_production_collected_at = NULL,
        suspicion_level = 0,
        updated_at = NOW()
    WHERE user_id = v_user_id;
    
    GET DIAGNOSTICS v_reset_count = ROW_COUNT;
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'All facility production reset',
        'facilities_reset', v_reset_count,
        'queue_items_deleted', COALESCE(v_deleted_queue, 0)
    );
END;
$$;


ALTER FUNCTION "public"."reset_all_facility_production"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."reset_facility_production"("p_facility_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
    v_facility RECORD;
    v_deleted_queue INT := 0;
BEGIN
    v_user_id := auth.uid();
    
    SELECT * INTO v_facility FROM public.facilities
    WHERE id = p_facility_id AND user_id = v_user_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Facility not found or not owned');
    END IF;
    
    -- Clear production queue for this facility
    DELETE FROM public.facility_queue
    WHERE facility_id = p_facility_id AND status = 'in_progress'
    RETURNING COUNT(*) INTO v_deleted_queue;
    
    -- Reset facility production
    UPDATE public.facilities
    SET 
        production_started_at = NULL,
        last_production_collected_at = NULL,
        suspicion_level = 0,
        updated_at = NOW()
    WHERE id = p_facility_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Facility production reset',
        'queue_items_deleted', COALESCE(v_deleted_queue, 0),
        'facility_id', p_facility_id,
        'facility_type', v_facility.type
    );
END;
$$;


ALTER FUNCTION "public"."reset_facility_production"("p_facility_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sell_inventory_item_by_row"("p_row_id" "uuid", "p_quantity" integer DEFAULT 1) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_current_qty int;
  v_vendor_sell_price int;
  v_sell_qty int;
  v_gold_earned int := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid quantity');
  END IF;

  SELECT quantity, COALESCE(vendor_sell_price, 0)
  INTO v_current_qty, v_vendor_sell_price
  FROM public.inventory
  WHERE row_id = p_row_id
    AND user_id = v_user_id
  FOR UPDATE;

  IF v_current_qty IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Item not found or not owned');
  END IF;

  v_sell_qty := LEAST(v_current_qty, p_quantity);
  v_gold_earned := GREATEST(0, v_vendor_sell_price * v_sell_qty);

  IF v_sell_qty >= v_current_qty THEN
    DELETE FROM public.inventory
    WHERE row_id = p_row_id
      AND user_id = v_user_id;
  ELSE
    UPDATE public.inventory
    SET quantity = quantity - v_sell_qty,
        updated_at = NOW()
    WHERE row_id = p_row_id
      AND user_id = v_user_id;
  END IF;

  UPDATE public.users
  SET gold = COALESCE(gold, 0) + v_gold_earned
  WHERE auth_id = v_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'sold_quantity', v_sell_qty,
    'currency', 'gold',
    'gold_earned', v_gold_earned,
    'gems_earned', 0
  );
END;
$$;


ALTER FUNCTION "public"."sell_inventory_item_by_row"("p_row_id" "uuid", "p_quantity" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_queue_estimated_completion"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF NEW.estimated_completion_at IS NULL AND NEW.duration_seconds IS NOT NULL THEN
    NEW.estimated_completion_at := NEW.started_at + (NEW.duration_seconds || ' seconds')::INTERVAL;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."set_queue_estimated_completion"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_referral_code"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    IF NEW.referral_code IS NULL THEN
        NEW.referral_code := generate_referral_code();
        -- Ensure uniqueness
        WHILE EXISTS (SELECT 1 FROM game.users WHERE referral_code = NEW.referral_code) LOOP
            NEW.referral_code := generate_referral_code();
        END LOOP;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."set_referral_code"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."split_stack_item"("p_row_id" "uuid", "p_split_quantity" integer, "p_target_slot" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_user_id uuid;
  v_row record;
  v_is_stackable boolean;
  v_new_row jsonb;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF p_split_quantity <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid split quantity');
  END IF;

  SELECT * INTO v_row FROM public.inventory WHERE row_id = p_row_id AND user_id = v_user_id LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Item not found');
  END IF;

  -- Ensure stackable and have enough quantity
  SELECT COALESCE(is_stackable, true) INTO v_is_stackable FROM public.items WHERE id = v_row.item_id;
  IF NOT v_is_stackable THEN
    RETURN jsonb_build_object('success', false, 'error', 'Item is not stackable');
  END IF;

  IF v_row.quantity <= p_split_quantity THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not enough quantity to split');
  END IF;

  -- Validate target slot
  IF p_target_slot < 0 OR p_target_slot > 9999 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid target slot');
  END IF;

  -- Ensure target slot is not occupied for this user
  IF EXISTS (SELECT 1 FROM public.inventory WHERE user_id = v_user_id AND slot_position = p_target_slot) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Target slot occupied');
  END IF;

  -- Reduce original stack
  UPDATE public.inventory
  SET quantity = quantity - p_split_quantity, updated_at = NOW()
  WHERE row_id = v_row.row_id AND user_id = v_user_id
  RETURNING to_jsonb(public.inventory.*) INTO v_row;

  -- Insert new split row
  INSERT INTO public.inventory (
    user_id, item_id, quantity, enhancement_level, is_equipped, obtained_at, slot_position
  ) VALUES (
    v_user_id, v_row.item_id, p_split_quantity, COALESCE(v_row.enhancement_level, 0), false, EXTRACT(EPOCH FROM NOW())::bigint, p_target_slot
  ) RETURNING to_jsonb(public.inventory.*) INTO v_new_row;

  RETURN jsonb_build_object('success', true, 'new_row', v_new_row);
END;
$$;


ALTER FUNCTION "public"."split_stack_item"("p_row_id" "uuid", "p_split_quantity" integer, "p_target_slot" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."start_facility_production"("p_facility_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
    v_facility RECORD;
    v_current_energy INT;
    v_energy_cost INT := 50;
BEGIN
    v_user_id := auth.uid();
    
    SELECT * INTO v_facility
    FROM public.facilities
    WHERE id = p_facility_id AND user_id = v_user_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Facility not found or not owned');
    END IF;
    
    SELECT energy INTO v_current_energy FROM public.users WHERE id = v_user_id;
    IF v_current_energy < v_energy_cost THEN
        RETURN jsonb_build_object('success', false, 'error', 'Insufficient energy');
    END IF;
    
    UPDATE public.users
    SET energy = energy - v_energy_cost
    WHERE id = v_user_id;
    
    UPDATE public.facilities
    SET production_started_at = NOW(),
        updated_at = NOW()
    WHERE id = p_facility_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Production started',
        'new_energy', v_current_energy - v_energy_cost,
        'production_started_at', NOW()
    );
END;
$$;


ALTER FUNCTION "public"."start_facility_production"("p_facility_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."start_facility_production"("p_facility_id" "uuid", "p_recipe_id" "text", "p_quantity" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
    v_facility RECORD;
    v_recipe RECORD;
    v_total_gold INT;
    v_now BIGINT;
    v_duration INT;
    v_suspicion_inc INT;
    v_mat_id TEXT;
    v_mat_req_single INT;
    v_mat_total_needed INT;
    v_user_has INT;
    v_deduct INT;
    v_inv_row RECORD;
BEGIN
    v_user_id := auth.uid();
    v_now := EXTRACT(EPOCH FROM NOW())::BIGINT;
    
    SELECT * INTO v_facility FROM public.facilities WHERE id = p_facility_id AND user_id = v_user_id;
    IF v_facility IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'Facility not found'); END IF;
    SELECT * INTO v_recipe FROM public.facility_recipes WHERE id = p_recipe_id;
    IF v_recipe IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'Recipe not found'); END IF;
    IF v_facility.level < v_recipe.required_level THEN RETURN jsonb_build_object('success', false, 'error', 'Facility level too low'); END IF;
    
    v_total_gold := v_recipe.gold_cost * p_quantity;
    
    -- CHECK public.users
    IF (SELECT gold FROM public.users WHERE id = v_user_id) < v_total_gold THEN
         RETURN jsonb_build_object('success', false, 'error', 'Insufficient gold');
    END IF;
    
    -- Check Materials
    FOR v_mat_id, v_mat_req_single IN SELECT * FROM jsonb_each_text(v_recipe.input_materials)
    LOOP
        v_mat_total_needed := v_mat_req_single::INT * p_quantity;
        SELECT COALESCE(SUM(quantity), 0) INTO v_user_has FROM public.inventory WHERE user_id = v_user_id AND item_id = v_mat_id;
        IF v_user_has < v_mat_total_needed THEN RAISE EXCEPTION 'Insufficient material: %', v_mat_id; END IF;
    END LOOP;
    
    -- UPDATE public.users
    UPDATE public.users SET gold = gold - v_total_gold WHERE id = v_user_id;
    
    -- Deduct Materials
    FOR v_mat_id, v_mat_req_single IN SELECT * FROM jsonb_each_text(v_recipe.input_materials)
    LOOP
        v_mat_total_needed := v_mat_req_single::INT * p_quantity;
        WHILE v_mat_total_needed > 0 LOOP
            SELECT row_id, quantity INTO v_inv_row FROM public.inventory WHERE user_id = v_user_id AND item_id = v_mat_id ORDER BY quantity ASC LIMIT 1;
            v_deduct := LEAST(v_inv_row.quantity, v_mat_total_needed);
            UPDATE public.inventory SET quantity = quantity - v_deduct WHERE row_id = v_inv_row.row_id;
            DELETE FROM public.inventory WHERE row_id = v_inv_row.row_id AND quantity <= 0;
            v_mat_total_needed := v_mat_total_needed - v_deduct;
        END LOOP;
    END LOOP;

    v_suspicion_inc := v_recipe.base_suspicion_increase * p_quantity;
    UPDATE public.facilities SET suspicion = LEAST(100, suspicion + v_suspicion_inc) WHERE id = p_facility_id;
    
    v_duration := (v_recipe.duration_seconds * p_quantity);
    INSERT INTO public.facility_queue (facility_id, recipe_id, quantity, started_at, completed_at)
    VALUES (p_facility_id, p_recipe_id, p_quantity, v_now, v_now + v_duration);
    
    RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;


ALTER FUNCTION "public"."start_facility_production"("p_facility_id" "uuid", "p_recipe_id" "text", "p_quantity" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."swap_inventory_bank"("p_source_type" "text", "p_source_id" "uuid", "p_target_type" "text", "p_target_id" "uuid", "p_quantity" integer DEFAULT NULL::integer, "p_target_slot" integer DEFAULT NULL::integer) RETURNS TABLE("success" boolean, "message" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid;
  v_source_item_id text;
  v_source_qty integer;
  v_source_slot integer;
  v_target_item_id text;
  v_target_qty integer;
  v_target_slot integer;
  v_max_stack integer;
  v_transfer_qty integer;
  v_remaining_qty integer;
  v_actual_transfer integer;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'Not authenticated'::text;
    RETURN;
  END IF;

  IF p_source_type = 'inventory' THEN
    SELECT item_id, quantity, slot_position INTO v_source_item_id, v_source_qty, v_source_slot
    FROM public.inventory
    WHERE row_id = p_source_id AND user_id = v_user_id;
  ELSIF p_source_type = 'bank' THEN
    SELECT item_id, quantity, slot_position INTO v_source_item_id, v_source_qty, v_source_slot
    FROM public.bank_items
    WHERE id = p_source_id AND user_id = v_user_id;
  END IF;

  IF v_source_item_id IS NULL THEN
    RETURN QUERY SELECT false, 'Source item not found'::text;
    RETURN;
  END IF;

  v_actual_transfer := COALESCE(p_quantity, v_source_qty);
  v_actual_transfer := LEAST(v_actual_transfer, v_source_qty);
  IF v_actual_transfer <= 0 THEN
    RETURN QUERY SELECT false, 'Invalid transfer quantity'::text;
    RETURN;
  END IF;

  IF p_target_id IS NOT NULL AND p_source_type = p_target_type AND p_source_id = p_target_id THEN
    RETURN QUERY SELECT true, 'Source and target are the same slot'::text;
    RETURN;
  END IF;

  IF p_target_id IS NOT NULL THEN
    IF p_target_type = 'inventory' THEN
      SELECT item_id, quantity, slot_position INTO v_target_item_id, v_target_qty, v_target_slot
      FROM public.inventory
      WHERE row_id = p_target_id AND user_id = v_user_id;
    ELSIF p_target_type = 'bank' THEN
      SELECT item_id, quantity, slot_position INTO v_target_item_id, v_target_qty, v_target_slot
      FROM public.bank_items
      WHERE id = p_target_id AND user_id = v_user_id;
    END IF;
  END IF;

  v_target_slot := COALESCE(v_target_slot, p_target_slot);
  IF v_target_slot IS NULL THEN
    RETURN QUERY SELECT false, 'Target slot is required'::text;
    RETURN;
  END IF;

  SELECT max_stack INTO v_max_stack
  FROM public.items WHERE id = v_source_item_id;
  v_max_stack := COALESCE(v_max_stack, 1);

  IF v_target_item_id IS NOT NULL AND v_target_item_id = v_source_item_id THEN
    v_transfer_qty := LEAST(v_actual_transfer, v_max_stack - v_target_qty);
    IF v_transfer_qty <= 0 THEN
      RETURN QUERY SELECT false, 'Target stack is full'::text;
      RETURN;
    END IF;

    v_remaining_qty := v_source_qty - v_transfer_qty;

    IF p_target_type = 'inventory' THEN
      UPDATE public.inventory SET quantity = quantity + v_transfer_qty, updated_at = now()
      WHERE row_id = p_target_id;
    ELSIF p_target_type = 'bank' THEN
      UPDATE public.bank_items SET quantity = quantity + v_transfer_qty, updated_at = now()
      WHERE id = p_target_id;
    END IF;

    IF v_remaining_qty > 0 THEN
      IF p_source_type = 'inventory' THEN
        UPDATE public.inventory SET quantity = v_remaining_qty, updated_at = now()
        WHERE row_id = p_source_id;
      ELSIF p_source_type = 'bank' THEN
        UPDATE public.bank_items SET quantity = v_remaining_qty, updated_at = now()
        WHERE id = p_source_id;
      END IF;
    ELSE
      IF p_source_type = 'inventory' THEN
        DELETE FROM public.inventory WHERE row_id = p_source_id;
      ELSIF p_source_type = 'bank' THEN
        DELETE FROM public.bank_items WHERE id = p_source_id;
        UPDATE public.user_bank_account
        SET used_slots = GREATEST(0, used_slots - 1), updated_at = now()
        WHERE user_id = v_user_id;
      END IF;
    END IF;

    RETURN QUERY SELECT true, 'Items merged successfully'::text;
    RETURN;
  END IF;

  IF v_target_item_id IS NULL THEN
    IF p_target_type = 'inventory' THEN
      IF EXISTS (
        SELECT 1 FROM public.inventory
        WHERE user_id = v_user_id
          AND is_equipped = FALSE
          AND slot_position = v_target_slot
          AND row_id <> p_source_id
      ) THEN
        RETURN QUERY SELECT false, 'Target inventory slot is occupied'::text;
        RETURN;
      END IF;
    ELSIF p_target_type = 'bank' THEN
      IF EXISTS (
        SELECT 1 FROM public.bank_items
        WHERE user_id = v_user_id
          AND slot_position = v_target_slot
          AND id <> p_source_id
      ) THEN
        RETURN QUERY SELECT false, 'Target bank slot is occupied'::text;
        RETURN;
      END IF;
    END IF;

    IF p_source_type = 'inventory' AND p_target_type = 'bank' THEN
      INSERT INTO public.bank_items (user_id, item_id, quantity, category, slot_position)
      SELECT v_user_id, inv.item_id, v_actual_transfer,
        CASE
          WHEN it.type = 'equipment' THEN 'equipment'
          WHEN it.type = 'consumable' THEN 'consumable'
          WHEN it.type = 'special' THEN 'special'
          ELSE 'material'
        END,
        v_target_slot
      FROM public.inventory inv
      JOIN public.items it ON inv.item_id = it.id
      WHERE inv.row_id = p_source_id;

      IF v_source_qty - v_actual_transfer > 0 THEN
        UPDATE public.inventory SET quantity = v_source_qty - v_actual_transfer, updated_at = now()
        WHERE row_id = p_source_id;
      ELSE
        DELETE FROM public.inventory WHERE row_id = p_source_id;
      END IF;

      UPDATE public.user_bank_account SET used_slots = used_slots + 1, updated_at = now()
      WHERE user_id = v_user_id;

    ELSIF p_source_type = 'bank' AND p_target_type = 'inventory' THEN
      INSERT INTO public.inventory (user_id, item_id, quantity, slot_position)
      SELECT v_user_id, b.item_id, v_actual_transfer, v_target_slot
      FROM public.bank_items b
      WHERE b.id = p_source_id;

      IF v_source_qty - v_actual_transfer > 0 THEN
        UPDATE public.bank_items SET quantity = v_source_qty - v_actual_transfer, updated_at = now()
        WHERE id = p_source_id;
      ELSE
        DELETE FROM public.bank_items WHERE id = p_source_id;
        UPDATE public.user_bank_account
        SET used_slots = GREATEST(0, used_slots - 1), updated_at = now()
        WHERE user_id = v_user_id;
      END IF;

    ELSIF p_source_type = 'inventory' AND p_target_type = 'inventory' THEN
      IF v_actual_transfer < v_source_qty THEN
        RETURN QUERY SELECT false, 'Partial move is only allowed between inventory and bank'::text;
        RETURN;
      END IF;

      UPDATE public.inventory
      SET slot_position = v_target_slot,
          updated_at = now()
      WHERE row_id = p_source_id;

    ELSIF p_source_type = 'bank' AND p_target_type = 'bank' THEN
      IF v_actual_transfer < v_source_qty THEN
        RETURN QUERY SELECT false, 'Partial move is only allowed between inventory and bank'::text;
        RETURN;
      END IF;

      UPDATE public.bank_items
      SET slot_position = v_target_slot,
          updated_at = now()
      WHERE id = p_source_id;
    END IF;

    RETURN QUERY SELECT true, 'Item moved to empty slot'::text;
    RETURN;
  END IF;

  IF v_actual_transfer < v_source_qty THEN
    RETURN QUERY SELECT false, 'Partial swap is not allowed on different items'::text;
    RETURN;
  END IF;

  IF p_source_type = 'inventory' AND p_target_type = 'bank' THEN
    UPDATE public.inventory SET item_id = v_target_item_id, quantity = v_target_qty, updated_at = now()
    WHERE row_id = p_source_id;

    UPDATE public.bank_items SET item_id = v_source_item_id, quantity = v_source_qty, updated_at = now()
    WHERE id = p_target_id;
  ELSIF p_source_type = 'bank' AND p_target_type = 'inventory' THEN
    UPDATE public.bank_items SET item_id = v_target_item_id, quantity = v_target_qty, updated_at = now()
    WHERE id = p_source_id;

    UPDATE public.inventory SET item_id = v_source_item_id, quantity = v_source_qty, updated_at = now()
    WHERE row_id = p_target_id;
  ELSIF p_source_type = 'inventory' AND p_target_type = 'inventory' THEN
    UPDATE public.inventory SET item_id = v_target_item_id, quantity = v_target_qty, updated_at = now()
    WHERE row_id = p_source_id;

    UPDATE public.inventory SET item_id = v_source_item_id, quantity = v_source_qty, updated_at = now()
    WHERE row_id = p_target_id;
  ELSIF p_source_type = 'bank' AND p_target_type = 'bank' THEN
    UPDATE public.bank_items SET item_id = v_target_item_id, quantity = v_target_qty, updated_at = now()
    WHERE id = p_source_id;

    UPDATE public.bank_items SET item_id = v_source_item_id, quantity = v_source_qty, updated_at = now()
    WHERE id = p_target_id;
  END IF;

  RETURN QUERY SELECT true, 'Items swapped successfully'::text;
END;
$$;


ALTER FUNCTION "public"."swap_inventory_bank"("p_source_type" "text", "p_source_id" "uuid", "p_target_type" "text", "p_target_id" "uuid", "p_quantity" integer, "p_target_slot" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."swap_slots"("p_from_slot" integer, "p_to_slot" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_a_row uuid;
  v_b_row uuid;
  v_tmp int := -999999999;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF p_from_slot IS NULL OR p_to_slot IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid slot args');
  END IF;

  IF p_from_slot = p_to_slot THEN
    RETURN jsonb_build_object('success', true, 'note', 'no-op');
  END IF;

  -- Lock involved rows
  SELECT row_id INTO v_a_row FROM public.inventory
    WHERE user_id = v_user_id AND slot_position = p_from_slot
    LIMIT 1 FOR UPDATE;

  SELECT row_id INTO v_b_row FROM public.inventory
    WHERE user_id = v_user_id AND slot_position = p_to_slot
    LIMIT 1 FOR UPDATE;

  -- Both rows exist: swap
  IF v_a_row IS NOT NULL AND v_b_row IS NOT NULL THEN
    UPDATE public.inventory SET slot_position = v_tmp WHERE row_id = v_a_row;
    UPDATE public.inventory SET slot_position = p_from_slot WHERE row_id = v_b_row;
    UPDATE public.inventory SET slot_position = p_to_slot WHERE slot_position = v_tmp AND user_id = v_user_id;
    RETURN jsonb_build_object('success', true);
  END IF;

  -- Only A exists
  IF v_a_row IS NOT NULL AND v_b_row IS NULL THEN
    UPDATE public.inventory SET slot_position = p_to_slot, updated_at = NOW()
      WHERE row_id = v_a_row;
    RETURN jsonb_build_object('success', true);
  END IF;

  -- Only B exists
  IF v_a_row IS NULL AND v_b_row IS NOT NULL THEN
    UPDATE public.inventory SET slot_position = p_from_slot, updated_at = NOW()
      WHERE row_id = v_b_row;
    RETURN jsonb_build_object('success', true);
  END IF;

  -- Neither exists
  RETURN jsonb_build_object('success', false, 'error', 'No items at given slots');
EXCEPTION WHEN others THEN
  RAISE;
END;
$$;


ALTER FUNCTION "public"."swap_slots"("p_from_slot" integer, "p_to_slot" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."toggle_item_favorite"("p_row_id" "uuid", "p_is_favorite" boolean) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_user_id uuid;
  v_updated int := 0;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  UPDATE public.inventory
  SET is_favorite = p_is_favorite, updated_at = NOW()
  WHERE row_id = p_row_id AND user_id = v_user_id
  RETURNING 1 INTO v_updated;

  IF v_updated > 0 THEN
    RETURN jsonb_build_object('success', true);
  END IF;

  RETURN jsonb_build_object('success', false, 'error', 'Item not found or not owned');
END;
$$;


ALTER FUNCTION "public"."toggle_item_favorite"("p_row_id" "uuid", "p_is_favorite" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trash_item"("p_row_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_user_id uuid;
  v_deleted_count int := 0;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  DELETE FROM public.inventory WHERE row_id = p_row_id AND user_id = v_user_id RETURNING 1 INTO v_deleted_count;

  IF v_deleted_count > 0 THEN
    RETURN jsonb_build_object('success', true);
  END IF;

  RETURN jsonb_build_object('success', false, 'error', 'Item not found or not owned');
END;
$$;


ALTER FUNCTION "public"."trash_item"("p_row_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."unequip_item"("p_slot" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
    v_updated_count INT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    UPDATE public.inventory
    SET is_equipped = FALSE, equip_slot = NULL, slot_position = NULL, updated_at = NOW()
    WHERE user_id = v_user_id
      AND lower(COALESCE(equip_slot, '')) = lower(COALESCE(p_slot, ''))
      AND is_equipped = TRUE;

    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    IF v_updated_count = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Item not found, not owned, or not equipped');
    END IF;

    RETURN jsonb_build_object('success', true, 'slot', p_slot);
END;
$$;


ALTER FUNCTION "public"."unequip_item"("p_slot" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."unlock_facility"("p_type" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
    v_cost INT;
    v_exists BOOLEAN;
BEGIN
    v_user_id := auth.uid();
    
    SELECT EXISTS(SELECT 1 FROM public.facilities WHERE user_id = v_user_id AND type = p_type AND is_active = true) 
    INTO v_exists;
    
    IF v_exists THEN 
        RETURN jsonb_build_object('success', false, 'error', 'Facility already unlocked'); 
    END IF;
    
    v_cost := 5000;
    
    IF (SELECT gold FROM public.users WHERE id = v_user_id) < v_cost THEN
        RETURN jsonb_build_object('success', false, 'error', 'Insufficient gold');
    END IF;
    
    UPDATE public.users SET gold = gold - v_cost WHERE id = v_user_id;
    
    INSERT INTO public.facilities (user_id, type, level, suspicion_level, is_active) 
    VALUES (v_user_id, p_type, 1, 0, true)
    ON CONFLICT (user_id, type) 
    DO UPDATE SET 
        is_active = true,
        suspicion_level = 0,
        updated_at = NOW();
    
    RETURN jsonb_build_object('success', true, 'message', 'Facility unlocked successfully');
END;
$$;


ALTER FUNCTION "public"."unlock_facility"("p_type" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_craft_queue_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_craft_queue_timestamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_crafting_recipes_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_crafting_recipes_timestamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_facilities_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_facilities_timestamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_global_suspicion_level"("p_global_suspicion" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
    v_last_bribe_at TIMESTAMPTZ;
    v_new_level INT;
BEGIN
    v_user_id := auth.uid();
    
    RAISE LOG '[update_global_suspicion_level] User: %, Calculated risk: %', v_user_id, p_global_suspicion;
    
    IF v_user_id IS NULL THEN
        RAISE LOG '[update_global_suspicion_level] auth.uid() returned NULL';
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;
    
    -- Get user's last_bribe_at timestamp
    SELECT last_bribe_at 
    INTO v_last_bribe_at
    FROM public.users 
    WHERE auth_id = v_user_id;
    
    IF NOT FOUND THEN
        RAISE LOG '[update_global_suspicion_level] User not found: %', v_user_id;
        RETURN jsonb_build_object('success', false, 'error', 'User not found');
    END IF;
    
    -- If no bribe ever taken, treat as epoch (all facilities will be filtered out or counted based on server logic)
    -- If bribe taken, only apply calculated_risk directly (already filtered server-side in calculation)
    -- Client calculates risk from facilities started after last_bribe_at
    v_new_level := GREATEST(0, LEAST(100, p_global_suspicion));
    
    RAISE LOG '[update_global_suspicion_level] Last bribe at: %, Calculated: %, Final: %', v_last_bribe_at, p_global_suspicion, v_new_level;
    
    -- Update global suspicion level
    UPDATE public.users
    SET global_suspicion_level = v_new_level,
        updated_at = NOW()
    WHERE auth_id = v_user_id;
    
    RAISE LOG '[update_global_suspicion_level] Successfully updated to: %', v_new_level;
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Global suspicion level updated',
        'new_level', v_new_level,
        'last_bribe_at', v_last_bribe_at,
        'calculated_risk', p_global_suspicion
    );
END;
$$;


ALTER FUNCTION "public"."update_global_suspicion_level"("p_global_suspicion" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_item_positions"("p_updates" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_update record;
    v_updated_count int := 0;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    IF p_updates IS NULL OR p_updates::text = '[]' THEN
        RETURN jsonb_build_object('success', true, 'updated', 0);
    END IF;

    FOR v_update IN SELECT * FROM jsonb_to_recordset(p_updates) AS x(row_id uuid, slot_position int)
    LOOP
        UPDATE public.inventory
        SET slot_position = v_update.slot_position, updated_at = NOW()
        WHERE row_id = v_update.row_id AND user_id = v_user_id;

        IF FOUND THEN
            v_updated_count := v_updated_count + 1;
        END IF;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'updated', v_updated_count);
EXCEPTION WHEN others THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;


ALTER FUNCTION "public"."update_item_positions"("p_updates" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_last_login"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := auth.uid();
    
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;
    
    UPDATE game.users
    SET last_login_at = NOW()
    WHERE auth_id = v_user_id;
    
    RETURN jsonb_build_object('success', true);
END;
$$;


ALTER FUNCTION "public"."update_last_login"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_production_queue_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_production_queue_timestamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_user_profile"("p_display_name" "text" DEFAULT NULL::"text", "p_avatar_url" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := auth.uid();
    
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;
    
    UPDATE game.users
    SET
        display_name = COALESCE(p_display_name, display_name),
        avatar_url = COALESCE(p_avatar_url, avatar_url),
        updated_at = NOW()
    WHERE auth_id = v_user_id;
    
    RETURN jsonb_build_object('success', true, 'message', 'Profile updated');
END;
$$;


ALTER FUNCTION "public"."update_user_profile"("p_display_name" "text", "p_avatar_url" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upgrade_facility"("p_facility_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
    v_facility RECORD;
    v_current_level INT;
    v_cost INT;
    v_user_gold INT;
    v_base_cost INT := 2000;
    v_multiplier FLOAT := 1.6;
BEGIN
    v_user_id := auth.uid();
    
    -- Get facility
    SELECT * INTO v_facility FROM public.facilities WHERE id = p_facility_id AND user_id = v_user_id;
    IF v_facility IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Facility not found');
    END IF;
    
    v_current_level := v_facility.level;
    
    -- Calculate cost: 2000 * (1.6 ^ level)
    -- Note: Power returns float, cast to int
    v_cost := (v_base_cost * power(v_multiplier, v_current_level))::INT;
    
    -- Check user gold
    SELECT gold INTO v_user_gold FROM game.users WHERE id = v_user_id;
    
    IF v_user_gold < v_cost THEN
        RETURN jsonb_build_object('success', false, 'error', 'Insufficient gold', 'cost', v_cost, 'current_gold', v_user_gold);
    END IF;
    
    -- Deduct gold
    UPDATE game.users SET gold = gold - v_cost WHERE id = v_user_id;
    
    -- Increment level
    UPDATE public.facilities 
    SET level = level + 1, updated_at = NOW() 
    WHERE id = p_facility_id;
    
    -- Calculate next cost for UI convenience
    -- next_cost = 2000 * (1.6 ^ (level + 1))
    
    RETURN jsonb_build_object(
        'success', true, 
        'new_level', v_current_level + 1,
        'gold_deducted', v_cost,
        'remaining_gold', v_user_gold - v_cost,
        'next_upgrade_cost', (v_base_cost * power(v_multiplier, v_current_level + 1))::INT
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;


ALTER FUNCTION "public"."upgrade_facility"("p_facility_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upgrade_item_enhancement"("p_new_level" integer, "p_row_id" "uuid") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_affected_rows INT;
BEGIN
    UPDATE public.inventory
    SET enhancement_level = p_new_level,
        updated_at = NOW()
    WHERE row_id = p_row_id;

    GET DIAGNOSTICS v_affected_rows = ROW_COUNT;

    IF v_affected_rows > 0 THEN
        RETURN json_build_object('success', true, 'new_level', p_new_level);
    ELSE
        RETURN json_build_object('success', false, 'error', 'Item not found or permission denied');
    END IF;
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;


ALTER FUNCTION "public"."upgrade_item_enhancement"("p_new_level" integer, "p_row_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validate_materials_in_inventory"("p_user_id" "uuid", "p_ingredients" "jsonb") RETURNS boolean
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_ingredient jsonb;
    v_item_id TEXT;
    v_required INT;
    v_owned INT;
BEGIN
    FOR v_ingredient IN SELECT jsonb_array_elements(p_ingredients) LOOP
        v_item_id := v_ingredient->>'item_id';
        v_required := (v_ingredient->>'quantity')::INT;
        
        SELECT COALESCE(SUM(quantity), 0) INTO v_owned
        FROM inventory
        WHERE user_id = p_user_id AND item_id = v_item_id;
        
        IF v_owned < v_required THEN
            RETURN FALSE;
        END IF;
    END LOOP;
    
    RETURN TRUE;
END;
$$;


ALTER FUNCTION "public"."validate_materials_in_inventory"("p_user_id" "uuid", "p_ingredients" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."withdraw_from_bank"("p_bank_item_ids" "uuid"[]) RETURNS TABLE("success" boolean, "message" "text", "items_withdrawn" integer, "new_used_slots" integer)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid;
  v_withdraw_count integer := 0;
  v_used_slots integer;
  v_bank_item_id uuid;
  v_item_id text;
  v_bank_quantity integer;
  v_max_stack integer;
  v_existing_inv_qty integer;
  v_can_stack integer;
  v_will_withdraw integer;
  v_will_remain integer;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'Not authenticated'::text, 0::integer, 0::integer;
    RETURN;
  END IF;

  -- Get current bank status
  SELECT used_slots 
  INTO v_used_slots
  FROM public.user_bank_account
  WHERE user_id = v_user_id;

  -- Move each bank item to inventory (respecting max_stack)
  FOREACH v_bank_item_id IN ARRAY p_bank_item_ids
  LOOP
    -- Get bank item details
    SELECT item_id, quantity INTO v_item_id, v_bank_quantity
    FROM public.bank_items
    WHERE id = v_bank_item_id AND user_id = v_user_id;

    IF v_item_id IS NULL THEN
      CONTINUE; -- Skip if not found
    END IF;

    -- Get item max_stack
    SELECT max_stack INTO v_max_stack
    FROM public.items
    WHERE id = v_item_id;

    -- Default max_stack to 1 if not set
    v_max_stack := COALESCE(v_max_stack, 1);

    -- Check existing inventory quantity for this item
    SELECT COALESCE(SUM(quantity), 0) INTO v_existing_inv_qty
    FROM public.inventory
    WHERE user_id = v_user_id 
      AND item_id = v_item_id 
      AND is_equipped = FALSE;

    -- Calculate how much we can add (respecting max_stack)
    v_can_stack := v_max_stack - v_existing_inv_qty;
    
    IF v_can_stack <= 0 THEN
      -- Inventory stack is full, skip this item
      CONTINUE;
    END IF;

    -- Determine how much to actually withdraw
    v_will_withdraw := LEAST(v_bank_quantity, v_can_stack);
    v_will_remain := v_bank_quantity - v_will_withdraw;

    -- Withdraw: either update existing inventory item or insert new one
    IF v_existing_inv_qty > 0 THEN
      -- Item exists in inventory, just update quantity
      UPDATE public.inventory
      SET quantity = quantity + v_will_withdraw,
          updated_at = now()
      WHERE user_id = v_user_id 
        AND item_id = v_item_id 
        AND is_equipped = FALSE;
    ELSE
      -- New item in inventory, find next available slot
      INSERT INTO public.inventory (user_id, item_id, quantity, is_equipped, equip_slot, slot_position)
      SELECT v_user_id, v_item_id, v_will_withdraw, false, 'none',
        (SELECT MIN(slot_num)
         FROM generate_series(0, 19) AS t(slot_num)
         WHERE NOT EXISTS (
           SELECT 1 FROM public.inventory
           WHERE user_id = v_user_id AND slot_position = t.slot_num AND is_equipped = FALSE
         ));
    END IF;

    -- Update or delete bank item
    IF v_will_remain > 0 THEN
      UPDATE public.bank_items
      SET quantity = v_will_remain,
          updated_at = now()
      WHERE id = v_bank_item_id;
    ELSE
      DELETE FROM public.bank_items WHERE id = v_bank_item_id;
      v_withdraw_count := v_withdraw_count + 1;
    END IF;
  END LOOP;

  -- Update bank used slots (only count deleted items, not quantity changes)
  UPDATE public.user_bank_account
  SET used_slots = GREATEST(0, used_slots - v_withdraw_count),
      updated_at = now()
  WHERE user_id = v_user_id;

  RETURN QUERY SELECT true,
    'Withdrawn successfully'::text,
    v_withdraw_count::integer,
    GREATEST(0, v_used_slots - v_withdraw_count)::integer;
END;
$$;


ALTER FUNCTION "public"."withdraw_from_bank"("p_bank_item_ids" "uuid"[]) OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."facilities" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "type" "text" NOT NULL,
    "level" integer DEFAULT 1 NOT NULL,
    "suspicion_level" integer DEFAULT 0 NOT NULL,
    "is_active" boolean DEFAULT true,
    "production_started_at" timestamp with time zone,
    "last_production_collected_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "offline_production_cap" integer DEFAULT 0,
    "workers" integer DEFAULT 0,
    "is_unlocked" boolean DEFAULT true,
    "last_production" timestamp with time zone,
    CONSTRAINT "facilities_suspicion_level_check" CHECK ((("suspicion_level" >= 0) AND ("suspicion_level" <= 100)))
);


ALTER TABLE "public"."facilities" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."facility_queue" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "facility_id" "uuid" NOT NULL,
    "recipe_id" "text" NOT NULL,
    "quantity" integer DEFAULT 1 NOT NULL,
    "started_at" bigint NOT NULL,
    "completed_at" bigint NOT NULL,
    "status" "text" DEFAULT 'in_progress'::"text",
    "is_raided" boolean DEFAULT false,
    "is_burned" boolean DEFAULT false,
    "rarity_outcome" character varying(20),
    "collected" boolean DEFAULT false NOT NULL,
    "collected_at" timestamp without time zone,
    "failed" boolean DEFAULT false NOT NULL,
    "failure_reason" character varying(200),
    "created_at" timestamp without time zone DEFAULT "now"(),
    "estimated_completion_at" timestamp without time zone,
    "duration_seconds" integer
);


ALTER TABLE "public"."facility_queue" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."active_production_queue" AS
 SELECT "fq"."id",
    "f"."user_id",
    "f"."type",
    "f"."level" AS "facility_level",
    "fq"."recipe_id",
    "fq"."quantity",
    "fq"."started_at",
    "fq"."estimated_completion_at",
    EXTRACT(epoch FROM (("fq"."estimated_completion_at")::timestamp with time zone - "now"())) AS "seconds_remaining",
    "fq"."rarity_outcome",
    "fq"."failed",
    "fq"."failure_reason"
   FROM ("public"."facility_queue" "fq"
     JOIN "public"."facilities" "f" ON (("fq"."facility_id" = "f"."id")))
  WHERE (("fq"."status" = 'in_progress'::"text") OR ("fq"."status" IS NULL));


ALTER VIEW "public"."active_production_queue" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."bank_items" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "item_id" "text" NOT NULL,
    "quantity" integer DEFAULT 1 NOT NULL,
    "category" "text" DEFAULT 'material'::"text" NOT NULL,
    "rarity" "text" DEFAULT 'common'::"text",
    "slot_position" integer,
    "is_pinned" boolean DEFAULT false,
    "pinned_at" timestamp with time zone,
    "stored_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "bank_items_slot_position_check" CHECK ((("slot_position" >= 0) AND ("slot_position" < 200)))
);


ALTER TABLE "public"."bank_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."bank_transactions" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "transaction_type" "text" NOT NULL,
    "item_id" "text",
    "quantity_moved" integer,
    "category" "text",
    "gem_cost" integer,
    "gems_before" integer,
    "gems_after" integer,
    "slots_before" integer,
    "slots_after" integer,
    "success" boolean DEFAULT true,
    "error_message" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."bank_transactions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."chat_messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "channel" "text" NOT NULL,
    "sender_id" "uuid",
    "receiver_id" "uuid",
    "guild_id" "uuid",
    "content" "text" NOT NULL,
    "sent_at" timestamp with time zone DEFAULT "now"(),
    "is_deleted" boolean DEFAULT false,
    "deleted_by" "uuid",
    "flagged" boolean DEFAULT false,
    "flagged_reason" "text",
    "deleted_at" timestamp without time zone
);


ALTER TABLE "public"."chat_messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."craft_queue" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "recipe_id" "uuid" NOT NULL,
    "batch_count" integer DEFAULT 1 NOT NULL,
    "started_at" timestamp with time zone DEFAULT "now"(),
    "completes_at" timestamp with time zone NOT NULL,
    "is_completed" boolean DEFAULT false,
    "claimed" boolean DEFAULT false,
    "failed" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."craft_queue" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."crafted_items_log" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "item_id" "text" NOT NULL,
    "quantity" integer NOT NULL,
    "rarity" character varying(20) NOT NULL,
    "facility_id" "uuid",
    "recipe_id" "text",
    "enhancement_level" integer DEFAULT 0,
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."crafted_items_log" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."crafting_recipes" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "output_item_id" "text" NOT NULL,
    "required_level" integer DEFAULT 1 NOT NULL,
    "production_time_seconds" integer NOT NULL,
    "success_rate" double precision DEFAULT 0.8 NOT NULL,
    "xp_reward" integer DEFAULT 0 NOT NULL,
    "ingredients" "jsonb" NOT NULL,
    "created_at" timestamp without time zone DEFAULT "now"(),
    "updated_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."crafting_recipes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."facility_recipes" (
    "id" "text" NOT NULL,
    "facility_type" "text" NOT NULL,
    "output_item_id" "text" NOT NULL,
    "output_quantity" integer DEFAULT 1 NOT NULL,
    "input_materials" "jsonb" DEFAULT '{}'::"jsonb",
    "gold_cost" integer DEFAULT 0,
    "duration_seconds" integer NOT NULL,
    "required_level" integer DEFAULT 1,
    "success_rate" integer DEFAULT 100,
    "base_suspicion_increase" integer DEFAULT 0,
    "production_speed_bonus" double precision DEFAULT 1.0,
    "rarity_distribution" "jsonb" DEFAULT '{"EPIC": 1.5, "RARE": 8, "COMMON": 70, "UNCOMMON": 20, "LEGENDARY": 0.5}'::"jsonb",
    "created_at" timestamp without time zone DEFAULT "now"(),
    "min_facility_level" integer DEFAULT 1,
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."facility_recipes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."guild_activities" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "guild_id" "uuid",
    "activity_type" "text",
    "user_id" "uuid",
    "description" "text",
    "metadata" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."guild_activities" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."guild_wars" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "guild_1_id" "uuid",
    "guild_2_id" "uuid",
    "guild_1_points" integer DEFAULT 0,
    "guild_2_points" integer DEFAULT 0,
    "winner_guild_id" "uuid",
    "start_time" timestamp without time zone,
    "end_time" timestamp without time zone,
    "status" "text" DEFAULT 'upcoming'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "different_guilds" CHECK (("guild_1_id" <> "guild_2_id"))
);


ALTER TABLE "public"."guild_wars" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."guilds" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "tag" "text" NOT NULL,
    "description" "text",
    "logo_url" "text",
    "founder_id" "uuid",
    "leader_id" "uuid",
    "member_count" integer DEFAULT 1,
    "max_members" integer DEFAULT 50,
    "level" integer DEFAULT 1,
    "xp" bigint DEFAULT 0,
    "treasury_gold" bigint DEFAULT 0,
    "tax_rate" numeric DEFAULT 0.05,
    "season_points" integer DEFAULT 0,
    "is_recruiting" boolean DEFAULT true,
    "min_level_requirement" integer DEFAULT 1,
    "min_level" integer DEFAULT 1,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."guilds" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."hospital_records" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "reason" "text",
    "related_battle_id" "uuid",
    "duration_minutes" integer NOT NULL,
    "release_time" timestamp without time zone DEFAULT ("now"() + '00:30:00'::interval) NOT NULL,
    "early_release" boolean DEFAULT false,
    "early_release_gem_cost" integer,
    "early_release_time" timestamp without time zone,
    "admitted_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."hospital_records" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."inventory" (
    "row_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "item_id" "text" NOT NULL,
    "quantity" integer DEFAULT 1 NOT NULL,
    "slot_position" integer,
    "is_equipped" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "equip_slot" "text",
    "description" "text",
    "icon" "text",
    "weapon_type" "text",
    "armor_type" "text",
    "material_type" "text",
    "potion_type" "text",
    "base_price" integer DEFAULT 0,
    "vendor_sell_price" integer DEFAULT 0,
    "is_tradeable" boolean DEFAULT true,
    "is_stackable" boolean DEFAULT true,
    "max_stack" integer DEFAULT 999,
    "max_enhancement" integer DEFAULT 0,
    "can_enhance" boolean DEFAULT false,
    "heal_amount" integer DEFAULT 0,
    "tolerance_increase" integer DEFAULT 0,
    "overdose_risk" double precision DEFAULT 0.0,
    "required_level" integer DEFAULT 0,
    "required_class" "text",
    "recipe_requirements" "jsonb" DEFAULT '{}'::"jsonb",
    "recipe_result_item_id" "text",
    "recipe_building_type" "text",
    "recipe_production_time" integer DEFAULT 0,
    "recipe_required_level" integer DEFAULT 0,
    "rune_enhancement_type" "text",
    "rune_success_bonus" double precision DEFAULT 0.0,
    "rune_destruction_reduction" double precision DEFAULT 0.0,
    "cosmetic_effect" "text",
    "cosmetic_bind_on_pickup" boolean DEFAULT false,
    "cosmetic_showcase_only" boolean DEFAULT false,
    "production_building_type" "text",
    "production_rate_per_hour" integer DEFAULT 0,
    "production_required_level" integer DEFAULT 0,
    "bound_to_player" boolean DEFAULT false,
    "pending_sync" boolean DEFAULT false,
    "enhancement_level" integer DEFAULT 0,
    "obtained_at" bigint,
    "is_favorite" boolean DEFAULT false,
    CONSTRAINT "inventory_quantity_check" CHECK (("quantity" > 0))
);


ALTER TABLE "public"."inventory" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."items" (
    "id" "text" NOT NULL,
    "name" "text" NOT NULL,
    "type" "text" NOT NULL,
    "description" "text",
    "rarity" "text" DEFAULT 'common'::"text",
    "icon" "text",
    "base_price" integer DEFAULT 0,
    "vendor_sell_price" integer DEFAULT 0,
    "is_tradeable" boolean DEFAULT true,
    "is_stackable" boolean DEFAULT true,
    "max_stack" integer DEFAULT 999,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "equip_slot" "text",
    "weapon_type" "text",
    "armor_type" "text",
    "material_type" "text",
    "potion_type" "text",
    "attack" integer DEFAULT 0,
    "defense" integer DEFAULT 0,
    "health" integer DEFAULT 0,
    "power" integer DEFAULT 0,
    "energy_restore" integer DEFAULT 0,
    "heal_amount" integer DEFAULT 0,
    "can_enhance" boolean DEFAULT false,
    "max_enhancement" integer DEFAULT 0,
    "required_level" integer DEFAULT 1,
    "required_class" "text",
    "tolerance_increase" integer DEFAULT 0,
    "overdose_risk" numeric DEFAULT 0,
    "production_building_type" "text",
    "rune_enhancement_type" "text",
    "rune_success_bonus" double precision DEFAULT 0.0,
    "rune_destruction_reduction" double precision DEFAULT 0.0,
    "health_restore" integer DEFAULT 0,
    "mana_restore" integer DEFAULT 0,
    "buff_duration" integer DEFAULT 0,
    "production_rate_per_hour" integer DEFAULT 0,
    "production_required_level" integer DEFAULT 0,
    "recipe_requirements" "jsonb" DEFAULT '{}'::"jsonb",
    "recipe_result_item_id" "text",
    "recipe_building_type" "text",
    "recipe_production_time" integer DEFAULT 0,
    "recipe_required_level" integer DEFAULT 0,
    "cosmetic_effect" "text",
    "cosmetic_bind_on_pickup" boolean DEFAULT false,
    "cosmetic_showcase_only" boolean DEFAULT false,
    "updated_at" timestamp without time zone DEFAULT "now"(),
    "craftable" boolean DEFAULT false,
    "craft_time_seconds" integer,
    "shop_available" boolean DEFAULT true NOT NULL,
    "shop_currency" "text" DEFAULT 'gold'::"text" NOT NULL,
    CONSTRAINT "items_shop_currency_check" CHECK (("shop_currency" = ANY (ARRAY['gold'::"text", 'gems'::"text"])))
);


ALTER TABLE "public"."items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."market_history" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "item_id" "text" NOT NULL,
    "seller_id" "uuid" NOT NULL,
    "buyer_id" "uuid" NOT NULL,
    "quantity" integer NOT NULL,
    "price" integer NOT NULL,
    "total_price" integer,
    "market_fee" integer,
    "sold_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."market_history" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."market_orders" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "seller_id" "uuid" NOT NULL,
    "item_id" "text" NOT NULL,
    "quantity" integer NOT NULL,
    "price" integer NOT NULL,
    "region_id" integer DEFAULT 1,
    "listed_at" bigint DEFAULT (EXTRACT(epoch FROM "now"()))::bigint,
    "item_data" "jsonb" DEFAULT '{}'::"jsonb",
    "buyer_id" "uuid",
    "total_price" integer,
    "status" "text" DEFAULT 'active'::"text",
    "sold_at" bigint,
    "expires_at" bigint,
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "currency" "text" DEFAULT 'gold'::"text" NOT NULL,
    CONSTRAINT "market_orders_currency_gold_only_check" CHECK (("currency" = 'gold'::"text")),
    CONSTRAINT "market_orders_price_check" CHECK (("price" >= 0)),
    CONSTRAINT "market_orders_quantity_check" CHECK (("quantity" > 0)),
    CONSTRAINT "valid_quantity" CHECK (("quantity" > 0))
);


ALTER TABLE "public"."market_orders" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."prison_records" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "facility_id" "uuid",
    "reason" character varying(200) NOT NULL,
    "sentence_hours" integer NOT NULL,
    "admitted_at" timestamp without time zone DEFAULT "now"(),
    "released_at" timestamp without time zone,
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."prison_records" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."player_prison_status" AS
 SELECT "user_id",
        CASE
            WHEN ("count"(*) FILTER (WHERE ("released_at" IS NULL)) > 0) THEN true
            ELSE false
        END AS "is_in_prison",
    "min"(
        CASE
            WHEN ("released_at" IS NULL) THEN "released_at"
            ELSE NULL::timestamp without time zone
        END) AS "next_release_time"
   FROM "public"."prison_records"
  GROUP BY "user_id";


ALTER VIEW "public"."player_prison_status" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."player_suspicion_levels" AS
 SELECT "user_id",
    "sum"("suspicion_level") AS "total_suspicion",
    "array_agg"(DISTINCT "type") AS "high_suspicion_facilities",
    "max"("suspicion_level") AS "max_facility_suspicion"
   FROM "public"."facilities"
  GROUP BY "user_id";


ALTER VIEW "public"."player_suspicion_levels" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."production_queue" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "facility_id" "uuid" NOT NULL,
    "recipe_id" "uuid" NOT NULL,
    "status" "text" DEFAULT 'queued'::"text",
    "started_at" timestamp without time zone,
    "completed_at" timestamp without time zone,
    "estimated_completion_at" timestamp without time zone,
    "success" boolean,
    "result_item_id" "text",
    "batch_number" integer DEFAULT 1,
    "sequence_order" integer,
    "created_at" timestamp without time zone DEFAULT "now"(),
    "updated_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."production_queue" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pvp_battles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "attacker_id" "uuid",
    "defender_id" "uuid",
    "attacker_power" integer,
    "defender_power" integer,
    "attacker_energy_before" integer,
    "outcome" "text",
    "winner_id" "uuid",
    "gold_stolen" integer DEFAULT 0,
    "attacker_hospital_minutes" integer DEFAULT 0,
    "defender_hospital_minutes" integer DEFAULT 0,
    "attacker_energy_cost" integer DEFAULT 0,
    "rating_change_attacker" integer DEFAULT 0,
    "rating_change_defender" integer DEFAULT 0,
    "battled_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."pvp_battles" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."ready_to_collect" AS
 SELECT "fq"."id",
    "f"."user_id",
    "f"."type",
    "fq"."recipe_id",
    "fq"."quantity",
    "fq"."rarity_outcome",
    "fr"."output_item_id",
    "fr"."output_quantity"
   FROM (("public"."facility_queue" "fq"
     JOIN "public"."facilities" "f" ON (("fq"."facility_id" = "f"."id")))
     JOIN "public"."facility_recipes" "fr" ON (("fq"."recipe_id" = "fr"."id")))
  WHERE (("fq"."collected" = false) AND ("fq"."status" = 'completed'::"text"));


ALTER VIEW "public"."ready_to_collect" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_bank_account" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "total_slots" integer DEFAULT 100 NOT NULL,
    "used_slots" integer DEFAULT 0 NOT NULL,
    "free_slots_remaining" integer DEFAULT 100 NOT NULL,
    "paid_slots_purchased" integer DEFAULT 0 NOT NULL,
    "last_accessed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "valid_slot_limits" CHECK ((("total_slots" >= 100) AND ("total_slots" <= 200))),
    CONSTRAINT "valid_slots" CHECK (("used_slots" <= "total_slots"))
);


ALTER TABLE "public"."user_bank_account" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."users" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "auth_id" "uuid",
    "username" "text" NOT NULL,
    "email" "text" NOT NULL,
    "display_name" "text",
    "avatar_url" "text",
    "level" integer DEFAULT 1,
    "xp" integer DEFAULT 0,
    "gold" integer DEFAULT 1000,
    "energy" integer DEFAULT 100,
    "max_energy" integer DEFAULT 100,
    "energy_last_updated" timestamp with time zone DEFAULT "now"(),
    "attack" integer DEFAULT 10,
    "defense" integer DEFAULT 10,
    "health" integer DEFAULT 100,
    "max_health" integer DEFAULT 100,
    "power" integer DEFAULT 0,
    "is_online" boolean DEFAULT false,
    "is_banned" boolean DEFAULT false,
    "ban_reason" "text",
    "banned_until" timestamp with time zone,
    "tutorial_completed" boolean DEFAULT false,
    "last_daily_reward" timestamp with time zone,
    "total_playtime_seconds" integer DEFAULT 0,
    "guild_id" "uuid",
    "guild_role" "text",
    "referral_code" "text",
    "referred_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "last_login_at" timestamp with time zone DEFAULT "now"(),
    "gems" integer DEFAULT 100,
    "experience" integer DEFAULT 0,
    "addiction_level" integer DEFAULT 0,
    "tolerance" integer DEFAULT 0,
    "in_hospital" boolean DEFAULT false,
    "hospital_until" timestamp without time zone,
    "hospital_reason" "text",
    "in_prison" boolean DEFAULT false,
    "prison_until" timestamp with time zone,
    "prison_reason" "text",
    "pvp_wins" integer DEFAULT 0,
    "pvp_losses" integer DEFAULT 0,
    "pvp_rating" integer DEFAULT 1000,
    "reputation" integer DEFAULT 0,
    "global_suspicion_level" integer DEFAULT 0 NOT NULL,
    "risk_baseline" double precision DEFAULT 0,
    "last_bribe_at" timestamp with time zone,
    CONSTRAINT "users_global_suspicion_level_check" CHECK ((("global_suspicion_level" >= 0) AND ("global_suspicion_level" <= 100)))
);


ALTER TABLE "public"."users" OWNER TO "postgres";


ALTER TABLE ONLY "public"."bank_items"
    ADD CONSTRAINT "bank_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."bank_transactions"
    ADD CONSTRAINT "bank_transactions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."chat_messages"
    ADD CONSTRAINT "chat_messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."craft_queue"
    ADD CONSTRAINT "craft_queue_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."crafted_items_log"
    ADD CONSTRAINT "crafted_items_log_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."crafting_recipes"
    ADD CONSTRAINT "crafting_recipes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."facilities"
    ADD CONSTRAINT "facilities_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."facilities"
    ADD CONSTRAINT "facilities_user_id_type_key" UNIQUE ("user_id", "type");



ALTER TABLE ONLY "public"."facility_queue"
    ADD CONSTRAINT "facility_queue_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."facility_recipes"
    ADD CONSTRAINT "facility_recipes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."guild_activities"
    ADD CONSTRAINT "guild_activities_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."guild_wars"
    ADD CONSTRAINT "guild_wars_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."guilds"
    ADD CONSTRAINT "guilds_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."guilds"
    ADD CONSTRAINT "guilds_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."guilds"
    ADD CONSTRAINT "guilds_tag_key" UNIQUE ("tag");



ALTER TABLE ONLY "public"."hospital_records"
    ADD CONSTRAINT "hospital_records_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."inventory"
    ADD CONSTRAINT "inventory_pkey" PRIMARY KEY ("row_id");



ALTER TABLE ONLY "public"."items"
    ADD CONSTRAINT "items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."market_history"
    ADD CONSTRAINT "market_history_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."market_orders"
    ADD CONSTRAINT "market_orders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."prison_records"
    ADD CONSTRAINT "prison_records_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."production_queue"
    ADD CONSTRAINT "production_queue_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pvp_battles"
    ADD CONSTRAINT "pvp_battles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_bank_account"
    ADD CONSTRAINT "user_bank_account_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_bank_account"
    ADD CONSTRAINT "user_bank_account_user_id_key" UNIQUE ("user_id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_auth_id_key" UNIQUE ("auth_id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_referral_code_key" UNIQUE ("referral_code");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_username_key" UNIQUE ("username");



CREATE INDEX "idx_bank_account_user_id" ON "public"."user_bank_account" USING "btree" ("user_id");



CREATE INDEX "idx_bank_items_category" ON "public"."bank_items" USING "btree" ("user_id", "category");



CREATE INDEX "idx_bank_items_is_pinned" ON "public"."bank_items" USING "btree" ("user_id", "is_pinned") WHERE ("is_pinned" = true);



CREATE INDEX "idx_bank_items_user_id" ON "public"."bank_items" USING "btree" ("user_id");



CREATE INDEX "idx_bank_transactions_user_id" ON "public"."bank_transactions" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "idx_chat_messages_channel" ON "public"."chat_messages" USING "btree" ("channel", "sent_at" DESC);



CREATE INDEX "idx_chat_messages_sender" ON "public"."chat_messages" USING "btree" ("sender_id", "sent_at" DESC);



CREATE INDEX "idx_craft_queue_completes_at" ON "public"."craft_queue" USING "btree" ("completes_at");



CREATE INDEX "idx_craft_queue_user_claimed" ON "public"."craft_queue" USING "btree" ("user_id", "claimed");



CREATE INDEX "idx_craft_queue_user_completed" ON "public"."craft_queue" USING "btree" ("user_id", "is_completed");



CREATE INDEX "idx_craft_queue_user_id" ON "public"."craft_queue" USING "btree" ("user_id");



CREATE INDEX "idx_crafted_items_log_facility_id" ON "public"."crafted_items_log" USING "btree" ("facility_id");



CREATE INDEX "idx_crafted_items_log_user_id" ON "public"."crafted_items_log" USING "btree" ("user_id");



CREATE INDEX "idx_crafting_recipes_ingredients" ON "public"."crafting_recipes" USING "gin" ("ingredients");



CREATE INDEX "idx_crafting_recipes_level" ON "public"."crafting_recipes" USING "btree" ("required_level");



CREATE INDEX "idx_crafting_recipes_output" ON "public"."crafting_recipes" USING "btree" ("output_item_id");



CREATE INDEX "idx_facilities_active" ON "public"."facilities" USING "btree" ("is_active");



CREATE INDEX "idx_facilities_type" ON "public"."facilities" USING "btree" ("type");



CREATE INDEX "idx_facilities_user" ON "public"."facilities" USING "btree" ("user_id");



CREATE INDEX "idx_facilities_user_id" ON "public"."facilities" USING "btree" ("user_id");



CREATE INDEX "idx_facility_queue_completed_at" ON "public"."facility_queue" USING "btree" ("completed_at");



CREATE INDEX "idx_facility_queue_facility_id" ON "public"."facility_queue" USING "btree" ("facility_id");



CREATE INDEX "idx_facility_queue_status" ON "public"."facility_queue" USING "btree" ("status");



CREATE INDEX "idx_facility_recipes_level" ON "public"."facility_recipes" USING "btree" ("required_level");



CREATE INDEX "idx_facility_recipes_output" ON "public"."facility_recipes" USING "btree" ("output_item_id");



CREATE INDEX "idx_facility_recipes_type" ON "public"."facility_recipes" USING "btree" ("facility_type");



CREATE INDEX "idx_guild_activities_guild" ON "public"."guild_activities" USING "btree" ("guild_id", "created_at" DESC);



CREATE INDEX "idx_guild_wars_guilds" ON "public"."guild_wars" USING "btree" ("guild_1_id", "guild_2_id");



CREATE INDEX "idx_guild_wars_status" ON "public"."guild_wars" USING "btree" ("status");



CREATE INDEX "idx_guilds_name" ON "public"."guilds" USING "btree" ("name");



CREATE INDEX "idx_guilds_recruiting" ON "public"."guilds" USING "btree" ("is_recruiting") WHERE ("is_recruiting" = true);



CREATE INDEX "idx_guilds_season_points" ON "public"."guilds" USING "btree" ("season_points" DESC);



CREATE INDEX "idx_hospital_user" ON "public"."hospital_records" USING "btree" ("user_id", "release_time");



CREATE INDEX "idx_inventory_equipped" ON "public"."inventory" USING "btree" ("user_id", "is_equipped") WHERE ("is_equipped" = true);



CREATE INDEX "idx_inventory_item" ON "public"."inventory" USING "btree" ("item_id");



CREATE INDEX "idx_inventory_item_id" ON "public"."inventory" USING "btree" ("item_id");



CREATE INDEX "idx_inventory_slot_position" ON "public"."inventory" USING "btree" ("user_id", "slot_position");



CREATE INDEX "idx_inventory_user" ON "public"."inventory" USING "btree" ("user_id");



CREATE UNIQUE INDEX "idx_inventory_user_equip_slot_unique" ON "public"."inventory" USING "btree" ("user_id", "equip_slot") WHERE (("is_equipped" = true) AND ("equip_slot" IS NOT NULL));



CREATE INDEX "idx_inventory_user_id" ON "public"."inventory" USING "btree" ("user_id");



CREATE UNIQUE INDEX "idx_inventory_user_slot_unique" ON "public"."inventory" USING "btree" ("user_id", "slot_position") WHERE (("slot_position" IS NOT NULL) AND ("is_equipped" = false));



CREATE INDEX "idx_items_equip_slot" ON "public"."items" USING "btree" ("equip_slot");



CREATE INDEX "idx_items_production_building_type" ON "public"."items" USING "btree" ("production_building_type");



CREATE INDEX "idx_items_rarity" ON "public"."items" USING "btree" ("rarity");



CREATE INDEX "idx_items_required_level" ON "public"."items" USING "btree" ("required_level");



CREATE INDEX "idx_items_shop_available" ON "public"."items" USING "btree" ("shop_available") WHERE ("shop_available" = true);



CREATE INDEX "idx_items_type" ON "public"."items" USING "btree" ("type");



CREATE INDEX "idx_market_history_buyer" ON "public"."market_history" USING "btree" ("buyer_id");



CREATE INDEX "idx_market_history_item" ON "public"."market_history" USING "btree" ("item_id");



CREATE INDEX "idx_market_history_seller" ON "public"."market_history" USING "btree" ("seller_id");



CREATE INDEX "idx_market_history_time" ON "public"."market_history" USING "btree" ("sold_at" DESC);



CREATE INDEX "idx_market_orders_user" ON "public"."market_orders" USING "btree" ("seller_id");



CREATE INDEX "idx_orders_item" ON "public"."market_orders" USING "btree" ("item_id") WHERE ("status" = 'active'::"text");



CREATE INDEX "idx_orders_price" ON "public"."market_orders" USING "btree" ("price") WHERE ("status" = 'active'::"text");



CREATE INDEX "idx_orders_status" ON "public"."market_orders" USING "btree" ("status");



CREATE INDEX "idx_prison_records_released_at" ON "public"."prison_records" USING "btree" ("released_at");



CREATE INDEX "idx_prison_records_user_id" ON "public"."prison_records" USING "btree" ("user_id");



CREATE INDEX "idx_production_queue_completion" ON "public"."production_queue" USING "btree" ("estimated_completion_at");



CREATE INDEX "idx_production_queue_facility" ON "public"."production_queue" USING "btree" ("facility_id");



CREATE INDEX "idx_production_queue_sequence" ON "public"."production_queue" USING "btree" ("facility_id", "sequence_order");



CREATE INDEX "idx_production_queue_status" ON "public"."production_queue" USING "btree" ("status");



CREATE INDEX "idx_production_queue_user" ON "public"."production_queue" USING "btree" ("user_id");



CREATE INDEX "idx_pvp_battles_attacker" ON "public"."pvp_battles" USING "btree" ("attacker_id", "battled_at" DESC);



CREATE INDEX "idx_pvp_battles_defender" ON "public"."pvp_battles" USING "btree" ("defender_id", "battled_at" DESC);



CREATE INDEX "idx_pvp_battles_time" ON "public"."pvp_battles" USING "btree" ("battled_at" DESC);



CREATE INDEX "idx_queue_facility" ON "public"."facility_queue" USING "btree" ("facility_id");



CREATE INDEX "idx_queue_status" ON "public"."facility_queue" USING "btree" ("status");



CREATE INDEX "idx_users_auth_id" ON "public"."users" USING "btree" ("auth_id");



CREATE INDEX "idx_users_email" ON "public"."users" USING "btree" ("email");



CREATE INDEX "idx_users_guild_id" ON "public"."users" USING "btree" ("guild_id");



CREATE INDEX "idx_users_level" ON "public"."users" USING "btree" ("level");



CREATE INDEX "idx_users_referral_code" ON "public"."users" USING "btree" ("referral_code");



CREATE INDEX "idx_users_referred_by" ON "public"."users" USING "btree" ("referred_by");



CREATE INDEX "idx_users_username" ON "public"."users" USING "btree" ("username");



CREATE OR REPLACE TRIGGER "facilities_update_timestamp" BEFORE UPDATE ON "public"."facilities" FOR EACH ROW EXECUTE FUNCTION "public"."update_facilities_timestamp"();



CREATE OR REPLACE TRIGGER "queue_set_estimated" BEFORE INSERT ON "public"."facility_queue" FOR EACH ROW EXECUTE FUNCTION "public"."set_queue_estimated_completion"();



CREATE OR REPLACE TRIGGER "trigger_craft_queue_timestamp" BEFORE UPDATE ON "public"."craft_queue" FOR EACH ROW EXECUTE FUNCTION "public"."update_craft_queue_timestamp"();



CREATE OR REPLACE TRIGGER "trigger_crafting_recipes_timestamp" BEFORE UPDATE ON "public"."crafting_recipes" FOR EACH ROW EXECUTE FUNCTION "public"."update_crafting_recipes_timestamp"();



CREATE OR REPLACE TRIGGER "trigger_production_queue_timestamp" BEFORE UPDATE ON "public"."production_queue" FOR EACH ROW EXECUTE FUNCTION "public"."update_production_queue_timestamp"();



CREATE OR REPLACE TRIGGER "trigger_set_referral_code" BEFORE INSERT ON "public"."users" FOR EACH ROW EXECUTE FUNCTION "public"."set_referral_code"();



CREATE OR REPLACE TRIGGER "trigger_users_updated_at" BEFORE UPDATE ON "public"."users" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



ALTER TABLE ONLY "public"."bank_items"
    ADD CONSTRAINT "bank_items_item_id_fkey" FOREIGN KEY ("item_id") REFERENCES "public"."items"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."bank_items"
    ADD CONSTRAINT "bank_items_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bank_transactions"
    ADD CONSTRAINT "bank_transactions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."craft_queue"
    ADD CONSTRAINT "craft_queue_recipe_id_fkey" FOREIGN KEY ("recipe_id") REFERENCES "public"."crafting_recipes"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."craft_queue"
    ADD CONSTRAINT "craft_queue_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."crafted_items_log"
    ADD CONSTRAINT "crafted_items_log_facility_id_fkey" FOREIGN KEY ("facility_id") REFERENCES "public"."facilities"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."crafted_items_log"
    ADD CONSTRAINT "crafted_items_log_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."crafting_recipes"
    ADD CONSTRAINT "crafting_recipes_output_item_id_fkey" FOREIGN KEY ("output_item_id") REFERENCES "public"."items"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."facilities"
    ADD CONSTRAINT "facilities_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."facility_queue"
    ADD CONSTRAINT "facility_queue_facility_id_fkey" FOREIGN KEY ("facility_id") REFERENCES "public"."facilities"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."facility_queue"
    ADD CONSTRAINT "facility_queue_recipe_id_fkey" FOREIGN KEY ("recipe_id") REFERENCES "public"."facility_recipes"("id");



ALTER TABLE ONLY "public"."guild_activities"
    ADD CONSTRAINT "guild_activities_guild_id_fkey" FOREIGN KEY ("guild_id") REFERENCES "public"."guilds"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."guild_wars"
    ADD CONSTRAINT "guild_wars_guild_1_id_fkey" FOREIGN KEY ("guild_1_id") REFERENCES "public"."guilds"("id");



ALTER TABLE ONLY "public"."guild_wars"
    ADD CONSTRAINT "guild_wars_guild_2_id_fkey" FOREIGN KEY ("guild_2_id") REFERENCES "public"."guilds"("id");



ALTER TABLE ONLY "public"."guild_wars"
    ADD CONSTRAINT "guild_wars_winner_guild_id_fkey" FOREIGN KEY ("winner_guild_id") REFERENCES "public"."guilds"("id");



ALTER TABLE ONLY "public"."inventory"
    ADD CONSTRAINT "inventory_item_id_fkey" FOREIGN KEY ("item_id") REFERENCES "public"."items"("id");



ALTER TABLE ONLY "public"."inventory"
    ADD CONSTRAINT "inventory_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."market_orders"
    ADD CONSTRAINT "market_orders_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."prison_records"
    ADD CONSTRAINT "prison_records_facility_id_fkey" FOREIGN KEY ("facility_id") REFERENCES "public"."facilities"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."prison_records"
    ADD CONSTRAINT "prison_records_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."production_queue"
    ADD CONSTRAINT "production_queue_facility_id_fkey" FOREIGN KEY ("facility_id") REFERENCES "public"."facilities"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."production_queue"
    ADD CONSTRAINT "production_queue_recipe_id_fkey" FOREIGN KEY ("recipe_id") REFERENCES "public"."crafting_recipes"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."production_queue"
    ADD CONSTRAINT "production_queue_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_bank_account"
    ADD CONSTRAINT "user_bank_account_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_auth_id_fkey" FOREIGN KEY ("auth_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_referred_by_fkey" FOREIGN KEY ("referred_by") REFERENCES "public"."users"("id");



CREATE POLICY "Everyone can view items" ON "public"."items" FOR SELECT USING (true);



CREATE POLICY "Everyone can view recipes" ON "public"."facility_recipes" FOR SELECT USING (true);



CREATE POLICY "Items are viewable by everyone" ON "public"."items" FOR SELECT USING (true);



CREATE POLICY "Items insertable by authenticated" ON "public"."items" FOR INSERT WITH CHECK (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Public read market orders" ON "public"."market_orders" FOR SELECT USING (true);



CREATE POLICY "Users can update own facilities" ON "public"."facilities" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update own inventory" ON "public"."inventory" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view own facilities" ON "public"."facilities" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view own inventory" ON "public"."inventory" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users manage own inventory" ON "public"."inventory" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users manage own orders" ON "public"."market_orders" USING (("auth"."uid"() = "seller_id"));



ALTER TABLE "public"."bank_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."bank_transactions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."chat_messages" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."craft_queue" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "crafted_items_insert" ON "public"."crafted_items_log" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."crafted_items_log" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "crafted_items_select" ON "public"."crafted_items_log" FOR SELECT USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."crafting_recipes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "crafting_recipes_select_all" ON "public"."crafting_recipes" FOR SELECT USING (true);



ALTER TABLE "public"."facilities" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "facilities_insert" ON "public"."facilities" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "facilities_select" ON "public"."facilities" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "facilities_update" ON "public"."facilities" FOR UPDATE USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."facility_queue" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."facility_recipes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."inventory" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "inventory_delete_own" ON "public"."inventory" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "inventory_insert_own" ON "public"."inventory" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "inventory_update_own" ON "public"."inventory" FOR UPDATE USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."market_history" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."market_orders" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."prison_records" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "prison_select" ON "public"."prison_records" FOR SELECT USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."production_queue" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "queue_insert" ON "public"."facility_queue" FOR INSERT WITH CHECK (("facility_id" IN ( SELECT "facilities"."id"
   FROM "public"."facilities"
  WHERE ("facilities"."user_id" = "auth"."uid"()))));



CREATE POLICY "queue_select" ON "public"."facility_queue" FOR SELECT USING (("facility_id" IN ( SELECT "facilities"."id"
   FROM "public"."facilities"
  WHERE ("facilities"."user_id" = "auth"."uid"()))));



ALTER TABLE "public"."user_bank_account" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "users_can_delete_own_bank_items" ON "public"."bank_items" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "users_can_insert_own_bank_items" ON "public"."bank_items" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "users_can_insert_own_craft_queue" ON "public"."craft_queue" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "users_can_read_own_bank_account" ON "public"."user_bank_account" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "users_can_read_own_bank_items" ON "public"."bank_items" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "users_can_read_own_craft_queue" ON "public"."craft_queue" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "users_can_read_own_transactions" ON "public"."bank_transactions" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "users_can_update_own_bank_account" ON "public"."user_bank_account" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "users_can_update_own_craft_queue" ON "public"."craft_queue" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "users_manage_own_queue" ON "public"."production_queue" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "users_see_own_queue" ON "public"."production_queue" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "users_select_own" ON "public"."users" FOR SELECT USING (("auth"."uid"() = "auth_id"));



CREATE POLICY "users_select_public" ON "public"."users" FOR SELECT USING (true);



CREATE POLICY "users_update_own" ON "public"."users" FOR UPDATE USING (("auth"."uid"() = "auth_id")) WITH CHECK (("auth"."uid"() = "auth_id"));



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON FUNCTION "public"."_facility_resource_index"("p_seed" bigint, "p_i" integer, "p_pool_len" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."_facility_resource_index"("p_seed" bigint, "p_i" integer, "p_pool_len" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."_facility_resource_index"("p_seed" bigint, "p_i" integer, "p_pool_len" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."_jsonb_to_int"("val" "jsonb", "default_val" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."_jsonb_to_int"("val" "jsonb", "default_val" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."_jsonb_to_int"("val" "jsonb", "default_val" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."acknowledge_crafted_item"("p_queue_item_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."acknowledge_crafted_item"("p_queue_item_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."acknowledge_crafted_item"("p_queue_item_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."add_inventory_item"("item_data" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."add_inventory_item"("item_data" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_inventory_item"("item_data" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."add_inventory_item_v2"("item_data" "jsonb", "p_slot_position" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."add_inventory_item_v2"("item_data" "jsonb", "p_slot_position" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_inventory_item_v2"("item_data" "jsonb", "p_slot_position" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."admit_to_hospital"("p_auth_id" "uuid", "p_duration_minutes" integer, "p_reason" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."admit_to_hospital"("p_auth_id" "uuid", "p_duration_minutes" integer, "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."admit_to_hospital"("p_auth_id" "uuid", "p_duration_minutes" integer, "p_reason" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."admit_to_prison"("p_facility_id" "uuid", "p_suspicion_level" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."admit_to_prison"("p_facility_id" "uuid", "p_suspicion_level" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."admit_to_prison"("p_facility_id" "uuid", "p_suspicion_level" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."bribe_officials"("p_facility_type" "text", "p_amount_gems" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."bribe_officials"("p_facility_type" "text", "p_amount_gems" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."bribe_officials"("p_facility_type" "text", "p_amount_gems" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."buy_shop_item"("p_item_id" "text", "p_currency" "text", "p_price" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."buy_shop_item"("p_item_id" "text", "p_currency" "text", "p_price" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."buy_shop_item"("p_item_id" "text", "p_currency" "text", "p_price" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."buy_shop_item"("p_item_id" "text", "p_currency" "text", "p_price" bigint, "p_quantity" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."buy_shop_item"("p_item_id" "text", "p_currency" "text", "p_price" bigint, "p_quantity" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."buy_shop_item"("p_item_id" "text", "p_currency" "text", "p_price" bigint, "p_quantity" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_global_suspicion"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_global_suspicion"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_global_suspicion"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_offline_production"("p_facility_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_offline_production"("p_facility_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_offline_production"("p_facility_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."cancel_craft_item"("p_queue_item_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."cancel_craft_item"("p_queue_item_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cancel_craft_item"("p_queue_item_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."cancel_sell_order"("p_order_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."cancel_sell_order"("p_order_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cancel_sell_order"("p_order_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."check_and_release_from_prison"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."check_and_release_from_prison"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_and_release_from_prison"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."claim_crafted_item"("p_queue_item_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."claim_crafted_item"("p_queue_item_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."claim_crafted_item"("p_queue_item_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."collect_facility_production"("p_facility_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."collect_facility_production"("p_facility_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."collect_facility_production"("p_facility_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."collect_facility_resources"("p_facility_id" "uuid", "p_resources" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."collect_facility_resources"("p_facility_id" "uuid", "p_resources" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."collect_facility_resources"("p_facility_id" "uuid", "p_resources" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."collect_facility_resources"("p_facility_id" "uuid", "p_seed" bigint, "p_debug" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."collect_facility_resources"("p_facility_id" "uuid", "p_seed" bigint, "p_debug" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."collect_facility_resources"("p_facility_id" "uuid", "p_seed" bigint, "p_debug" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."collect_facility_resources_v2"("p_facility_id" "uuid", "p_seed" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."collect_facility_resources_v2"("p_facility_id" "uuid", "p_seed" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."collect_facility_resources_v2"("p_facility_id" "uuid", "p_seed" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."collect_facility_resources_v2"("p_facility_id" "uuid", "p_seed" bigint, "p_total_count" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."collect_facility_resources_v2"("p_facility_id" "uuid", "p_seed" bigint, "p_total_count" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."collect_facility_resources_v2"("p_facility_id" "uuid", "p_seed" bigint, "p_total_count" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."craft_item_async"("p_recipe_id" "uuid", "p_batch_count" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."craft_item_async"("p_recipe_id" "uuid", "p_batch_count" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."craft_item_async"("p_recipe_id" "uuid", "p_batch_count" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."decrement_facility_suspicion"("p_facility_id" "uuid", "p_amount" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."decrement_facility_suspicion"("p_facility_id" "uuid", "p_amount" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."decrement_facility_suspicion"("p_facility_id" "uuid", "p_amount" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."deduct_materials_from_inventory"("p_user_id" "uuid", "p_ingredients" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."deduct_materials_from_inventory"("p_user_id" "uuid", "p_ingredients" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."deduct_materials_from_inventory"("p_user_id" "uuid", "p_ingredients" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."deposit_to_bank"("p_item_row_ids" "uuid"[], "p_quantities" integer[]) TO "anon";
GRANT ALL ON FUNCTION "public"."deposit_to_bank"("p_item_row_ids" "uuid"[], "p_quantities" integer[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."deposit_to_bank"("p_item_row_ids" "uuid"[], "p_quantities" integer[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."determine_rarity_outcome"("p_facility_level" integer, "p_suspicion_level" integer, "p_rarity_distribution" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."determine_rarity_outcome"("p_facility_level" integer, "p_suspicion_level" integer, "p_rarity_distribution" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."determine_rarity_outcome"("p_facility_level" integer, "p_suspicion_level" integer, "p_rarity_distribution" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."equip_item"("p_row_id" "uuid", "p_slot" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."equip_item"("p_row_id" "uuid", "p_slot" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."equip_item"("p_row_id" "uuid", "p_slot" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."expand_bank_slots"("p_num_expansions" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."expand_bank_slots"("p_num_expansions" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."expand_bank_slots"("p_num_expansions" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."finalize_crafted_item"("p_queue_item_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."finalize_crafted_item"("p_queue_item_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."finalize_crafted_item"("p_queue_item_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_referral_code"() TO "anon";
GRANT ALL ON FUNCTION "public"."generate_referral_code"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_referral_code"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_bank_account"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_bank_account"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_bank_account"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_bank_items"("p_category" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_bank_items"("p_category" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_bank_items"("p_category" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_craft_queue"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_craft_queue"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_craft_queue"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_craft_recipes"("p_user_level" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_craft_recipes"("p_user_level" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_craft_recipes"("p_user_level" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_current_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_current_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_current_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_equipped_items"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_equipped_items"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_equipped_items"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_facility_recipes_rpc"("p_facility_type" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_facility_recipes_rpc"("p_facility_type" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_facility_recipes_rpc"("p_facility_type" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_hospital_status"("p_auth_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_hospital_status"("p_auth_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_hospital_status"("p_auth_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_inventory"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_inventory"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_inventory"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_player_facilities_with_queue"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_player_facilities_with_queue"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_player_facilities_with_queue"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."increment_facility_suspicion"("p_facility_id" "uuid", "p_amount" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."increment_facility_suspicion"("p_facility_id" "uuid", "p_amount" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."increment_facility_suspicion"("p_facility_id" "uuid", "p_amount" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."organize_bank"("p_item_id" "uuid", "p_pin" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."organize_bank"("p_item_id" "uuid", "p_pin" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."organize_bank"("p_item_id" "uuid", "p_pin" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."place_sell_order"("p_item_row_id" "uuid", "p_quantity" integer, "p_price" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."place_sell_order"("p_item_row_id" "uuid", "p_quantity" integer, "p_price" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."place_sell_order"("p_item_row_id" "uuid", "p_quantity" integer, "p_price" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."purchase_market_listing"("p_order_id" "uuid", "p_quantity" integer, "p_is_stackable" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."purchase_market_listing"("p_order_id" "uuid", "p_quantity" integer, "p_is_stackable" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."purchase_market_listing"("p_order_id" "uuid", "p_quantity" integer, "p_is_stackable" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."refund_partial_materials"("p_user_id" "uuid", "p_ingredients" "jsonb", "p_refund_rate" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."refund_partial_materials"("p_user_id" "uuid", "p_ingredients" "jsonb", "p_refund_rate" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."refund_partial_materials"("p_user_id" "uuid", "p_ingredients" "jsonb", "p_refund_rate" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."release_from_hospital"("p_auth_id" "uuid", "p_method" "text", "p_cost" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."release_from_hospital"("p_auth_id" "uuid", "p_method" "text", "p_cost" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."release_from_hospital"("p_auth_id" "uuid", "p_method" "text", "p_cost" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."release_from_prison"("p_use_bail" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."release_from_prison"("p_use_bail" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."release_from_prison"("p_use_bail" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."remove_inventory_item"("p_item_id" "text", "p_quantity" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."remove_inventory_item"("p_item_id" "text", "p_quantity" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."remove_inventory_item"("p_item_id" "text", "p_quantity" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."remove_inventory_item_by_row"("p_row_id" "uuid", "p_quantity" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."remove_inventory_item_by_row"("p_row_id" "uuid", "p_quantity" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."remove_inventory_item_by_row"("p_row_id" "uuid", "p_quantity" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."reset_all_facility_production"() TO "anon";
GRANT ALL ON FUNCTION "public"."reset_all_facility_production"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."reset_all_facility_production"() TO "service_role";



GRANT ALL ON FUNCTION "public"."reset_facility_production"("p_facility_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."reset_facility_production"("p_facility_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."reset_facility_production"("p_facility_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."sell_inventory_item_by_row"("p_row_id" "uuid", "p_quantity" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."sell_inventory_item_by_row"("p_row_id" "uuid", "p_quantity" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sell_inventory_item_by_row"("p_row_id" "uuid", "p_quantity" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."set_queue_estimated_completion"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_queue_estimated_completion"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_queue_estimated_completion"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_referral_code"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_referral_code"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_referral_code"() TO "service_role";



GRANT ALL ON FUNCTION "public"."split_stack_item"("p_row_id" "uuid", "p_split_quantity" integer, "p_target_slot" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."split_stack_item"("p_row_id" "uuid", "p_split_quantity" integer, "p_target_slot" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."split_stack_item"("p_row_id" "uuid", "p_split_quantity" integer, "p_target_slot" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."start_facility_production"("p_facility_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."start_facility_production"("p_facility_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."start_facility_production"("p_facility_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."start_facility_production"("p_facility_id" "uuid", "p_recipe_id" "text", "p_quantity" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."start_facility_production"("p_facility_id" "uuid", "p_recipe_id" "text", "p_quantity" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."start_facility_production"("p_facility_id" "uuid", "p_recipe_id" "text", "p_quantity" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."swap_inventory_bank"("p_source_type" "text", "p_source_id" "uuid", "p_target_type" "text", "p_target_id" "uuid", "p_quantity" integer, "p_target_slot" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."swap_inventory_bank"("p_source_type" "text", "p_source_id" "uuid", "p_target_type" "text", "p_target_id" "uuid", "p_quantity" integer, "p_target_slot" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."swap_inventory_bank"("p_source_type" "text", "p_source_id" "uuid", "p_target_type" "text", "p_target_id" "uuid", "p_quantity" integer, "p_target_slot" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."swap_slots"("p_from_slot" integer, "p_to_slot" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."swap_slots"("p_from_slot" integer, "p_to_slot" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."swap_slots"("p_from_slot" integer, "p_to_slot" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."toggle_item_favorite"("p_row_id" "uuid", "p_is_favorite" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."toggle_item_favorite"("p_row_id" "uuid", "p_is_favorite" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."toggle_item_favorite"("p_row_id" "uuid", "p_is_favorite" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."trash_item"("p_row_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."trash_item"("p_row_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."trash_item"("p_row_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."unequip_item"("p_slot" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."unequip_item"("p_slot" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."unequip_item"("p_slot" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."unlock_facility"("p_type" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."unlock_facility"("p_type" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."unlock_facility"("p_type" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_craft_queue_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_craft_queue_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_craft_queue_timestamp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_crafting_recipes_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_crafting_recipes_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_crafting_recipes_timestamp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_facilities_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_facilities_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_facilities_timestamp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_global_suspicion_level"("p_global_suspicion" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."update_global_suspicion_level"("p_global_suspicion" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_global_suspicion_level"("p_global_suspicion" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."update_item_positions"("p_updates" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."update_item_positions"("p_updates" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_item_positions"("p_updates" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_last_login"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_last_login"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_last_login"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_production_queue_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_production_queue_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_production_queue_timestamp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_user_profile"("p_display_name" "text", "p_avatar_url" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."update_user_profile"("p_display_name" "text", "p_avatar_url" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_user_profile"("p_display_name" "text", "p_avatar_url" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."upgrade_facility"("p_facility_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."upgrade_facility"("p_facility_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."upgrade_facility"("p_facility_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."upgrade_item_enhancement"("p_new_level" integer, "p_row_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."upgrade_item_enhancement"("p_new_level" integer, "p_row_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."upgrade_item_enhancement"("p_new_level" integer, "p_row_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."validate_materials_in_inventory"("p_user_id" "uuid", "p_ingredients" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."validate_materials_in_inventory"("p_user_id" "uuid", "p_ingredients" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."validate_materials_in_inventory"("p_user_id" "uuid", "p_ingredients" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."withdraw_from_bank"("p_bank_item_ids" "uuid"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."withdraw_from_bank"("p_bank_item_ids" "uuid"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."withdraw_from_bank"("p_bank_item_ids" "uuid"[]) TO "service_role";



GRANT ALL ON TABLE "public"."facilities" TO "anon";
GRANT ALL ON TABLE "public"."facilities" TO "authenticated";
GRANT ALL ON TABLE "public"."facilities" TO "service_role";



GRANT ALL ON TABLE "public"."facility_queue" TO "anon";
GRANT ALL ON TABLE "public"."facility_queue" TO "authenticated";
GRANT ALL ON TABLE "public"."facility_queue" TO "service_role";



GRANT ALL ON TABLE "public"."active_production_queue" TO "anon";
GRANT ALL ON TABLE "public"."active_production_queue" TO "authenticated";
GRANT ALL ON TABLE "public"."active_production_queue" TO "service_role";



GRANT ALL ON TABLE "public"."bank_items" TO "anon";
GRANT ALL ON TABLE "public"."bank_items" TO "authenticated";
GRANT ALL ON TABLE "public"."bank_items" TO "service_role";



GRANT ALL ON TABLE "public"."bank_transactions" TO "anon";
GRANT ALL ON TABLE "public"."bank_transactions" TO "authenticated";
GRANT ALL ON TABLE "public"."bank_transactions" TO "service_role";



GRANT ALL ON TABLE "public"."chat_messages" TO "anon";
GRANT ALL ON TABLE "public"."chat_messages" TO "authenticated";
GRANT ALL ON TABLE "public"."chat_messages" TO "service_role";



GRANT ALL ON TABLE "public"."craft_queue" TO "anon";
GRANT ALL ON TABLE "public"."craft_queue" TO "authenticated";
GRANT ALL ON TABLE "public"."craft_queue" TO "service_role";



GRANT ALL ON TABLE "public"."crafted_items_log" TO "anon";
GRANT ALL ON TABLE "public"."crafted_items_log" TO "authenticated";
GRANT ALL ON TABLE "public"."crafted_items_log" TO "service_role";



GRANT ALL ON TABLE "public"."crafting_recipes" TO "anon";
GRANT ALL ON TABLE "public"."crafting_recipes" TO "authenticated";
GRANT ALL ON TABLE "public"."crafting_recipes" TO "service_role";



GRANT ALL ON TABLE "public"."facility_recipes" TO "anon";
GRANT ALL ON TABLE "public"."facility_recipes" TO "authenticated";
GRANT ALL ON TABLE "public"."facility_recipes" TO "service_role";



GRANT ALL ON TABLE "public"."guild_activities" TO "anon";
GRANT ALL ON TABLE "public"."guild_activities" TO "authenticated";
GRANT ALL ON TABLE "public"."guild_activities" TO "service_role";



GRANT ALL ON TABLE "public"."guild_wars" TO "anon";
GRANT ALL ON TABLE "public"."guild_wars" TO "authenticated";
GRANT ALL ON TABLE "public"."guild_wars" TO "service_role";



GRANT ALL ON TABLE "public"."guilds" TO "anon";
GRANT ALL ON TABLE "public"."guilds" TO "authenticated";
GRANT ALL ON TABLE "public"."guilds" TO "service_role";



GRANT ALL ON TABLE "public"."hospital_records" TO "anon";
GRANT ALL ON TABLE "public"."hospital_records" TO "authenticated";
GRANT ALL ON TABLE "public"."hospital_records" TO "service_role";



GRANT ALL ON TABLE "public"."inventory" TO "anon";
GRANT ALL ON TABLE "public"."inventory" TO "authenticated";
GRANT ALL ON TABLE "public"."inventory" TO "service_role";



GRANT ALL ON TABLE "public"."items" TO "anon";
GRANT ALL ON TABLE "public"."items" TO "authenticated";
GRANT ALL ON TABLE "public"."items" TO "service_role";



GRANT ALL ON TABLE "public"."market_history" TO "anon";
GRANT ALL ON TABLE "public"."market_history" TO "authenticated";
GRANT ALL ON TABLE "public"."market_history" TO "service_role";



GRANT ALL ON TABLE "public"."market_orders" TO "anon";
GRANT ALL ON TABLE "public"."market_orders" TO "authenticated";
GRANT ALL ON TABLE "public"."market_orders" TO "service_role";



GRANT ALL ON TABLE "public"."prison_records" TO "anon";
GRANT ALL ON TABLE "public"."prison_records" TO "authenticated";
GRANT ALL ON TABLE "public"."prison_records" TO "service_role";



GRANT ALL ON TABLE "public"."player_prison_status" TO "anon";
GRANT ALL ON TABLE "public"."player_prison_status" TO "authenticated";
GRANT ALL ON TABLE "public"."player_prison_status" TO "service_role";



GRANT ALL ON TABLE "public"."player_suspicion_levels" TO "anon";
GRANT ALL ON TABLE "public"."player_suspicion_levels" TO "authenticated";
GRANT ALL ON TABLE "public"."player_suspicion_levels" TO "service_role";



GRANT ALL ON TABLE "public"."production_queue" TO "anon";
GRANT ALL ON TABLE "public"."production_queue" TO "authenticated";
GRANT ALL ON TABLE "public"."production_queue" TO "service_role";



GRANT ALL ON TABLE "public"."pvp_battles" TO "anon";
GRANT ALL ON TABLE "public"."pvp_battles" TO "authenticated";
GRANT ALL ON TABLE "public"."pvp_battles" TO "service_role";



GRANT ALL ON TABLE "public"."ready_to_collect" TO "anon";
GRANT ALL ON TABLE "public"."ready_to_collect" TO "authenticated";
GRANT ALL ON TABLE "public"."ready_to_collect" TO "service_role";



GRANT ALL ON TABLE "public"."user_bank_account" TO "anon";
GRANT ALL ON TABLE "public"."user_bank_account" TO "authenticated";
GRANT ALL ON TABLE "public"."user_bank_account" TO "service_role";



GRANT ALL ON TABLE "public"."users" TO "anon";
GRANT ALL ON TABLE "public"."users" TO "authenticated";
GRANT ALL ON TABLE "public"."users" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";







