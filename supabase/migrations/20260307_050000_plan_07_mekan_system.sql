-- =========================================================================================
-- MIGRATION: PLAN_07_MEKAN_SYSTEM
-- =========================================================================================

-- 1. Create Mekan Tables
CREATE TABLE IF NOT EXISTS public.mekans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  mekan_type TEXT NOT NULL CHECK (mekan_type IN ('bar', 'kahvehane', 'dovus_kulubu', 'luks_lounge', 'yeralti')),
  name TEXT NOT NULL,
  level INTEGER NOT NULL DEFAULT 1 CHECK (level >= 1 AND level <= 10),
  fame INTEGER NOT NULL DEFAULT 0,
  suspicion INTEGER NOT NULL DEFAULT 0 CHECK (suspicion >= 0 AND suspicion <= 100),
  is_open BOOLEAN NOT NULL DEFAULT true,
  closed_until TIMESTAMPTZ,
  monthly_rent_paid_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  UNIQUE(owner_id) -- Her oyuncu max 1 mekan
);

CREATE TABLE IF NOT EXISTS public.mekan_stock (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mekan_id UUID NOT NULL REFERENCES public.mekans(id) ON DELETE CASCADE,
  item_id TEXT NOT NULL REFERENCES public.items(id),
  quantity INTEGER NOT NULL DEFAULT 0 CHECK (quantity >= 0),
  sell_price BIGINT NOT NULL CHECK (sell_price > 0),
  stocked_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  UNIQUE(mekan_id, item_id)
);

CREATE TABLE IF NOT EXISTS public.mekan_sales (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mekan_id UUID NOT NULL REFERENCES public.mekans(id) ON DELETE CASCADE,
  buyer_id UUID NOT NULL REFERENCES auth.users(id),
  item_id TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  price_per_unit BIGINT NOT NULL,
  total_price BIGINT NOT NULL,
  owner_profit BIGINT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.mekan_pvp_matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mekan_id UUID NOT NULL REFERENCES public.mekans(id) ON DELETE CASCADE,
  attacker_id UUID NOT NULL REFERENCES auth.users(id),
  defender_id UUID NOT NULL REFERENCES auth.users(id),
  winner_id UUID REFERENCES auth.users(id),
  gold_wagered BIGINT NOT NULL DEFAULT 0,
  gold_won BIGINT NOT NULL DEFAULT 0,
  mekan_commission BIGINT NOT NULL DEFAULT 0,
  attacker_rating_change INTEGER NOT NULL DEFAULT 0,
  defender_rating_change INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS Policies
ALTER TABLE public.mekans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mekan_stock ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mekan_sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mekan_pvp_matches ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Mekans viewable by everyone' AND tablename = 'mekans') THEN
    CREATE POLICY "Mekans viewable by everyone" ON public.mekans FOR SELECT USING (true);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Mekan stock viewable by everyone' AND tablename = 'mekan_stock') THEN
    CREATE POLICY "Mekan stock viewable by everyone" ON public.mekan_stock FOR SELECT USING (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Owners can update their mekan' AND tablename = 'mekans') THEN
    CREATE POLICY "Owners can update their mekan" ON public.mekans FOR UPDATE USING (auth.uid() = owner_id);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Sales viewable by owner and buyer' AND tablename = 'mekan_sales') THEN
    CREATE POLICY "Sales viewable by owner and buyer" ON public.mekan_sales FOR SELECT USING (
      auth.uid() = buyer_id OR 
      auth.uid() IN (SELECT owner_id FROM public.mekans WHERE id = mekan_id)
    );
  END IF;
END $$;

-- 2. Seed Han-Only Items
INSERT INTO public.items (
  id, name, name_tr, type, sub_type, description, rarity, 
  base_price, is_tradeable, is_market_tradeable, is_direct_tradeable, is_han_only,
  energy_restore, heal_amount, tolerance_increase, overdose_risk
) VALUES
  ('han_item_vigor_minor', 'Vinum Vigor Minor', 'Küçük Han Şarabı', 'potion', 'energy', '+50 enerji; tolerance +3', 'common', 100000, true, false, false, true, 50, 0, 3, 0),
  ('han_item_vigor_major', 'Vinum Vigor Major', 'Büyük Han Şarabı', 'potion', 'energy', '+100 enerji; tolerance +8; overdose riski', 'rare', 400000, true, false, false, true, 100, 0, 8, 0.05),
  ('han_item_elixir_purge', 'Elixir Purgationis', 'Arındırma İçeceği', 'potion', 'detox', 'tolerance -20', 'uncommon', 250000, true, false, false, true, 0, 0, -20, 0),
  ('han_item_clarity', 'Potio Claritatis', 'Berraklık İksiri', 'potion', 'detox', 'tolerance -40', 'rare', 1000000, true, false, false, true, 0, 0, -40, 0),
  ('han_item_berserk', 'Furor Berserkium', 'Berserker Özü', 'potion', 'buff', 'ATK artışı; tolerance +20; yüksek overdose', 'epic', 2500000, true, false, false, true, 0, 0, 20, 0.25),
  ('han_item_shadow_brew', 'Potio Umbrarum', 'Gölge Karışımı', 'potion', 'buff', 'PvP dodge artışı; tolerance +10', 'epic', 2000000, true, false, false, true, 0, 0, 10, 0.10),
  ('han_item_restoration', 'Restoratio Magna', 'Büyük Restorasyon', 'potion', 'health', 'HP +15,000; tolerance +5', 'legendary', 2000000, true, false, false, true, 0, 15000, 5, 0)
ON CONFLICT (id) DO UPDATE SET
  is_han_only = EXCLUDED.is_han_only,
  is_market_tradeable = EXCLUDED.is_market_tradeable,
  is_direct_tradeable = EXCLUDED.is_direct_tradeable;

-- 3. RPC: open_mekan
CREATE OR REPLACE FUNCTION public.open_mekan(
  p_user_id UUID, 
  p_mekan_type TEXT, 
  p_name TEXT
) RETURNS JSONB AS $$
DECLARE
  v_cost BIGINT;
  v_level_req INT;
  v_user_level INT;
  v_user_gold BIGINT;
BEGIN
  IF p_user_id != auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz işlem');
  END IF;

  -- Validate mekan type and get cost/level req
  IF p_mekan_type = 'bar' THEN
    v_cost := 5000000;
    v_level_req := 15;
  ELSIF p_mekan_type = 'kahvehane' THEN
    v_cost := 8000000;
    v_level_req := 20;
  ELSIF p_mekan_type = 'dovus_kulubu' THEN
    v_cost := 15000000;
    v_level_req := 30;
  ELSIF p_mekan_type = 'luks_lounge' THEN
    v_cost := 50000000;
    v_level_req := 45;
  ELSIF p_mekan_type = 'yeralti' THEN
    v_cost := 200000000;
    v_level_req := 60;
  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz mekan türü');
  END IF;

  SELECT level, gold INTO v_user_level, v_user_gold
  FROM public.users WHERE auth_id = p_user_id;

  IF v_user_level < v_level_req THEN
    RETURN jsonb_build_object('success', false, 'error', 'Level yetersiz. Gereken: ' || v_level_req);
  END IF;

  IF v_user_gold < v_cost THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gold yetersiz. Gereken: ' || v_cost);
  END IF;

  -- Check if user already has a mekan
  IF EXISTS (SELECT 1 FROM public.mekans WHERE owner_id = p_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Zaten bir mekanınız var');
  END IF;

  -- Deduct gold and insert mekan
  UPDATE public.users SET gold = gold - v_cost WHERE auth_id = p_user_id AND gold >= v_cost;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'İşlem sırasında altın yetersiz kaldı');
  END IF;

  INSERT INTO public.mekans (owner_id, mekan_type, name)
  VALUES (p_user_id, p_mekan_type, p_name);

  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.open_mekan(UUID, TEXT, TEXT) TO authenticated;

-- 4. RPC: buy_from_mekan
CREATE OR REPLACE FUNCTION public.buy_from_mekan(
  p_buyer_id UUID, 
  p_mekan_id UUID, 
  p_item_id TEXT, 
  p_quantity INT
) RETURNS JSONB AS $$
DECLARE
  v_stock RECORD;
  v_mekan RECORD;
  v_total_price BIGINT;
  v_owner_profit BIGINT;
  v_buyer_gold BIGINT;
BEGIN
  IF p_buyer_id != auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz işlem');
  END IF;

  -- Check if mekan is open
  SELECT * INTO v_mekan FROM public.mekans WHERE id = p_mekan_id AND is_open = true;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mekan kapalı veya bulunamadı');
  END IF;

  -- Check stock
  SELECT * INTO v_stock FROM public.mekan_stock
  WHERE mekan_id = p_mekan_id AND item_id = p_item_id AND quantity >= p_quantity FOR UPDATE;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Stok yetersiz');
  END IF;

  v_total_price := v_stock.sell_price * p_quantity;

  -- Check buyer gold
  SELECT gold INTO v_buyer_gold FROM public.users WHERE auth_id = p_buyer_id FOR UPDATE;
  IF v_buyer_gold < v_total_price THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gold yetersiz');
  END IF;

  -- Cannot buy from own mekan
  IF p_buyer_id = v_mekan.owner_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kendi mekanınızdan satın alamazsınız');
  END IF;

  v_owner_profit := v_total_price; -- 100% to owner

  -- Transactions
  UPDATE public.users SET gold = gold - v_total_price WHERE auth_id = p_buyer_id AND gold >= v_total_price;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'İşlem sırasında altın yetersiz kaldı');
  END IF;

  UPDATE public.users SET gold = gold + v_owner_profit WHERE auth_id = v_mekan.owner_id;
  
  UPDATE public.mekan_stock SET quantity = quantity - p_quantity
  WHERE mekan_id = p_mekan_id AND item_id = p_item_id;
  
  -- Add item to inventory
  INSERT INTO public.inventory (row_id, user_id, item_id, quantity, obtained_at)
  VALUES (gen_random_uuid(), p_buyer_id, p_item_id, p_quantity, EXTRACT(EPOCH FROM NOW())::BIGINT);

  -- Log sale
  INSERT INTO public.mekan_sales (mekan_id, buyer_id, item_id, quantity, price_per_unit, total_price, owner_profit)
  VALUES (p_mekan_id, p_buyer_id, p_item_id, p_quantity, v_stock.sell_price, v_total_price, v_owner_profit);

  -- Fame increase (1 per item sold)
  UPDATE public.mekans SET fame = fame + p_quantity WHERE id = p_mekan_id;

  RETURN jsonb_build_object('success', true, 'total_price', v_total_price);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.buy_from_mekan(UUID, UUID, TEXT, INT) TO authenticated;

-- 5. RPC: use_han_item
CREATE OR REPLACE FUNCTION public.use_han_item(
  p_user_id UUID,
  p_row_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_inv RECORD;
  v_item RECORD;
  v_user RECORD;
  v_overdose_chance NUMERIC;
  v_is_overdose BOOLEAN := false;
  v_tolerance_mult NUMERIC := 1.0;
  v_hospital_minutes INT;
BEGIN
  IF p_user_id != auth.uid() THEN
    RETURN jsonb_build_object('error', 'Yetkisiz işlem');
  END IF;

  -- Get user
  SELECT * INTO v_user FROM public.users WHERE auth_id = p_user_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Kullanıcı bulunamadı');
  END IF;

  -- Get inventory item
  SELECT * INTO v_inv FROM public.inventory WHERE row_id = p_row_id AND user_id = p_user_id AND quantity > 0;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Eşya bulunamadı');
  END IF;

  -- Get item stats
  SELECT * INTO v_item FROM public.items WHERE id = v_inv.item_id;
  IF NOT v_item.is_han_only THEN
    RETURN jsonb_build_object('error', 'Bu bir Han eşyası değil, use_potion kullanın');
  END IF;

  -- Check overdose risk
  IF COALESCE(v_user.tolerance, 0) > 60 AND COALESCE(v_item.overdose_risk, 0) > 0 THEN
    v_tolerance_mult := v_user.tolerance / 50.0;
    v_overdose_chance := v_item.overdose_risk * v_tolerance_mult;
    
    -- Alchemist overdose reduction
    IF COALESCE(v_user.character_class, '') = 'alchemist' THEN
      v_overdose_chance := v_overdose_chance * 0.80;
    END IF;

    IF random() <= v_overdose_chance THEN
      v_is_overdose := true;
    END IF;
  END IF;

  -- Consume item FIRST with quantity check to prevent double use
  UPDATE public.inventory SET quantity = quantity - 1 WHERE row_id = p_row_id AND quantity > 0;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Eşya bulunamadı veya miktar yetersiz');
  END IF;
  
  DELETE FROM public.inventory WHERE quantity <= 0 AND row_id = p_row_id;

  -- Apply effects or overdose
  IF v_is_overdose THEN
    -- Overdose penalty: Hospital for 2-4 hours, massive tolerance penalty
    v_hospital_minutes := 120 + floor(random() * 120);
    
    UPDATE public.users
    SET
      hospital_until = now() + (v_hospital_minutes || ' minutes')::INTERVAL,
      hospital_reason = 'Han İksiri Overdose',
      tolerance = LEAST(100, COALESCE(tolerance, 0) + 15)
    WHERE auth_id = p_user_id;

    RETURN jsonb_build_object(
      'success', true,
      'overdose', true,
      'hospital_minutes', v_hospital_minutes
    );
  ELSE
    -- Normal use
    UPDATE public.users
    SET
      energy = LEAST(100, energy + COALESCE(v_item.energy_restore, 0)),
      health = LEAST(max_health, health + COALESCE(v_item.heal_amount, 0)),
      tolerance = GREATEST(0, LEAST(100, COALESCE(tolerance, 0) + COALESCE(v_item.tolerance_increase, 0)))
    WHERE auth_id = p_user_id;

    RETURN jsonb_build_object(
      'success', true,
      'overdose', false,
      'energy_restored', COALESCE(v_item.energy_restore, 0),
      'new_tolerance', GREATEST(0, LEAST(100, COALESCE(v_user.tolerance, 0) + COALESCE(v_item.tolerance_increase, 0)))
    );
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.use_han_item(UUID, UUID) TO authenticated;

-- 6. RPC: pvp_attack_mekan
CREATE OR REPLACE FUNCTION public.pvp_attack_mekan(
  p_attacker_id UUID,
  p_defender_id UUID,
  p_mekan_id UUID,
  p_wager BIGINT
) RETURNS JSONB AS $$
DECLARE
  v_attacker RECORD;
  v_defender RECORD;
  v_mekan RECORD;
  v_winner_id UUID;
  v_loser_id UUID;
  v_win_chance NUMERIC;
  v_att_rating_change INT;
  v_def_rating_change INT;
  v_commission BIGINT;
  v_net_win BIGINT;
  v_hospitalized BOOLEAN := false;
  v_att_power NUMERIC;
  v_def_power NUMERIC;
BEGIN
  -- Get mekan
  SELECT * INTO v_mekan FROM public.mekans WHERE id = p_mekan_id AND is_open = true;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Mekan kapalı veya geçersiz');
  END IF;

  IF v_mekan.mekan_type NOT IN ('dovus_kulubu', 'luks_lounge', 'yeralti') THEN
    RETURN jsonb_build_object('error', 'Bu mekan türünde PvP yapılamaz');
  END IF;

  -- Get players
  SELECT * INTO v_attacker FROM public.users WHERE auth_id = p_attacker_id FOR UPDATE;
  SELECT * INTO v_defender FROM public.users WHERE auth_id = p_defender_id FOR UPDATE;

  IF v_attacker IS NULL OR v_defender IS NULL THEN
    RETURN jsonb_build_object('error', 'Oyuncu bulunamadı');
  END IF;

  IF v_attacker.energy < 15 THEN
    RETURN jsonb_build_object('error', 'Yetersiz enerji (15 gerekli)');
  END IF;

  IF v_attacker.gold < p_wager THEN
    RETURN jsonb_build_object('error', 'Yetersiz altın (bahis için)');
  END IF;

  IF v_defender.gold < p_wager THEN
    RETURN jsonb_build_object('error', 'Rakibin yeterli altını yok');
  END IF;

  -- Calculate win chance based on power (simplified)
  v_att_power := COALESCE(v_attacker.attack, 10) + COALESCE(v_attacker.defense, 10);
  v_def_power := COALESCE(v_defender.attack, 10) + COALESCE(v_defender.defense, 10);

  -- Shadow class 15% dodge bonus could be integrated here, simplified
  IF COALESCE(v_defender.character_class, '') = 'shadow' THEN
    v_def_power := v_def_power * 1.15;
  END IF;
  IF COALESCE(v_attacker.character_class, '') = 'shadow' THEN
    v_att_power := v_att_power * 1.15;
  END IF;

  v_win_chance := v_att_power / NULLIF(v_att_power + v_def_power, 0);
  IF v_win_chance IS NULL THEN v_win_chance := 0.5; END IF;

  -- Roll
  IF random() <= v_win_chance THEN
    v_winner_id := p_attacker_id;
    v_loser_id := p_defender_id;
    v_att_rating_change := 15 + floor(random() * 10);
    v_def_rating_change := -(10 + floor(random() * 5));
  ELSE
    v_winner_id := p_defender_id;
    v_loser_id := p_attacker_id;
    v_att_rating_change := -(10 + floor(random() * 5));
    v_def_rating_change := 15 + floor(random() * 10);
  END IF;

  -- Financials
  v_commission := floor((p_wager * 2) * 0.05); -- 5% of total pool
  v_net_win := (p_wager * 2) - v_commission;

  -- Transactions
  UPDATE public.users SET
    gold = gold - p_wager,
    energy = energy - 15,
    pvp_rating = GREATEST(0, COALESCE(pvp_rating, 1000) + v_att_rating_change),
    pvp_wins = COALESCE(pvp_wins, 0) + CASE WHEN v_winner_id = p_attacker_id THEN 1 ELSE 0 END,
    pvp_losses = COALESCE(pvp_losses, 0) + CASE WHEN v_loser_id = p_attacker_id THEN 1 ELSE 0 END
  WHERE auth_id = p_attacker_id AND gold >= p_wager AND energy >= 15;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'İşlem sırasında enerji veya altın yetersiz kaldı');
  END IF;

  UPDATE public.users SET
    gold = gold - p_wager,
    pvp_rating = GREATEST(0, COALESCE(pvp_rating, 1000) + v_def_rating_change),
    pvp_wins = COALESCE(pvp_wins, 0) + CASE WHEN v_winner_id = p_defender_id THEN 1 ELSE 0 END,
    pvp_losses = COALESCE(pvp_losses, 0) + CASE WHEN v_loser_id = p_defender_id THEN 1 ELSE 0 END
  WHERE auth_id = p_defender_id AND gold >= p_wager;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Rakibin işlemi sırasında hata (altın yetersiz)');
  END IF;

  -- Give win pool
  UPDATE public.users SET gold = gold + v_net_win WHERE auth_id = v_winner_id;

  -- Give commission to mekan owner
  UPDATE public.users SET gold = gold + v_commission WHERE auth_id = v_mekan.owner_id;

  -- Hospital risk for loser (10%)
  IF random() <= 0.10 THEN
    v_hospitalized := true;
    UPDATE public.users SET 
      hospital_until = now() + '30 minutes'::INTERVAL,
      hospital_reason = 'PvP Maçı Kaybı'
    WHERE auth_id = v_loser_id;
  END IF;

  -- Log match
  INSERT INTO public.mekan_pvp_matches (
    mekan_id, attacker_id, defender_id, winner_id, 
    gold_wagered, gold_won, mekan_commission, 
    attacker_rating_change, defender_rating_change
  ) VALUES (
    p_mekan_id, p_attacker_id, p_defender_id, v_winner_id,
    p_wager, v_net_win, v_commission,
    v_att_rating_change, v_def_rating_change
  );

  RETURN jsonb_build_object(
    'success', true,
    'winner_id', v_winner_id,
    'net_win', v_net_win,
    'hospitalized', v_hospitalized,
    'attacker_rating_change', v_att_rating_change,
    'defender_rating_change', v_def_rating_change
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.pvp_attack_mekan(UUID, UUID, UUID, BIGINT) TO authenticated;
