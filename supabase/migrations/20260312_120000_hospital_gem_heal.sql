CREATE OR REPLACE FUNCTION public.heal_with_gems()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id uuid;
    v_hospital_until timestamptz;
    v_gems int;
    v_minutes_left int;
    v_gem_cost int;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    -- Get player's hospital status and gems (use auth_id)
    SELECT hospital_until, gems
    INTO v_hospital_until, v_gems
    FROM public.users
    WHERE auth_id = v_user_id;

    IF v_hospital_until IS NULL OR v_hospital_until <= now() THEN
        -- clear it anyway just in case
        UPDATE public.users SET hospital_until = NULL, hospital_reason = NULL WHERE auth_id = v_user_id;
        RETURN json_build_object('success', true);
    END IF;

    -- Calculate minutes left
    v_minutes_left := CEIL(EXTRACT(EPOCH FROM (v_hospital_until - now())) / 60.0);
    IF v_minutes_left < 1 THEN
        v_minutes_left := 1;
    END IF;

    -- Calculate gem cost (3 gems per minute)
    v_gem_cost := v_minutes_left * 3;

    -- Check if player has enough gems
    IF v_gems < v_gem_cost THEN
        RETURN json_build_object('success', false, 'error', 'Yetersiz elmas. Gerekli: ' || v_gem_cost);
    END IF;

    -- Deduct gems and clear hospital status
    UPDATE public.users
    SET gems = gems - v_gem_cost,
        hospital_until = NULL,
        hospital_reason = NULL
    WHERE auth_id = v_user_id;

    RETURN json_build_object('success', true, 'cost', v_gem_cost);
END;
$$;