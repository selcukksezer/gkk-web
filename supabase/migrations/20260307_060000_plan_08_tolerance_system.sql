-- =========================================================================================
-- MIGRATION: PLAN_08_TOLERANCE_SYSTEM
-- =========================================================================================

-- 1. Add columns to public.users if they don't exist
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS last_potion_used_at TIMESTAMPTZ;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS last_detox_used_at TIMESTAMPTZ;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS detox_type_last TEXT;

-- 2. Create Tolerance Log Table
CREATE TABLE IF NOT EXISTS public.tolerance_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL CHECK (event_type IN ('potion_use', 'overdose', 'detox')),
  item_id TEXT,
  tolerance_before INT NOT NULL,
  tolerance_after INT NOT NULL,
  addiction_before INT NOT NULL,
  addiction_after INT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_tolerance_log_user ON public.tolerance_log(user_id);

ALTER TABLE public.tolerance_log ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can view their own tolerance log' AND tablename = 'tolerance_log') THEN
    CREATE POLICY "Users can view their own tolerance log" ON public.tolerance_log FOR SELECT USING (auth.uid() = user_id);
  END IF;
END $$;

-- 3. use_potion RPC
CREATE OR REPLACE FUNCTION public.use_potion(p_user_id UUID, p_row_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_inv RECORD;
  v_item RECORD;
  v_user RECORD;
  v_new_tolerance INT;
  v_overdose BOOLEAN := false;
  v_efficiency NUMERIC;
  v_overdose_chance NUMERIC;
  v_roll NUMERIC;
  v_hospital_minutes INT;
  v_heal_amount INT;
BEGIN
  IF p_user_id != auth.uid() THEN
    RETURN jsonb_build_object('error', 'Yetkisiz işlem');
  END IF;

  -- Get user
  SELECT * INTO v_user FROM public.users WHERE auth_id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Kullanıcı bulunamadı');
  END IF;

  -- Get inventory item
  SELECT * INTO v_inv FROM public.inventory WHERE row_id = p_row_id AND user_id = p_user_id AND quantity > 0 FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Eşya bulunamadı veya miktar yetersiz');
  END IF;

  -- Get item stats
  SELECT * INTO v_item FROM public.items WHERE id = v_inv.item_id;
  IF NOT FOUND OR v_item.type != 'potion' THEN
    RETURN jsonb_build_object('error', 'Geçersiz iksir');
  END IF;

  -- Tolerance artışı (Alchemist: -%25)
  v_new_tolerance := COALESCE(v_user.tolerance, 0) + COALESCE(v_item.tolerance_increase, 0);
  IF COALESCE(v_user.character_class, '') = 'alchemist' THEN
    v_new_tolerance := COALESCE(v_user.tolerance, 0) + floor(COALESCE(v_item.tolerance_increase, 0) * 0.75);
  END IF;
  v_new_tolerance := GREATEST(0, LEAST(v_new_tolerance, 100));

  -- Etkinlik hesaplama (Alchemist: +%30)
  v_efficiency := CASE
    WHEN COALESCE(v_user.tolerance, 0) <= 20 THEN 1.0
    WHEN COALESCE(v_user.tolerance, 0) <= 40 THEN 0.85
    WHEN COALESCE(v_user.tolerance, 0) <= 60 THEN 0.65
    WHEN COALESCE(v_user.tolerance, 0) <= 80 THEN 0.45
    ELSE 0.25
  END;
  
  IF COALESCE(v_user.character_class, '') = 'alchemist' THEN
    v_efficiency := LEAST(1.0, v_efficiency * 1.30);
  END IF;

  -- Overdose kontrolü
  v_overdose_chance := COALESCE(v_item.overdose_risk, 0) * CASE
    WHEN COALESCE(v_user.tolerance, 0) <= 40 THEN 0.0
    WHEN COALESCE(v_user.tolerance, 0) <= 60 THEN 1.0
    WHEN COALESCE(v_user.tolerance, 0) <= 80 THEN 2.0
    WHEN COALESCE(v_user.tolerance, 0) <= 90 THEN 4.0
    ELSE 8.0
  END;

  IF COALESCE(v_user.character_class, '') = 'alchemist' THEN
    v_overdose_chance := v_overdose_chance * 0.80;
  END IF;

  v_roll := random();
  IF v_roll <= v_overdose_chance THEN
    v_overdose := true;
  END IF;

  -- Consume item FIRST with quantity check
  UPDATE public.inventory SET quantity = quantity - 1 WHERE row_id = p_row_id AND quantity > 0;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Eşya bulunamadı veya miktar yetersiz');
  END IF;
  
  DELETE FROM public.inventory WHERE quantity <= 0 AND row_id = p_row_id;

  -- Overdose ise hastaneye gönder
  IF v_overdose THEN
    v_hospital_minutes := 30 + (COALESCE(v_user.tolerance, 0) * 2);
    
    UPDATE public.users
    SET 
      addiction_level = LEAST(COALESCE(addiction_level, 0) + 1, 10),
      tolerance = LEAST(v_new_tolerance + 10, 100),
      hospital_until = now() + (v_hospital_minutes || ' minutes')::interval,
      hospital_reason = 'Overdose',
      last_potion_used_at = now()
    WHERE auth_id = p_user_id;

    INSERT INTO public.tolerance_log (user_id, event_type, item_id, tolerance_before, tolerance_after, addiction_before, addiction_after)
    VALUES (p_user_id, 'overdose', v_inv.item_id, COALESCE(v_user.tolerance, 0), LEAST(v_new_tolerance + 10, 100), COALESCE(v_user.addiction_level, 0), LEAST(COALESCE(v_user.addiction_level, 0) + 1, 10));

    RETURN jsonb_build_object(
      'success', true,
      'overdose', true,
      'hospital_minutes', v_hospital_minutes,
      'efficiency', 0
    );
  END IF;

  -- Normal kullanım
  v_heal_amount := FLOOR(COALESCE(v_item.heal_amount, 0) * v_efficiency);
  
  UPDATE public.users
  SET 
    tolerance = v_new_tolerance,
    last_potion_used_at = now(),
    energy = LEAST(100, energy + FLOOR(COALESCE(v_item.energy_restore, 0) * v_efficiency)),
    health = LEAST(max_health, health + v_heal_amount)
  WHERE auth_id = p_user_id;

  INSERT INTO public.tolerance_log (user_id, event_type, item_id, tolerance_before, tolerance_after, addiction_before, addiction_after)
  VALUES (p_user_id, 'potion_use', v_inv.item_id, COALESCE(v_user.tolerance, 0), v_new_tolerance, COALESCE(v_user.addiction_level, 0), COALESCE(v_user.addiction_level, 0));

  RETURN jsonb_build_object(
    'success', true,
    'overdose', false,
    'efficiency', v_efficiency,
    'new_tolerance', v_new_tolerance,
    'heal_amount', v_heal_amount
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.use_potion(UUID, UUID) TO authenticated;

-- 4. use_detox RPC
CREATE OR REPLACE FUNCTION public.use_detox(p_user_id UUID, p_row_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_inv RECORD;
  v_item RECORD;
  v_user RECORD;
  v_tolerance_reduction INT;
  v_addiction_reduction INT;
  v_cooldown_hours INT;
  v_new_tolerance INT;
  v_new_addiction INT;
  v_detox_type TEXT;
BEGIN
  IF p_user_id != auth.uid() THEN
    RETURN jsonb_build_object('error', 'Yetkisiz işlem');
  END IF;

  -- Get user
  SELECT * INTO v_user FROM public.users WHERE auth_id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Kullanıcı bulunamadı');
  END IF;

  -- Get inventory item
  SELECT * INTO v_inv FROM public.inventory WHERE row_id = p_row_id AND user_id = p_user_id AND quantity > 0 FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Eşya bulunamadı veya miktar yetersiz');
  END IF;

  -- Get item stats
  SELECT * INTO v_item FROM public.items WHERE id = v_inv.item_id;
  IF NOT FOUND OR v_item.sub_type != 'detox' THEN
    RETURN jsonb_build_object('error', 'Geçersiz detox içeceği');
  END IF;

  -- Determine detox type based on item ID (assuming han_item_elixir_purge, han_item_clarity etc)
  -- Or we can just read from item stats if provided, but let's hardcode according to PLAN_08
  IF v_item.id = 'detox_minor' THEN
    v_detox_type := 'minor'; v_tolerance_reduction := 15; v_addiction_reduction := 0; v_cooldown_hours := 4;
  ELSIF v_item.id = 'detox_major' THEN
    v_detox_type := 'major'; v_tolerance_reduction := 35; v_addiction_reduction := 1; v_cooldown_hours := 8;
  ELSIF v_item.id = 'detox_supreme' THEN
    v_detox_type := 'supreme'; v_tolerance_reduction := 60; v_addiction_reduction := 2; v_cooldown_hours := 12;
  ELSIF v_item.id = 'detox_full_cleanse' THEN
    v_detox_type := 'full_cleanse'; v_tolerance_reduction := 100; v_addiction_reduction := 10; v_cooldown_hours := 24;
  ELSE
    -- Default fallback if dynamic detox item
    v_detox_type := 'minor'; v_tolerance_reduction := 15; v_addiction_reduction := 0; v_cooldown_hours := 4;
  END IF;

  -- Cooldown kontrolü
  IF v_user.last_detox_used_at IS NOT NULL
     AND v_user.last_detox_used_at + (v_cooldown_hours || ' hours')::interval > now() THEN
    RETURN jsonb_build_object('error', 'Detox cooldown aktif. Kalan süre için bekleyin.');
  END IF;

  v_new_tolerance := GREATEST(COALESCE(v_user.tolerance, 0) - v_tolerance_reduction, 0);
  v_new_addiction := GREATEST(COALESCE(v_user.addiction_level, 0) - v_addiction_reduction, 0);

  -- Consume item FIRST with quantity check
  UPDATE public.inventory SET quantity = quantity - 1 WHERE row_id = p_row_id AND quantity > 0;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Eşya bulunamadı veya miktar yetersiz');
  END IF;
  
  DELETE FROM public.inventory WHERE quantity <= 0 AND row_id = p_row_id;

  -- Güncelle
  UPDATE public.users
  SET tolerance = v_new_tolerance,
      addiction_level = v_new_addiction,
      last_detox_used_at = now(),
      detox_type_last = v_detox_type
  WHERE auth_id = p_user_id;

  -- Log
  INSERT INTO public.tolerance_log (user_id, event_type, item_id, tolerance_before, tolerance_after, addiction_before, addiction_after)
  VALUES (p_user_id, 'detox', v_item.id, COALESCE(v_user.tolerance, 0), v_new_tolerance, COALESCE(v_user.addiction_level, 0), v_new_addiction);

  RETURN jsonb_build_object(
    'success', true,
    'new_tolerance', v_new_tolerance,
    'new_addiction', v_new_addiction
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.use_detox(UUID, UUID) TO authenticated;
