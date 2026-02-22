


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


CREATE SCHEMA IF NOT EXISTS "admin";


ALTER SCHEMA "admin" OWNER TO "postgres";


CREATE SCHEMA IF NOT EXISTS "analytics";


ALTER SCHEMA "analytics" OWNER TO "postgres";


CREATE SCHEMA IF NOT EXISTS "game";


ALTER SCHEMA "game" OWNER TO "postgres";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "game"."trigger_set_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "game"."trigger_set_timestamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "game"."update_users_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "game"."update_users_timestamp"() OWNER TO "postgres";


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
    v_item_id text;
    v_user_id uuid;
    v_quantity int;
    v_new_row jsonb;
    v_is_stackable boolean;
    v_target_position int;
    v_existing_row record;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN '{"success": false, "error": "Not authenticated"}'::jsonb;
    END IF;

    v_item_id := item_data->>'id';
    IF v_item_id IS NULL OR v_item_id = '' THEN
        RETURN '{"success": false, "error": "item_id is required"}'::jsonb;
    END IF;
    
    v_quantity := public._jsonb_to_int(item_data->'quantity', 1);

    -- Upsert item definition (same as before)
    INSERT INTO public.items (
        id, name, description, icon, type, rarity, equip_slot,
        weapon_type, armor_type, material_type, potion_type,
        attack, defense, health, power, energy_restore, heal_amount,
        base_price, vendor_sell_price, can_enhance, max_enhancement,
        is_tradeable, is_stackable, max_stack,
        required_level, required_class, tolerance_increase, overdose_risk, production_building_type
    ) VALUES (
        v_item_id, item_data->>'name', item_data->>'description', item_data->>'icon',
        item_data->>'item_type', item_data->>'rarity', item_data->>'equip_slot',
        item_data->>'weapon_type', item_data->>'armor_type', item_data->>'material_type', item_data->>'potion_type',
        public._jsonb_to_int(item_data->'attack', 0), public._jsonb_to_int(item_data->'defense', 0),
        public._jsonb_to_int(item_data->'health', 0), public._jsonb_to_int(item_data->'power', 0),
        public._jsonb_to_int(item_data->'energy_restore', 0), public._jsonb_to_int(item_data->'heal_amount', 0),
        public._jsonb_to_int(item_data->'base_price', 0), public._jsonb_to_int(item_data->'vendor_sell_price', 0),
        COALESCE((item_data->>'can_enhance')::boolean, false), public._jsonb_to_int(item_data->'max_enhancement', 0),
        COALESCE((item_data->>'is_tradeable')::boolean, true), COALESCE((item_data->>'is_stackable')::boolean, true),
        public._jsonb_to_int(item_data->'max_stack', 999),
        public._jsonb_to_int(item_data->'required_level', 1), item_data->>'required_class',
        public._jsonb_to_int(item_data->'tolerance_increase', 0), COALESCE((item_data->>'overdose_risk')::numeric, 0),
        item_data->>'production_building_type'
    )
    ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name, description = EXCLUDED.description, icon = EXCLUDED.icon,
        attack = EXCLUDED.attack, defense = EXCLUDED.defense, health = EXCLUDED.health, power = EXCLUDED.power;

    -- Check if stackable
    SELECT COALESCE(is_stackable, true) INTO v_is_stackable
    FROM public.items WHERE id = v_item_id;

    -- Check for existing item
    SELECT * INTO v_existing_row FROM public.inventory 
    WHERE user_id = v_user_id AND item_id = v_item_id
    LIMIT 1;

    -- If stackable and exists
    IF v_is_stackable AND v_existing_row IS NOT NULL THEN
        -- Check if it has a valid slot
        IF v_existing_row.slot_position IS NULL OR v_existing_row.slot_position < 0 THEN
             -- FIND A SLOT because the existing one is broken/hidden
            SELECT MIN(slot_num) INTO v_target_position
            FROM generate_series(0, 19) slot_num
            WHERE NOT EXISTS (
                SELECT 1 FROM public.inventory 
                WHERE user_id = v_user_id AND slot_position = slot_num
            );
            
            -- If full, we still have to handle it. 
            -- But upgrading an existing NULL item is better than nothing.
            -- If v_target_position is NULL (full), we leave it as NULL (or maybe 0?)
            -- Let's stick to NULL if full, but ideally we assign a slot.
            
            UPDATE public.inventory
            SET quantity = quantity + v_quantity, 
                slot_position = COALESCE(v_target_position, slot_position), -- Update slot if we found one
                updated_at = NOW()
            WHERE row_id = v_existing_row.row_id
            RETURNING to_jsonb(inventory.*) INTO v_new_row;
            
        ELSE
            -- Normal update
            UPDATE public.inventory
            SET quantity = quantity + v_quantity, updated_at = NOW()
            WHERE row_id = v_existing_row.row_id
            RETURNING to_jsonb(inventory.*) INTO v_new_row;
        END IF;

    ELSE
        -- Find slot position (use provided or find first empty)
        IF p_slot_position IS NOT NULL THEN
            v_target_position := p_slot_position;
        ELSE
            -- Find first empty slot (0-19)
            SELECT MIN(slot_num) INTO v_target_position
            FROM generate_series(0, 19) slot_num
            WHERE NOT EXISTS (
                SELECT 1 FROM public.inventory 
                WHERE user_id = v_user_id AND slot_position = slot_num
            );
        END IF;
        
        -- If inventory is full (v_target_position IS NULL)
        IF v_target_position IS NULL THEN
             RETURN '{"success": false, "error": "Inventory is full"}'::jsonb;
        END IF;

        -- Insert new item
        INSERT INTO public.inventory (
            user_id, item_id, quantity, enhancement_level, is_equipped, obtained_at, slot_position
        ) VALUES (
            v_user_id, v_item_id, v_quantity,
            public._jsonb_to_int(item_data->'enhancement_level', 0),
            false, EXTRACT(EPOCH FROM NOW())::bigint, v_target_position
        )
        RETURNING to_jsonb(inventory.*) INTO v_new_row;
    END IF;

    RETURN jsonb_build_object('success', true, 'data', v_new_row);
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


CREATE OR REPLACE FUNCTION "public"."bribe_officials"("p_facility_id" "uuid", "p_amount_gems" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
    v_reduction INT;
BEGIN
    v_user_id := auth.uid();
    
    -- CHECK public.users for GEMS
    IF (SELECT gems FROM public.users WHERE id = v_user_id) < p_amount_gems THEN
        RETURN jsonb_build_object('success', false, 'error', 'Insufficient gems');
    END IF;
    
    v_reduction := p_amount_gems * 10;
    
    -- UPDATE public.users
    UPDATE public.users SET gems = gems - p_amount_gems WHERE id = v_user_id;
    UPDATE public.facilities SET suspicion = GREATEST(0, suspicion - v_reduction) WHERE id = p_facility_id;
    
    RETURN jsonb_build_object('success', true, 'new_suspicion', (SELECT suspicion FROM public.facilities WHERE id = p_facility_id));
END;
$$;


ALTER FUNCTION "public"."bribe_officials"("p_facility_id" "uuid", "p_amount_gems" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calculate_global_suspicion"("p_user_id" "uuid") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_active_count INT;
    v_level_sum INT;
    v_immunity TIMESTAMPTZ;
    v_risk FLOAT;
    v_duration INTERVAL := INTERVAL '120 seconds';
BEGIN
    -- Check Immunity
    SELECT suspicion_immunity_until INTO v_immunity FROM public.profiles WHERE id = p_user_id;

    IF v_immunity > NOW() THEN
        RETURN 0;
    END IF;

    -- Calculate Active Facilities (production running OR finished but uncollected)
    SELECT
        COUNT(*),
        COALESCE(SUM(level), 0)
    INTO
        v_active_count,
        v_level_sum
    FROM public.facilities
    WHERE user_id = p_user_id
        AND production_started_at IS NOT NULL
        AND (
            NOW() < production_started_at + v_duration
            OR COALESCE(last_production_collected_at, production_started_at) < production_started_at + v_duration
        );

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


CREATE OR REPLACE FUNCTION "public"."collect_facility_resources"("p_facility_id" "uuid", "p_resources" "jsonb" DEFAULT '[]'::"jsonb", "p_preview" boolean DEFAULT false) RETURNS "jsonb"
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
    v_items_json JSONB := '[]'::jsonb;
    v_risk INT;
    v_risk_roll INT;
    
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
        SELECT 1 FROM auth.users 
        WHERE id = v_user_id AND prison_until > NOW()
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
                'total_count', 0,
            'items', '[]'::jsonb,
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
        RETURN jsonb_build_object(
            'success', true,
            'message', 'No resources accumulated yet',
            'total_count', 0,
            'items', '[]'::jsonb
        );
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
    
    -- Deterministic seed so preview and collect match
    PERFORM setseed(
        (abs(hashtext(v_facility.id::text || v_started_at::text || v_last_collected::text)) % 100000)::float / 100000.0
    );

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

    -- Build items array for client response
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'item_id', k,
            'quantity', (v_to_add->>k)::int,
            'rarity', COALESCE((SELECT rarity FROM public.items WHERE id = k), 'common')
        )
    ), '[]'::jsonb)
    INTO v_items_json
    FROM jsonb_object_keys(v_to_add) AS k;

    -- If preview, return items without any writes
    IF p_preview THEN
        RETURN jsonb_build_object(
            'success', true,
            'total_count', v_total_qty,
            'items', v_items_json
        );
    END IF;

    -- Prison roll (server authoritative)
    v_risk := calculate_global_suspicion(v_user_id);
    v_risk_roll := floor(random() * 100) + 1;
    IF v_risk_roll <= v_risk THEN
        UPDATE auth.users
        SET prison_until = NOW() + INTERVAL '1 hour',
            prison_reason = 'Facility Collection'
        WHERE id = v_user_id;

        UPDATE public.facilities
        SET production_started_at = NULL
        WHERE user_id = v_user_id;

        RETURN jsonb_build_object(
            'success', false,
            'error', 'CAUGHT_BY_POLICE',
            'data', jsonb_build_object(
                'prison_hours', 1,
                'message', 'Polis baskini! Tutuklandiniz ve tum uretim durduruldu.'
            )
        );
    END IF;

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
            'total_count', v_total_qty,
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
                suspicion = GREATEST(0, suspicion - GREATEST(5, (suspicion * 0.15)::INT))
            WHERE id = p_facility_id;
        ELSE
            -- Production still active (under 120 seconds), keep production_started_at
            RAISE NOTICE '[collect_facility_resources] Production still active, keeping production_started_at';
            UPDATE public.facilities
            SET last_production_collected_at = v_now,
                suspicion = GREATEST(0, suspicion - GREATEST(5, (suspicion * 0.15)::INT))
            WHERE id = p_facility_id;
        END IF;
    END;

    RAISE NOTICE '[collect_facility_resources] SUCCESS: collected %, inserted=%, updated=%', v_total_qty, v_items_inserted, v_items_updated;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Resources collected',
        'total_count', v_total_qty,
        'items', v_items_json,
        'items_inserted', v_items_inserted,
        'items_updated', v_items_updated,
        'items_skipped', v_items_skipped,
        'debug_started_at', v_started_at,
        'debug_last_collected', v_last_collected,
        'debug_calc_end', v_calc_end,
        'debug_hours_elapsed', v_hours_elapsed,
        'debug_rate', v_production_rate,
        'new_suspicion', GREATEST(0, v_facility.suspicion - GREATEST(5, (v_facility.suspicion * 0.15)::INT))
    );

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '[collect_facility_resources] ERROR: %', SQLERRM;
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;


ALTER FUNCTION "public"."collect_facility_resources"("p_facility_id" "uuid", "p_resources" "jsonb", "p_preview" boolean) OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."equip_item"("item_instance_id" "uuid", "slot" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
    v_item_row RECORD;
BEGIN
    -- Get authenticated user
    v_user_id := auth.uid();
    
    IF v_user_id IS NULL THEN
        RETURN '{"success": false, "error": "Not authenticated"}'::jsonb;
    END IF;
    
    -- Get item and verify ownership
    SELECT * INTO v_item_row
    FROM public.inventory
    WHERE row_id = item_instance_id AND user_id = v_user_id;
    
    IF NOT FOUND THEN
        RETURN '{"success": false, "error": "Item not found or not owned by player"}'::jsonb;
    END IF;
    
    -- Unequip any item currently in this slot
    UPDATE public.inventory
    SET is_equipped = FALSE, equip_slot = NULL, updated_at = NOW()
    WHERE user_id = v_user_id 
      AND equip_slot = slot 
      AND is_equipped = TRUE
      AND row_id != item_instance_id;
    
    -- Equip new item
    UPDATE public.inventory
    SET is_equipped = TRUE, equip_slot = slot, updated_at = NOW()
    WHERE row_id = item_instance_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'item_id', item_instance_id,
        'slot', slot
    );
END;
$$;


ALTER FUNCTION "public"."equip_item"("item_instance_id" "uuid", "slot" "text") OWNER TO "postgres";


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
    -- Get authenticated user
    v_user_id := auth.uid();
    
    IF v_user_id IS NULL THEN
        RETURN '{"success": false, "error": "Not authenticated"}'::jsonb;
    END IF;
    
    -- Fetch equipped items with definitions from items table
    SELECT jsonb_agg(
        jsonb_build_object(
            'row_id', inv.row_id,
            'item_id', inv.item_id,
            'equip_slot', inv.equip_slot,
            'enhancement_level', COALESCE(inv.enhancement_level, 0),
            'quantity', inv.quantity,
            'obtained_at', inv.obtained_at,
            -- Item definition from items table
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
    
    -- Return empty array if no items
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
    v_user_id uuid;
    v_inventory jsonb;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN '{"success": false, "error": "Not authenticated"}'::jsonb;
    END IF;

    -- Fetch inventory with slot_position, ordered by position
    SELECT jsonb_agg(
        jsonb_build_object(
            'row_id', inv.row_id,
            'id', inv.item_id,
            'item_id', inv.item_id,
            'quantity', inv.quantity,
            'enhancement_level', COALESCE(inv.enhancement_level, 0),
            'is_equipped', COALESCE(inv.is_equipped, false),
            'equip_slot', inv.equip_slot,
            'obtained_at', inv.obtained_at,
            'is_favorite', COALESCE(inv.is_favorite, false),
            'slot_position', inv.slot_position,  -- NEW
            -- Item definition data
            'name', it.name,
            'description', it.description,
            'icon', it.icon,
            'item_type', it.type,
            'rarity', it.rarity,
            'weapon_type', it.weapon_type,
            'armor_type', it.armor_type,
            'material_type', it.material_type,
            'potion_type', it.potion_type,
            'attack', it.attack,
            'defense', it.defense,
            'health', it.health,
            'power', it.power,
            'energy_restore', it.energy_restore,
            'heal_amount', it.heal_amount,
            'base_price', it.base_price,
            'vendor_sell_price', it.vendor_sell_price,
            'can_enhance', it.can_enhance,
            'max_enhancement', it.max_enhancement,
            'is_tradeable', it.is_tradeable,
            'is_stackable', it.is_stackable,
            'max_stack', it.max_stack,
            'required_level', COALESCE(it.required_level, 1),
            'required_class', it.required_class,
            'tolerance_increase', COALESCE(it.tolerance_increase, 0),
            'overdose_risk', COALESCE(it.overdose_risk, 0),
            'production_building_type', it.production_building_type
        )
        ORDER BY COALESCE(inv.slot_position, 999), inv.obtained_at  -- Sort by position, unassigned last
    )
    INTO v_inventory
    FROM public.inventory inv
    LEFT JOIN public.items it ON inv.item_id = it.id
    WHERE inv.user_id = v_user_id;

    IF v_inventory IS NULL THEN
        v_inventory := '[]'::jsonb;
    END IF;

    RETURN jsonb_build_object('success', true, 'items', v_inventory);
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


CREATE OR REPLACE FUNCTION "public"."increment_facility_suspicion"("p_facility_id" "uuid", "p_amount" integer DEFAULT 5) RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_new_suspicion INT;
BEGIN
  UPDATE public.facilities
  SET suspicion_level = LEAST(suspicion_level + p_amount, 100),
      updated_at = NOW()
  WHERE id = p_facility_id
  RETURNING suspicion_level INTO v_new_suspicion;
  
  RETURN v_new_suspicion;
END;
$$;


ALTER FUNCTION "public"."increment_facility_suspicion"("p_facility_id" "uuid", "p_amount" integer) OWNER TO "postgres";


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
    
    -- Use game.users
    SELECT * INTO v_user FROM public.users WHERE id = v_user_id;
    
    IF v_user IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'User not found in game.users'); END IF;

    IF v_user.prison_until IS NULL OR v_user.prison_until <= v_now THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not in prison');
    END IF;
    
    IF p_use_bail THEN
        v_remaining_mins := CEIL(EXTRACT(EPOCH FROM (v_user.prison_until - v_now)) / 60);
        v_bail_gems := GREATEST(1, v_remaining_mins);
        
        IF v_user.gems < v_bail_gems THEN
            RETURN jsonb_build_object('success', false, 'error', 'Insufficient gems', 'cost', v_bail_gems);
        END IF;
        
        UPDATE public.users SET gems = gems - v_bail_gems WHERE id = v_user_id;
    END IF;
    
    -- Release
    UPDATE game.users 
    SET prison_until = NULL, prison_reason = NULL 
    WHERE id = v_user_id;
    
    RETURN jsonb_build_object('success', true, 'message', 'Released from prison');
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


CREATE OR REPLACE FUNCTION "public"."start_facility_production"("p_facility_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
    v_energy_cost INT := 50;
    v_current_energy INT;
    v_facility RECORD;
BEGIN
    v_user_id := auth.uid();
    
    -- Check facility ownership
    SELECT * INTO v_facility
    FROM public.facilities
    WHERE id = p_facility_id AND user_id = v_user_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Facility not found');
    END IF;

    -- Check user energy in public.users
    -- Try auth_id first (common pattern), then id
    SELECT energy INTO v_current_energy
    FROM public.users
    WHERE auth_id = v_user_id;
    
    -- Fallback: if auth_id didn't match, maybe id matches?
    IF v_current_energy IS NULL THEN
        SELECT energy INTO v_current_energy
        FROM public.users
        WHERE id = v_user_id;
    END IF;

    IF v_current_energy IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'User profile not found in game.users');
    END IF;

    IF v_current_energy < v_energy_cost THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not enough energy', 'required', v_energy_cost, 'current', v_current_energy);
    END IF;

    -- Deduct Energy
    -- Update based on the same logic (auth_id preferred)
    UPDATE public.users
    SET energy = energy - v_energy_cost
    WHERE auth_id = v_user_id OR (auth_id IS NULL AND id = v_user_id);

    -- Update Facility Production Start Time
    UPDATE public.facilities
    SET production_started_at = NOW()
    WHERE id = p_facility_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Production started',
        'new_energy', v_current_energy - v_energy_cost,
        'production_started_at', NOW()
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
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


CREATE OR REPLACE FUNCTION "public"."unequip_item"("item_instance_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
    v_updated_count INT;
BEGIN
    -- Get authenticated user
    v_user_id := auth.uid();
    
    IF v_user_id IS NULL THEN
        RETURN '{"success": false, "error": "Not authenticated"}'::jsonb;
    END IF;
    
    -- Unequip item
    UPDATE public.inventory
    SET is_equipped = FALSE, equip_slot = NULL, updated_at = NOW()
    WHERE row_id = item_instance_id 
      AND user_id = v_user_id
      AND is_equipped = TRUE;
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    
    IF v_updated_count = 0 THEN
        RETURN '{"success": false, "error": "Item not found, not owned, or not equipped"}'::jsonb;
    END IF;
    
    RETURN jsonb_build_object(
        'success', true,
        'item_id', item_instance_id
    );
END;
$$;


ALTER FUNCTION "public"."unequip_item"("item_instance_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."unlock_facility"("p_type" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
    v_cost INT;
    v_facility RECORD;
BEGIN
    v_user_id := auth.uid();
    
    -- Check if facility exists (fetch full record)
    SELECT * INTO v_facility FROM public.facilities WHERE user_id = v_user_id AND type = p_type;
    
    -- If exists AND is actively running -> Error
    IF v_facility IS NOT NULL AND v_facility.is_active THEN
        RETURN jsonb_build_object('success', false, 'error', 'Facility already unlocked');
    END IF;
    
    -- Determine Cost
    v_cost := CASE 
        WHEN p_type = 'mine' THEN 1000
        WHEN p_type = 'farm' THEN 500
        WHEN p_type = 'lumber_mill' THEN 800
        ELSE 1000
    END;
    
    -- Check Balance
    IF (SELECT gold FROM public.users WHERE id = v_user_id) < v_cost THEN
        RETURN jsonb_build_object('success', false, 'error', 'Insufficient gold');
    END IF;
    
    -- Deduct Gold
    UPDATE public.users SET gold = gold - v_cost WHERE id = v_user_id;
    
    IF v_facility IS NOT NULL THEN
        -- Reactivate existing facility (Treat as 'Repairing/Re-opening')
        -- We won't reset level so if you mistakenly closed it, you keep progress.
        -- But we reset suspicion to be nice.
        UPDATE public.facilities 
        SET is_active = true, 
            suspicion = 0,
            updated_at = NOW()
        WHERE id = v_facility.id;
    ELSE
        -- Insert new facility
        INSERT INTO public.facilities (user_id, type, level, suspicion, is_active) 
        VALUES (v_user_id, p_type, 1, 0, true);
    END IF;
    
    RETURN jsonb_build_object('success', true);
END;
$$;


ALTER FUNCTION "public"."unlock_facility"("p_type" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_facilities_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_facilities_timestamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_item_positions"("p_updates" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id uuid;
    v_update jsonb;
    v_row_id uuid;
    v_new_position int;
    v_count int := 0;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    -- p_updates is array like: [{"row_id": "uuid", "slot_position": 5}, ...]
    FOR v_update IN SELECT * FROM jsonb_array_elements(p_updates)
    LOOP
        v_row_id := (v_update->>'row_id')::uuid;
        v_new_position := (v_update->>'slot_position')::int;
        
        -- Validate position (0-19)
        IF v_new_position < 0 OR v_new_position > 19 THEN
            RETURN jsonb_build_object(
                'success', false, 
                'error', format('Invalid slot_position: %s (must be 0-19)', v_new_position)
            );
        END IF;
        
        -- Update position
        UPDATE public.inventory
        SET slot_position = v_new_position,
            updated_at = NOW()
        WHERE row_id = v_row_id
          AND user_id = v_user_id;
        
        v_count := v_count + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true, 
        'updated_count', v_count
    );
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

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "admin"."audit_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "admin_user_id" "uuid",
    "action" "text" NOT NULL,
    "table_name" "text",
    "record_id" "uuid",
    "old_values" "jsonb",
    "new_values" "jsonb",
    "ip_address" "inet",
    "user_agent" "text",
    "timestamp" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "admin"."audit_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "admin"."bans" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "reason" "text" NOT NULL,
    "evidence" "text",
    "banned_until" timestamp without time zone,
    "banned_by" "uuid",
    "active" boolean DEFAULT true,
    "banned_at" timestamp with time zone DEFAULT "now"(),
    "unbanned_at" timestamp without time zone
);


ALTER TABLE "admin"."bans" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "analytics"."analytics_daily_aggregates" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "date" "date" NOT NULL,
    "dau" integer,
    "new_users" integer,
    "avg_session_duration_seconds" integer,
    "total_sessions" integer,
    "total_gold_earned" bigint,
    "total_gold_spent" bigint,
    "revenue_usd" numeric,
    "paying_users" integer,
    "calculated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "analytics"."analytics_daily_aggregates" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "analytics"."analytics_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "event" "text" NOT NULL,
    "user_id" "uuid",
    "properties" "jsonb",
    "session_id" "uuid",
    "device_type" "text",
    "timestamp" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "analytics"."analytics_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "game"."battle_pass_progress" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "season_id" "uuid",
    "level" integer DEFAULT 1,
    "xp" integer DEFAULT 0,
    "is_premium" boolean DEFAULT false,
    "purchased_at" timestamp without time zone,
    "free_rewards_claimed" "jsonb",
    "premium_rewards_claimed" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "game"."battle_pass_progress" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "game"."dungeon_runs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "dungeon_id" "text",
    "success" boolean,
    "duration_seconds" integer,
    "gold_earned" integer,
    "xp_earned" integer,
    "items_dropped" "jsonb",
    "completed_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "game"."dungeon_runs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "game"."dungeons" (
    "id" "text" NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "difficulty" "text",
    "min_level" integer,
    "min_power" integer,
    "energy_cost" integer,
    "base_gold_min" integer,
    "base_gold_max" integer,
    "loot_table" "jsonb",
    "estimated_duration_minutes" integer
);


ALTER TABLE "game"."dungeons" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "game"."enhancement_history" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "inventory_item_id" "uuid",
    "item_id" "text",
    "from_level" integer,
    "to_level" integer,
    "success" boolean,
    "gold_cost" integer,
    "rune_used" "text",
    "item_destroyed" boolean DEFAULT false,
    "enhanced_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "game"."enhancement_history" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "game"."items" (
    "id" "text" NOT NULL,
    "name" "text" NOT NULL,
    "type" "text",
    "description" "text",
    "rarity" "text",
    "icon_url" "text",
    "is_stackable" boolean DEFAULT false,
    "max_stack" integer DEFAULT 1,
    "base_price" numeric DEFAULT 0,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "game"."items" OWNER TO "postgres";


COMMENT ON TABLE "game"."items" IS 'Idempotent migration: creates game.items used by seed files (05_VERI_VE_ICERIK.sql)';



CREATE TABLE IF NOT EXISTS "game"."purchases" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "package_id" "text" NOT NULL,
    "gems" integer NOT NULL,
    "price_usd" numeric NOT NULL,
    "currency" "text" DEFAULT 'USD'::"text",
    "payment_method" "text",
    "payment_provider_transaction_id" "text",
    "status" "text" DEFAULT 'pending'::"text",
    "first_purchase" boolean DEFAULT false,
    "country" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "completed_at" timestamp without time zone
);


ALTER TABLE "game"."purchases" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "game"."quests" (
    "id" "text" NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "quest_type" "text",
    "difficulty" "text",
    "min_level" integer DEFAULT 1,
    "prerequisite_quest_id" "text",
    "gold_reward" integer,
    "xp_reward" integer,
    "item_rewards" "jsonb",
    "duration_minutes" integer,
    "energy_cost" integer,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "game"."quests" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "game"."season_leaderboards" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "season_id" "uuid",
    "category" "text" NOT NULL,
    "rankings" "jsonb",
    "last_updated" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "game"."season_leaderboards" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "game"."seasons" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "season_number" integer NOT NULL,
    "name" "text" NOT NULL,
    "theme" "text",
    "start_date" timestamp without time zone NOT NULL,
    "end_date" timestamp without time zone NOT NULL,
    "phase" "text" DEFAULT 'foundation'::"text",
    "status" "text" DEFAULT 'upcoming'::"text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "game"."seasons" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "game"."sessions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "device_type" "text",
    "device_id" "text",
    "ip_address" "inet",
    "start_time" timestamp without time zone DEFAULT "now"(),
    "end_time" timestamp without time zone,
    "duration_seconds" integer,
    "client_version" "text",
    "platform" "text"
);


ALTER TABLE "game"."sessions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "game"."user_quests" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "quest_id" "text",
    "status" "text" DEFAULT 'in_progress'::"text",
    "progress" "jsonb",
    "started_at" timestamp with time zone DEFAULT "now"(),
    "completed_at" timestamp without time zone
);


ALTER TABLE "game"."user_quests" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "game"."users" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "email" "text",
    "username" "text" NOT NULL,
    "password_hash" "text",
    "display_name" "text",
    "avatar_url" "text",
    "title" "text",
    "bio" "text",
    "level" integer DEFAULT 1,
    "xp" bigint DEFAULT 0,
    "gold" bigint DEFAULT 1000,
    "gems" integer DEFAULT 100,
    "energy" integer DEFAULT 100,
    "max_energy" integer DEFAULT 100,
    "addiction_level" integer DEFAULT 0,
    "last_potion_time" timestamp without time zone,
    "daily_potion_count" integer DEFAULT 0,
    "hospital_until" timestamp without time zone,
    "hospital_reason" "text",
    "prison_until" timestamp with time zone,
    "prison_reason" "text",
    "guild_id" "uuid",
    "guild_role" "text",
    "guild_contribution" integer DEFAULT 0,
    "pvp_wins" integer DEFAULT 0,
    "pvp_losses" integer DEFAULT 0,
    "pvp_rating" integer DEFAULT 1000,
    "account_level" integer DEFAULT 1,
    "account_xp" bigint DEFAULT 0,
    "is_banned" boolean DEFAULT false,
    "is_muted" boolean DEFAULT false,
    "mute_until" timestamp without time zone,
    "last_login" timestamp without time zone,
    "last_daily_reset" timestamp without time zone,
    "created_at" timestamp without time zone DEFAULT "now"(),
    "updated_at" timestamp without time zone DEFAULT "now"(),
    "auth_id" "uuid" DEFAULT "gen_random_uuid"(),
    "referral_code" "text" DEFAULT ''::"text",
    "referred_by" "text",
    "energy_last_updated" timestamp with time zone DEFAULT "now"(),
    "tolerance" integer DEFAULT 0,
    "last_tolerance_decay" timestamp with time zone,
    "in_hospital" boolean DEFAULT false,
    "in_prison" boolean DEFAULT false,
    "reputation" integer DEFAULT 0,
    "attack" integer DEFAULT 10,
    "defense" integer DEFAULT 10,
    "health" integer DEFAULT 100,
    "max_health" integer DEFAULT 100,
    "power" integer DEFAULT 0,
    "is_online" boolean DEFAULT false,
    "ban_reason" "text",
    "banned_until" timestamp with time zone,
    "tutorial_completed" boolean DEFAULT false,
    "last_daily_reward" timestamp with time zone,
    "total_playtime_seconds" integer DEFAULT 0,
    "total_playtime" integer DEFAULT 0,
    "last_login_at" timestamp with time zone DEFAULT "now"(),
    "last_energy_regen" timestamp with time zone,
    "experience" integer DEFAULT 0,
    CONSTRAINT "valid_addiction" CHECK ((("addiction_level" >= 0) AND ("addiction_level" <= 100))),
    CONSTRAINT "valid_energy" CHECK ((("energy" >= 0) AND ("energy" <= "max_energy"))),
    CONSTRAINT "valid_level" CHECK (("level" >= 1))
);


ALTER TABLE "game"."users" OWNER TO "postgres";


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
    "craft_time_seconds" integer
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
    "reputation" integer DEFAULT 0
);


ALTER TABLE "public"."users" OWNER TO "postgres";


ALTER TABLE ONLY "admin"."audit_logs"
    ADD CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "admin"."bans"
    ADD CONSTRAINT "bans_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "analytics"."analytics_daily_aggregates"
    ADD CONSTRAINT "analytics_daily_aggregates_date_key" UNIQUE ("date");



ALTER TABLE ONLY "analytics"."analytics_daily_aggregates"
    ADD CONSTRAINT "analytics_daily_aggregates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "analytics"."analytics_events"
    ADD CONSTRAINT "analytics_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "game"."battle_pass_progress"
    ADD CONSTRAINT "battle_pass_progress_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "game"."dungeon_runs"
    ADD CONSTRAINT "dungeon_runs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "game"."dungeons"
    ADD CONSTRAINT "dungeons_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "game"."enhancement_history"
    ADD CONSTRAINT "enhancement_history_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "game"."items"
    ADD CONSTRAINT "items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "game"."purchases"
    ADD CONSTRAINT "purchases_payment_provider_transaction_id_key" UNIQUE ("payment_provider_transaction_id");



ALTER TABLE ONLY "game"."purchases"
    ADD CONSTRAINT "purchases_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "game"."quests"
    ADD CONSTRAINT "quests_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "game"."season_leaderboards"
    ADD CONSTRAINT "season_leaderboards_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "game"."seasons"
    ADD CONSTRAINT "seasons_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "game"."seasons"
    ADD CONSTRAINT "seasons_season_number_key" UNIQUE ("season_number");



ALTER TABLE ONLY "game"."sessions"
    ADD CONSTRAINT "sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "game"."user_quests"
    ADD CONSTRAINT "user_quests_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "game"."users"
    ADD CONSTRAINT "users_email_key" UNIQUE ("email");



ALTER TABLE ONLY "game"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "game"."users"
    ADD CONSTRAINT "users_username_key" UNIQUE ("username");



ALTER TABLE ONLY "public"."chat_messages"
    ADD CONSTRAINT "chat_messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."crafted_items_log"
    ADD CONSTRAINT "crafted_items_log_pkey" PRIMARY KEY ("id");



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



ALTER TABLE ONLY "public"."pvp_battles"
    ADD CONSTRAINT "pvp_battles_pkey" PRIMARY KEY ("id");



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



CREATE INDEX "idx_audit_logs_action" ON "admin"."audit_logs" USING "btree" ("action", "timestamp" DESC);



CREATE INDEX "idx_audit_logs_admin" ON "admin"."audit_logs" USING "btree" ("admin_user_id", "timestamp" DESC);



CREATE INDEX "idx_audit_logs_user" ON "admin"."audit_logs" USING "btree" ("user_id", "timestamp" DESC);



CREATE INDEX "idx_bans_active" ON "admin"."bans" USING "btree" ("active") WHERE ("active" = true);



CREATE INDEX "idx_bans_user" ON "admin"."bans" USING "btree" ("user_id");



CREATE INDEX "idx_analytics_daily_date" ON "analytics"."analytics_daily_aggregates" USING "btree" ("date" DESC);



CREATE INDEX "idx_analytics_events_event" ON "analytics"."analytics_events" USING "btree" ("event", "timestamp" DESC);



CREATE INDEX "idx_analytics_events_time" ON "analytics"."analytics_events" USING "btree" ("timestamp" DESC);



CREATE INDEX "idx_analytics_events_user" ON "analytics"."analytics_events" USING "btree" ("user_id", "timestamp" DESC);



CREATE INDEX "idx_battle_pass_season" ON "game"."battle_pass_progress" USING "btree" ("season_id");



CREATE UNIQUE INDEX "idx_battle_pass_user_season" ON "game"."battle_pass_progress" USING "btree" ("user_id", "season_id");



CREATE INDEX "idx_dungeon_runs_dungeon" ON "game"."dungeon_runs" USING "btree" ("dungeon_id", "completed_at" DESC);



CREATE INDEX "idx_dungeon_runs_user" ON "game"."dungeon_runs" USING "btree" ("user_id");



CREATE INDEX "idx_enhancement_history_item" ON "game"."enhancement_history" USING "btree" ("item_id");



CREATE INDEX "idx_enhancement_history_time" ON "game"."enhancement_history" USING "btree" ("enhanced_at" DESC);



CREATE INDEX "idx_enhancement_history_user" ON "game"."enhancement_history" USING "btree" ("user_id");



CREATE INDEX "idx_game_items_name_lower" ON "game"."items" USING "btree" ("lower"("name"));



CREATE INDEX "idx_game_items_rarity" ON "game"."items" USING "btree" ("rarity");



CREATE INDEX "idx_game_items_type" ON "game"."items" USING "btree" ("type");



CREATE INDEX "idx_purchases_status" ON "game"."purchases" USING "btree" ("status");



CREATE INDEX "idx_purchases_time" ON "game"."purchases" USING "btree" ("completed_at" DESC) WHERE ("status" = 'completed'::"text");



CREATE INDEX "idx_purchases_user" ON "game"."purchases" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "idx_quests_level" ON "game"."quests" USING "btree" ("min_level");



CREATE INDEX "idx_quests_type" ON "game"."quests" USING "btree" ("quest_type");



CREATE UNIQUE INDEX "idx_season_leaderboards_unique" ON "game"."season_leaderboards" USING "btree" ("season_id", "category");



CREATE INDEX "idx_seasons_dates" ON "game"."seasons" USING "btree" ("start_date", "end_date");



CREATE INDEX "idx_seasons_status" ON "game"."seasons" USING "btree" ("status");



CREATE INDEX "idx_sessions_start" ON "game"."sessions" USING "btree" ("start_time" DESC);



CREATE INDEX "idx_sessions_user" ON "game"."sessions" USING "btree" ("user_id");



CREATE INDEX "idx_user_quests_quest" ON "game"."user_quests" USING "btree" ("quest_id");



CREATE INDEX "idx_user_quests_user" ON "game"."user_quests" USING "btree" ("user_id", "status");



CREATE INDEX "idx_users_auth_id" ON "game"."users" USING "btree" ("auth_id");



CREATE INDEX "idx_users_email" ON "game"."users" USING "btree" ("email");



CREATE INDEX "idx_users_guild" ON "game"."users" USING "btree" ("guild_id");



CREATE INDEX "idx_users_guild_id" ON "game"."users" USING "btree" ("guild_id");



CREATE INDEX "idx_users_last_login" ON "game"."users" USING "btree" ("last_login");



CREATE INDEX "idx_users_level" ON "game"."users" USING "btree" ("level" DESC);



CREATE INDEX "idx_users_pvp_rating" ON "game"."users" USING "btree" ("pvp_rating" DESC);



CREATE INDEX "idx_users_referral_code" ON "game"."users" USING "btree" ("referral_code");



CREATE INDEX "idx_users_referred_by" ON "game"."users" USING "btree" ("referred_by");



CREATE INDEX "idx_users_username" ON "game"."users" USING "btree" ("username");



CREATE INDEX "idx_chat_messages_channel" ON "public"."chat_messages" USING "btree" ("channel", "sent_at" DESC);



CREATE INDEX "idx_chat_messages_sender" ON "public"."chat_messages" USING "btree" ("sender_id", "sent_at" DESC);



CREATE INDEX "idx_crafted_items_log_facility_id" ON "public"."crafted_items_log" USING "btree" ("facility_id");



CREATE INDEX "idx_crafted_items_log_user_id" ON "public"."crafted_items_log" USING "btree" ("user_id");



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



CREATE OR REPLACE TRIGGER "set_timestamp_game_items" BEFORE UPDATE ON "game"."items" FOR EACH ROW EXECUTE FUNCTION "game"."trigger_set_timestamp"();



CREATE OR REPLACE TRIGGER "trigger_set_referral_code" BEFORE INSERT ON "game"."users" FOR EACH ROW EXECUTE FUNCTION "public"."set_referral_code"();



CREATE OR REPLACE TRIGGER "trigger_update_users_updated_at" BEFORE UPDATE ON "game"."users" FOR EACH ROW EXECUTE FUNCTION "game"."update_users_timestamp"();



CREATE OR REPLACE TRIGGER "trigger_users_updated_at" BEFORE UPDATE ON "game"."users" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "facilities_update_timestamp" BEFORE UPDATE ON "public"."facilities" FOR EACH ROW EXECUTE FUNCTION "public"."update_facilities_timestamp"();



CREATE OR REPLACE TRIGGER "queue_set_estimated" BEFORE INSERT ON "public"."facility_queue" FOR EACH ROW EXECUTE FUNCTION "public"."set_queue_estimated_completion"();



CREATE OR REPLACE TRIGGER "trigger_set_referral_code" BEFORE INSERT ON "public"."users" FOR EACH ROW EXECUTE FUNCTION "public"."set_referral_code"();



CREATE OR REPLACE TRIGGER "trigger_users_updated_at" BEFORE UPDATE ON "public"."users" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



ALTER TABLE ONLY "game"."battle_pass_progress"
    ADD CONSTRAINT "battle_pass_progress_season_id_fkey" FOREIGN KEY ("season_id") REFERENCES "game"."seasons"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "game"."battle_pass_progress"
    ADD CONSTRAINT "battle_pass_progress_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "game"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "game"."dungeon_runs"
    ADD CONSTRAINT "dungeon_runs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "game"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "game"."enhancement_history"
    ADD CONSTRAINT "enhancement_history_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "game"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "game"."purchases"
    ADD CONSTRAINT "purchases_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "game"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "game"."season_leaderboards"
    ADD CONSTRAINT "season_leaderboards_season_id_fkey" FOREIGN KEY ("season_id") REFERENCES "game"."seasons"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "game"."sessions"
    ADD CONSTRAINT "sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "game"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "game"."user_quests"
    ADD CONSTRAINT "user_quests_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "game"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."crafted_items_log"
    ADD CONSTRAINT "crafted_items_log_facility_id_fkey" FOREIGN KEY ("facility_id") REFERENCES "public"."facilities"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."crafted_items_log"
    ADD CONSTRAINT "crafted_items_log_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



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



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_auth_id_fkey" FOREIGN KEY ("auth_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_referred_by_fkey" FOREIGN KEY ("referred_by") REFERENCES "public"."users"("id");



ALTER TABLE "game"."user_quests" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "game"."users" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "users_select_own" ON "game"."users" FOR SELECT USING (("auth"."uid"() = "id"));



CREATE POLICY "users_select_public" ON "game"."users" FOR SELECT USING (true);



CREATE POLICY "users_update_own" ON "game"."users" FOR UPDATE USING (("auth"."uid"() = "id")) WITH CHECK (("auth"."uid"() = "id"));



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



ALTER TABLE "public"."chat_messages" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "crafted_items_insert" ON "public"."crafted_items_log" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."crafted_items_log" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "crafted_items_select" ON "public"."crafted_items_log" FOR SELECT USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."facilities" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "facilities_insert" ON "public"."facilities" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "facilities_select" ON "public"."facilities" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "facilities_update" ON "public"."facilities" FOR UPDATE USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."facility_queue" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."facility_recipes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."inventory" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."market_history" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."market_orders" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."prison_records" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "prison_select" ON "public"."prison_records" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "queue_insert" ON "public"."facility_queue" FOR INSERT WITH CHECK (("facility_id" IN ( SELECT "facilities"."id"
   FROM "public"."facilities"
  WHERE ("facilities"."user_id" = "auth"."uid"()))));



CREATE POLICY "queue_select" ON "public"."facility_queue" FOR SELECT USING (("facility_id" IN ( SELECT "facilities"."id"
   FROM "public"."facilities"
  WHERE ("facilities"."user_id" = "auth"."uid"()))));



ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "users_select_own" ON "public"."users" FOR SELECT USING (("auth"."uid"() = "auth_id"));



CREATE POLICY "users_select_public" ON "public"."users" FOR SELECT USING (true);



CREATE POLICY "users_update_own" ON "public"."users" FOR UPDATE USING (("auth"."uid"() = "auth_id")) WITH CHECK (("auth"."uid"() = "auth_id"));





ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "game" TO "authenticated";
GRANT USAGE ON SCHEMA "game" TO "anon";
GRANT USAGE ON SCHEMA "game" TO "authenticator";
GRANT USAGE ON SCHEMA "game" TO "service_role";



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";

























































































































































GRANT ALL ON FUNCTION "public"."_jsonb_to_int"("val" "jsonb", "default_val" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."_jsonb_to_int"("val" "jsonb", "default_val" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."_jsonb_to_int"("val" "jsonb", "default_val" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."add_inventory_item"("item_data" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."add_inventory_item"("item_data" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_inventory_item"("item_data" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."add_inventory_item_v2"("item_data" "jsonb", "p_slot_position" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."add_inventory_item_v2"("item_data" "jsonb", "p_slot_position" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_inventory_item_v2"("item_data" "jsonb", "p_slot_position" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."admit_to_hospital"("p_auth_id" "uuid", "p_duration_minutes" integer, "p_reason" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."admit_to_hospital"("p_auth_id" "uuid", "p_duration_minutes" integer, "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."admit_to_hospital"("p_auth_id" "uuid", "p_duration_minutes" integer, "p_reason" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."bribe_officials"("p_facility_id" "uuid", "p_amount_gems" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."bribe_officials"("p_facility_id" "uuid", "p_amount_gems" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."bribe_officials"("p_facility_id" "uuid", "p_amount_gems" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_global_suspicion"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_global_suspicion"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_global_suspicion"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_offline_production"("p_facility_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_offline_production"("p_facility_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_offline_production"("p_facility_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."cancel_sell_order"("p_order_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."cancel_sell_order"("p_order_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cancel_sell_order"("p_order_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."collect_facility_production"("p_facility_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."collect_facility_production"("p_facility_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."collect_facility_production"("p_facility_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."collect_facility_resources"("p_facility_id" "uuid", "p_resources" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."collect_facility_resources"("p_facility_id" "uuid", "p_resources" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."collect_facility_resources"("p_facility_id" "uuid", "p_resources" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."collect_facility_resources"("p_facility_id" "uuid", "p_resources" "jsonb", "p_preview" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."collect_facility_resources"("p_facility_id" "uuid", "p_resources" "jsonb", "p_preview" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."collect_facility_resources"("p_facility_id" "uuid", "p_resources" "jsonb", "p_preview" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."decrement_facility_suspicion"("p_facility_id" "uuid", "p_amount" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."decrement_facility_suspicion"("p_facility_id" "uuid", "p_amount" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."decrement_facility_suspicion"("p_facility_id" "uuid", "p_amount" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."determine_rarity_outcome"("p_facility_level" integer, "p_suspicion_level" integer, "p_rarity_distribution" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."determine_rarity_outcome"("p_facility_level" integer, "p_suspicion_level" integer, "p_rarity_distribution" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."determine_rarity_outcome"("p_facility_level" integer, "p_suspicion_level" integer, "p_rarity_distribution" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."equip_item"("item_instance_id" "uuid", "slot" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."equip_item"("item_instance_id" "uuid", "slot" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."equip_item"("item_instance_id" "uuid", "slot" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_referral_code"() TO "anon";
GRANT ALL ON FUNCTION "public"."generate_referral_code"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_referral_code"() TO "service_role";



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



GRANT ALL ON FUNCTION "public"."place_sell_order"("p_item_row_id" "uuid", "p_quantity" integer, "p_price" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."place_sell_order"("p_item_row_id" "uuid", "p_quantity" integer, "p_price" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."place_sell_order"("p_item_row_id" "uuid", "p_quantity" integer, "p_price" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."purchase_market_listing"("p_order_id" "uuid", "p_quantity" integer, "p_is_stackable" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."purchase_market_listing"("p_order_id" "uuid", "p_quantity" integer, "p_is_stackable" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."purchase_market_listing"("p_order_id" "uuid", "p_quantity" integer, "p_is_stackable" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."release_from_hospital"("p_auth_id" "uuid", "p_method" "text", "p_cost" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."release_from_hospital"("p_auth_id" "uuid", "p_method" "text", "p_cost" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."release_from_hospital"("p_auth_id" "uuid", "p_method" "text", "p_cost" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."release_from_prison"("p_use_bail" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."release_from_prison"("p_use_bail" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."release_from_prison"("p_use_bail" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."remove_inventory_item"("p_item_id" "text", "p_quantity" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."remove_inventory_item"("p_item_id" "text", "p_quantity" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."remove_inventory_item"("p_item_id" "text", "p_quantity" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."set_queue_estimated_completion"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_queue_estimated_completion"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_queue_estimated_completion"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_referral_code"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_referral_code"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_referral_code"() TO "service_role";



GRANT ALL ON FUNCTION "public"."start_facility_production"("p_facility_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."start_facility_production"("p_facility_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."start_facility_production"("p_facility_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."start_facility_production"("p_facility_id" "uuid", "p_recipe_id" "text", "p_quantity" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."start_facility_production"("p_facility_id" "uuid", "p_recipe_id" "text", "p_quantity" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."start_facility_production"("p_facility_id" "uuid", "p_recipe_id" "text", "p_quantity" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."unequip_item"("item_instance_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."unequip_item"("item_instance_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."unequip_item"("item_instance_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."unlock_facility"("p_type" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."unlock_facility"("p_type" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."unlock_facility"("p_type" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_facilities_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_facilities_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_facilities_timestamp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_item_positions"("p_updates" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."update_item_positions"("p_updates" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_item_positions"("p_updates" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_last_login"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_last_login"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_last_login"() TO "service_role";



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


















GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "game"."battle_pass_progress" TO "authenticator";
GRANT ALL ON TABLE "game"."battle_pass_progress" TO "authenticated";
GRANT ALL ON TABLE "game"."battle_pass_progress" TO "anon";
GRANT ALL ON TABLE "game"."battle_pass_progress" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "game"."dungeon_runs" TO "authenticator";
GRANT ALL ON TABLE "game"."dungeon_runs" TO "authenticated";
GRANT ALL ON TABLE "game"."dungeon_runs" TO "anon";
GRANT ALL ON TABLE "game"."dungeon_runs" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "game"."dungeons" TO "authenticator";
GRANT ALL ON TABLE "game"."dungeons" TO "authenticated";
GRANT ALL ON TABLE "game"."dungeons" TO "anon";
GRANT ALL ON TABLE "game"."dungeons" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "game"."enhancement_history" TO "authenticator";
GRANT ALL ON TABLE "game"."enhancement_history" TO "authenticated";
GRANT ALL ON TABLE "game"."enhancement_history" TO "anon";
GRANT ALL ON TABLE "game"."enhancement_history" TO "service_role";



GRANT SELECT ON TABLE "game"."items" TO PUBLIC;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "game"."items" TO "authenticator";
GRANT ALL ON TABLE "game"."items" TO "authenticated";
GRANT ALL ON TABLE "game"."items" TO "anon";
GRANT ALL ON TABLE "game"."items" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "game"."purchases" TO "authenticator";
GRANT ALL ON TABLE "game"."purchases" TO "authenticated";
GRANT ALL ON TABLE "game"."purchases" TO "anon";
GRANT ALL ON TABLE "game"."purchases" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "game"."quests" TO "authenticator";
GRANT ALL ON TABLE "game"."quests" TO "authenticated";
GRANT ALL ON TABLE "game"."quests" TO "anon";
GRANT ALL ON TABLE "game"."quests" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "game"."season_leaderboards" TO "authenticator";
GRANT ALL ON TABLE "game"."season_leaderboards" TO "authenticated";
GRANT ALL ON TABLE "game"."season_leaderboards" TO "anon";
GRANT ALL ON TABLE "game"."season_leaderboards" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "game"."seasons" TO "authenticator";
GRANT ALL ON TABLE "game"."seasons" TO "authenticated";
GRANT ALL ON TABLE "game"."seasons" TO "anon";
GRANT ALL ON TABLE "game"."seasons" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "game"."sessions" TO "authenticator";
GRANT ALL ON TABLE "game"."sessions" TO "authenticated";
GRANT ALL ON TABLE "game"."sessions" TO "anon";
GRANT ALL ON TABLE "game"."sessions" TO "service_role";



GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "game"."user_quests" TO "authenticator";
GRANT ALL ON TABLE "game"."user_quests" TO "authenticated";
GRANT ALL ON TABLE "game"."user_quests" TO "anon";
GRANT ALL ON TABLE "game"."user_quests" TO "service_role";



GRANT ALL ON TABLE "game"."users" TO "authenticated";
GRANT ALL ON TABLE "game"."users" TO "anon";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "game"."users" TO "authenticator";
GRANT ALL ON TABLE "game"."users" TO "service_role";



GRANT ALL ON TABLE "public"."facilities" TO "anon";
GRANT ALL ON TABLE "public"."facilities" TO "authenticated";
GRANT ALL ON TABLE "public"."facilities" TO "service_role";



GRANT ALL ON TABLE "public"."facility_queue" TO "anon";
GRANT ALL ON TABLE "public"."facility_queue" TO "authenticated";
GRANT ALL ON TABLE "public"."facility_queue" TO "service_role";



GRANT ALL ON TABLE "public"."active_production_queue" TO "anon";
GRANT ALL ON TABLE "public"."active_production_queue" TO "authenticated";
GRANT ALL ON TABLE "public"."active_production_queue" TO "service_role";



GRANT ALL ON TABLE "public"."chat_messages" TO "anon";
GRANT ALL ON TABLE "public"."chat_messages" TO "authenticated";
GRANT ALL ON TABLE "public"."chat_messages" TO "service_role";



GRANT ALL ON TABLE "public"."crafted_items_log" TO "anon";
GRANT ALL ON TABLE "public"."crafted_items_log" TO "authenticated";
GRANT ALL ON TABLE "public"."crafted_items_log" TO "service_role";



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



GRANT ALL ON TABLE "public"."pvp_battles" TO "anon";
GRANT ALL ON TABLE "public"."pvp_battles" TO "authenticated";
GRANT ALL ON TABLE "public"."pvp_battles" TO "service_role";



GRANT ALL ON TABLE "public"."ready_to_collect" TO "anon";
GRANT ALL ON TABLE "public"."ready_to_collect" TO "authenticated";
GRANT ALL ON TABLE "public"."ready_to_collect" TO "service_role";



GRANT ALL ON TABLE "public"."users" TO "anon";
GRANT ALL ON TABLE "public"."users" TO "authenticated";
GRANT ALL ON TABLE "public"."users" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "game" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "game" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "game" GRANT ALL ON TABLES TO "service_role";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "game" GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO "authenticator";



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































