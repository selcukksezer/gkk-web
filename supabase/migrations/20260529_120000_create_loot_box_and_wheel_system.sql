BEGIN;

-- =====================================================
-- Loot Box + Spin Wheel Economy System
-- Full server-side configurability for prices, drop pools,
-- drop rates, currencies and active states.
-- =====================================================

CREATE TABLE IF NOT EXISTS public.loot_box_configs (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  currency_type TEXT NOT NULL CHECK (currency_type IN ('gold', 'gems')),
  price INTEGER NOT NULL CHECK (price > 0),
  reward_multiplier NUMERIC(6,2) NOT NULL DEFAULT 1.00 CHECK (reward_multiplier > 0),
  art_asset TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  display_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.loot_box_drop_entries (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  box_id TEXT NOT NULL REFERENCES public.loot_box_configs(id) ON DELETE CASCADE,
  item_id TEXT NOT NULL REFERENCES public.items(id) ON DELETE CASCADE,
  weight NUMERIC(16,8) NOT NULL CHECK (weight > 0),
  min_quantity INTEGER NOT NULL DEFAULT 1 CHECK (min_quantity > 0),
  max_quantity INTEGER NOT NULL DEFAULT 1 CHECK (max_quantity >= min_quantity),
  show_in_preview BOOLEAN NOT NULL DEFAULT TRUE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (box_id, item_id)
);

CREATE TABLE IF NOT EXISTS public.spin_wheel_configs (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  currency_type TEXT NOT NULL CHECK (currency_type IN ('gold', 'gems')),
  price INTEGER NOT NULL CHECK (price > 0),
  daily_limit INTEGER CHECK (daily_limit IS NULL OR daily_limit >= 0),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  display_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.spin_wheel_reward_entries (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  wheel_id TEXT NOT NULL REFERENCES public.spin_wheel_configs(id) ON DELETE CASCADE,
  reward_type TEXT NOT NULL CHECK (reward_type IN ('item', 'gold', 'gems')),
  item_id TEXT NULL REFERENCES public.items(id) ON DELETE CASCADE,
  amount_min INTEGER NOT NULL DEFAULT 1,
  amount_max INTEGER NOT NULL DEFAULT 1,
  weight NUMERIC(16,8) NOT NULL CHECK (weight > 0),
  show_in_preview BOOLEAN NOT NULL DEFAULT TRUE,
  is_jackpot BOOLEAN NOT NULL DEFAULT FALSE,
  label TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (amount_max >= amount_min),
  CHECK (
    (reward_type = 'item' AND item_id IS NOT NULL)
    OR
    (reward_type IN ('gold', 'gems') AND item_id IS NULL)
  )
);

CREATE TABLE IF NOT EXISTS public.player_loot_box_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  box_id TEXT NOT NULL REFERENCES public.loot_box_configs(id) ON DELETE RESTRICT,
  spent_currency TEXT NOT NULL CHECK (spent_currency IN ('gold', 'gems')),
  spent_amount INTEGER NOT NULL,
  reward_type TEXT NOT NULL CHECK (reward_type IN ('item', 'gold', 'gems')),
  reward_item_id TEXT NULL REFERENCES public.items(id),
  reward_amount INTEGER NOT NULL,
  roll_weight NUMERIC(16,8),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.player_spin_wheel_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  wheel_id TEXT NOT NULL REFERENCES public.spin_wheel_configs(id) ON DELETE RESTRICT,
  spent_currency TEXT NOT NULL CHECK (spent_currency IN ('gold', 'gems')),
  spent_amount INTEGER NOT NULL,
  reward_type TEXT NOT NULL CHECK (reward_type IN ('item', 'gold', 'gems')),
  reward_item_id TEXT NULL REFERENCES public.items(id),
  reward_amount INTEGER NOT NULL,
  roll_weight NUMERIC(16,8),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_loot_box_configs_active_order
  ON public.loot_box_configs (is_active, display_order);

CREATE INDEX IF NOT EXISTS idx_loot_box_drop_entries_box_active
  ON public.loot_box_drop_entries (box_id, is_active);

CREATE INDEX IF NOT EXISTS idx_spin_wheel_configs_active_order
  ON public.spin_wheel_configs (is_active, display_order);

CREATE INDEX IF NOT EXISTS idx_spin_wheel_reward_entries_wheel_active
  ON public.spin_wheel_reward_entries (wheel_id, is_active);

CREATE INDEX IF NOT EXISTS idx_player_loot_box_logs_user_time
  ON public.player_loot_box_logs (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_player_spin_wheel_logs_user_time
  ON public.player_spin_wheel_logs (user_id, created_at DESC);

-- -----------------------------------------------------
-- RLS
-- -----------------------------------------------------
ALTER TABLE public.loot_box_configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loot_box_drop_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.spin_wheel_configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.spin_wheel_reward_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.player_loot_box_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.player_spin_wheel_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS loot_box_configs_select_auth ON public.loot_box_configs;
CREATE POLICY loot_box_configs_select_auth
ON public.loot_box_configs
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS loot_box_drop_entries_select_auth ON public.loot_box_drop_entries;
CREATE POLICY loot_box_drop_entries_select_auth
ON public.loot_box_drop_entries
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS spin_wheel_configs_select_auth ON public.spin_wheel_configs;
CREATE POLICY spin_wheel_configs_select_auth
ON public.spin_wheel_configs
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS spin_wheel_reward_entries_select_auth ON public.spin_wheel_reward_entries;
CREATE POLICY spin_wheel_reward_entries_select_auth
ON public.spin_wheel_reward_entries
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS player_loot_box_logs_select_own ON public.player_loot_box_logs;
CREATE POLICY player_loot_box_logs_select_own
ON public.player_loot_box_logs
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS player_spin_wheel_logs_select_own ON public.player_spin_wheel_logs;
CREATE POLICY player_spin_wheel_logs_select_own
ON public.player_spin_wheel_logs
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- -----------------------------------------------------
-- Query RPCs (client display)
-- -----------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_loot_boxes_with_stats()
RETURNS TABLE (
  id TEXT,
  name TEXT,
  description TEXT,
  currency_type TEXT,
  price INTEGER,
  reward_multiplier NUMERIC,
  art_asset TEXT,
  drop_count INTEGER,
  total_weight NUMERIC,
  jackpot_rate NUMERIC,
  display_order INTEGER
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT
    b.id,
    b.name,
    b.description,
    b.currency_type,
    b.price,
    b.reward_multiplier,
    b.art_asset,
    COUNT(e.id)::INTEGER AS drop_count,
    COALESCE(SUM(e.weight), 0)::NUMERIC AS total_weight,
    COALESCE(
      SUM(CASE WHEN COALESCE(i.rarity, 'common') IN ('legendary', 'mythic') THEN e.weight ELSE 0 END)
      / NULLIF(SUM(e.weight), 0),
      0
    )::NUMERIC AS jackpot_rate,
    b.display_order
  FROM public.loot_box_configs b
  LEFT JOIN public.loot_box_drop_entries e
    ON e.box_id = b.id AND e.is_active = TRUE
  LEFT JOIN public.items i
    ON i.id = e.item_id
  WHERE b.is_active = TRUE
  GROUP BY b.id, b.name, b.description, b.currency_type, b.price, b.reward_multiplier, b.art_asset, b.display_order
  ORDER BY b.display_order, b.id;
$$;

CREATE OR REPLACE FUNCTION public.get_loot_box_drops(p_box_id TEXT)
RETURNS TABLE (
  item_id TEXT,
  item_name TEXT,
  icon TEXT,
  rarity TEXT,
  min_quantity INTEGER,
  max_quantity INTEGER,
  weight NUMERIC,
  drop_rate NUMERIC
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT
    e.item_id,
    i.name AS item_name,
    i.icon,
    COALESCE(i.rarity, 'common') AS rarity,
    e.min_quantity,
    e.max_quantity,
    e.weight,
    (e.weight / NULLIF(SUM(e.weight) OVER (), 0) * 100)::NUMERIC AS drop_rate
  FROM public.loot_box_drop_entries e
  JOIN public.items i ON i.id = e.item_id
  WHERE e.box_id = p_box_id
    AND e.is_active = TRUE
    AND e.show_in_preview = TRUE
  ORDER BY drop_rate DESC, item_name ASC;
$$;

CREATE OR REPLACE FUNCTION public.get_spin_wheels_with_stats()
RETURNS TABLE (
  id TEXT,
  name TEXT,
  description TEXT,
  currency_type TEXT,
  price INTEGER,
  daily_limit INTEGER,
  reward_count INTEGER,
  total_weight NUMERIC,
  jackpot_rate NUMERIC,
  display_order INTEGER
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT
    w.id,
    w.name,
    w.description,
    w.currency_type,
    w.price,
    w.daily_limit,
    COUNT(r.id)::INTEGER AS reward_count,
    COALESCE(SUM(r.weight), 0)::NUMERIC AS total_weight,
    COALESCE(SUM(CASE WHEN r.is_jackpot THEN r.weight ELSE 0 END) / NULLIF(SUM(r.weight), 0), 0)::NUMERIC AS jackpot_rate,
    w.display_order
  FROM public.spin_wheel_configs w
  LEFT JOIN public.spin_wheel_reward_entries r
    ON r.wheel_id = w.id AND r.is_active = TRUE
  WHERE w.is_active = TRUE
  GROUP BY w.id, w.name, w.description, w.currency_type, w.price, w.daily_limit, w.display_order
  ORDER BY w.display_order, w.id;
$$;

CREATE OR REPLACE FUNCTION public.get_spin_wheel_rewards(p_wheel_id TEXT)
RETURNS TABLE (
  reward_type TEXT,
  item_id TEXT,
  item_name TEXT,
  icon TEXT,
  rarity TEXT,
  amount_min INTEGER,
  amount_max INTEGER,
  weight NUMERIC,
  drop_rate NUMERIC,
  is_jackpot BOOLEAN,
  reward_label TEXT
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT
    r.reward_type,
    r.item_id,
    CASE
      WHEN r.reward_type = 'item' THEN i.name
      WHEN r.reward_type = 'gold' THEN 'Gold'
      WHEN r.reward_type = 'gems' THEN 'Elmas'
      ELSE 'Odul'
    END AS item_name,
    COALESCE(i.icon, '') AS icon,
    COALESCE(i.rarity, 'common') AS rarity,
    r.amount_min,
    r.amount_max,
    r.weight,
    (r.weight / NULLIF(SUM(r.weight) OVER (), 0) * 100)::NUMERIC AS drop_rate,
    r.is_jackpot,
    COALESCE(r.label, '') AS reward_label
  FROM public.spin_wheel_reward_entries r
  LEFT JOIN public.items i ON i.id = r.item_id
  WHERE r.wheel_id = p_wheel_id
    AND r.is_active = TRUE
    AND r.show_in_preview = TRUE
  ORDER BY drop_rate DESC, reward_type ASC;
$$;

-- -----------------------------------------------------
-- Economy sink RPC: open loot box
-- -----------------------------------------------------
CREATE OR REPLACE FUNCTION public.open_loot_box(p_box_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_box RECORD;
  v_drop RECORD;
  v_balance_ok BOOLEAN := FALSE;
  v_reward_qty INTEGER;
  v_add_result JSONB;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT *
  INTO v_box
  FROM public.loot_box_configs
  WHERE id = p_box_id
    AND is_active = TRUE
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Kasa bulunamadi veya pasif.');
  END IF;

  IF v_box.currency_type = 'gems' THEN
    UPDATE public.users
    SET gems = gems - v_box.price
    WHERE auth_id = v_user_id
      AND gems >= v_box.price
    RETURNING TRUE INTO v_balance_ok;
  ELSE
    UPDATE public.users
    SET gold = gold - v_box.price
    WHERE auth_id = v_user_id
      AND gold >= v_box.price
    RETURNING TRUE INTO v_balance_ok;
  END IF;

  IF COALESCE(v_balance_ok, FALSE) = FALSE THEN
    RETURN jsonb_build_object('success', false, 'message', 'Yetersiz bakiye.');
  END IF;

  SELECT
    e.item_id,
    e.weight,
    e.min_quantity,
    e.max_quantity,
    i.name AS item_name,
    i.icon,
    COALESCE(i.is_stackable, FALSE) AS is_stackable
  INTO v_drop
  FROM public.loot_box_drop_entries e
  JOIN public.items i ON i.id = e.item_id
  WHERE e.box_id = p_box_id
    AND e.is_active = TRUE
  ORDER BY -LN(GREATEST(random(), 1e-9)) / GREATEST(e.weight, 1e-9)
  LIMIT 1;

  IF NOT FOUND THEN
    IF v_box.currency_type = 'gems' THEN
      UPDATE public.users SET gems = gems + v_box.price WHERE auth_id = v_user_id;
    ELSE
      UPDATE public.users SET gold = gold + v_box.price WHERE auth_id = v_user_id;
    END IF;
    RETURN jsonb_build_object('success', false, 'message', 'Bu kasa icin drop tanimi yok.');
  END IF;

  v_reward_qty := FLOOR(random() * (v_drop.max_quantity - v_drop.min_quantity + 1) + v_drop.min_quantity)::INTEGER;
  v_reward_qty := GREATEST(1, FLOOR(v_reward_qty * COALESCE(v_box.reward_multiplier, 1))::INTEGER);

  IF COALESCE(v_drop.is_stackable, FALSE) = FALSE THEN
    v_reward_qty := 1;
  END IF;

  v_add_result := public.add_inventory_item_v2(
    jsonb_build_object(
      'item_id', v_drop.item_id,
      'quantity', v_reward_qty,
      'allow_stack', true
    ),
    NULL
  );

  IF COALESCE((v_add_result->>'success')::BOOLEAN, FALSE) = FALSE THEN
    IF v_box.currency_type = 'gems' THEN
      UPDATE public.users SET gems = gems + v_box.price WHERE auth_id = v_user_id;
    ELSE
      UPDATE public.users SET gold = gold + v_box.price WHERE auth_id = v_user_id;
    END IF;
    RETURN jsonb_build_object('success', false, 'message', 'Envanter dolu. Kasa ucreti iade edildi.');
  END IF;

  INSERT INTO public.player_loot_box_logs (
    user_id,
    box_id,
    spent_currency,
    spent_amount,
    reward_type,
    reward_item_id,
    reward_amount,
    roll_weight,
    metadata
  ) VALUES (
    v_user_id,
    v_box.id,
    v_box.currency_type,
    v_box.price,
    'item',
    v_drop.item_id,
    v_reward_qty,
    v_drop.weight,
    jsonb_build_object(
      'box_name', v_box.name,
      'item_name', v_drop.item_name
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Kasa acildi.',
    'box_id', v_box.id,
    'box_name', v_box.name,
    'spent_currency', v_box.currency_type,
    'spent_amount', v_box.price,
    'reward', jsonb_build_object(
      'type', 'item',
      'item_id', v_drop.item_id,
      'name', v_drop.item_name,
      'icon', COALESCE(v_drop.icon, ''),
      'quantity', v_reward_qty
    )
  );
END;
$$;

-- -----------------------------------------------------
-- Economy sink RPC: spin wheel
-- -----------------------------------------------------
CREATE OR REPLACE FUNCTION public.spin_wheel(p_wheel_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_wheel RECORD;
  v_reward RECORD;
  v_balance_ok BOOLEAN := FALSE;
  v_today_count INTEGER := 0;
  v_reward_amount INTEGER;
  v_add_result JSONB;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT *
  INTO v_wheel
  FROM public.spin_wheel_configs
  WHERE id = p_wheel_id
    AND is_active = TRUE
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Cark bulunamadi veya pasif.');
  END IF;

  IF v_wheel.daily_limit IS NOT NULL THEN
    SELECT COUNT(*)
    INTO v_today_count
    FROM public.player_spin_wheel_logs
    WHERE user_id = v_user_id
      AND wheel_id = v_wheel.id
      AND created_at::date = (now() at time zone 'utc')::date;

    IF v_today_count >= v_wheel.daily_limit THEN
      RETURN jsonb_build_object('success', false, 'message', 'Gunluk cark limiti doldu.');
    END IF;
  END IF;

  IF v_wheel.currency_type = 'gems' THEN
    UPDATE public.users
    SET gems = gems - v_wheel.price
    WHERE auth_id = v_user_id
      AND gems >= v_wheel.price
    RETURNING TRUE INTO v_balance_ok;
  ELSE
    UPDATE public.users
    SET gold = gold - v_wheel.price
    WHERE auth_id = v_user_id
      AND gold >= v_wheel.price
    RETURNING TRUE INTO v_balance_ok;
  END IF;

  IF COALESCE(v_balance_ok, FALSE) = FALSE THEN
    RETURN jsonb_build_object('success', false, 'message', 'Yetersiz bakiye.');
  END IF;

  SELECT
    r.reward_type,
    r.item_id,
    r.amount_min,
    r.amount_max,
    r.weight,
    r.is_jackpot,
    COALESCE(r.label, '') AS reward_label,
    i.name AS item_name,
    i.icon,
    COALESCE(i.is_stackable, FALSE) AS is_stackable
  INTO v_reward
  FROM public.spin_wheel_reward_entries r
  LEFT JOIN public.items i ON i.id = r.item_id
  WHERE r.wheel_id = p_wheel_id
    AND r.is_active = TRUE
  ORDER BY -LN(GREATEST(random(), 1e-9)) / GREATEST(r.weight, 1e-9)
  LIMIT 1;

  IF NOT FOUND THEN
    IF v_wheel.currency_type = 'gems' THEN
      UPDATE public.users SET gems = gems + v_wheel.price WHERE auth_id = v_user_id;
    ELSE
      UPDATE public.users SET gold = gold + v_wheel.price WHERE auth_id = v_user_id;
    END IF;
    RETURN jsonb_build_object('success', false, 'message', 'Bu cark icin odul tanimi yok.');
  END IF;

  v_reward_amount := FLOOR(random() * (v_reward.amount_max - v_reward.amount_min + 1) + v_reward.amount_min)::INTEGER;
  v_reward_amount := GREATEST(v_reward_amount, 0);

  IF v_reward.reward_type = 'item' THEN
    IF COALESCE(v_reward.is_stackable, FALSE) = FALSE THEN
      v_reward_amount := 1;
    END IF;

    v_add_result := public.add_inventory_item_v2(
      jsonb_build_object(
        'item_id', v_reward.item_id,
        'quantity', v_reward_amount,
        'allow_stack', true
      ),
      NULL
    );

    IF COALESCE((v_add_result->>'success')::BOOLEAN, FALSE) = FALSE THEN
      IF v_wheel.currency_type = 'gems' THEN
        UPDATE public.users SET gems = gems + v_wheel.price WHERE auth_id = v_user_id;
      ELSE
        UPDATE public.users SET gold = gold + v_wheel.price WHERE auth_id = v_user_id;
      END IF;
      RETURN jsonb_build_object('success', false, 'message', 'Envanter dolu. Cark ucreti iade edildi.');
    END IF;
  ELSIF v_reward.reward_type = 'gold' THEN
    UPDATE public.users
    SET gold = gold + v_reward_amount
    WHERE auth_id = v_user_id;
  ELSE
    UPDATE public.users
    SET gems = gems + v_reward_amount
    WHERE auth_id = v_user_id;
  END IF;

  INSERT INTO public.player_spin_wheel_logs (
    user_id,
    wheel_id,
    spent_currency,
    spent_amount,
    reward_type,
    reward_item_id,
    reward_amount,
    roll_weight,
    metadata
  ) VALUES (
    v_user_id,
    v_wheel.id,
    v_wheel.currency_type,
    v_wheel.price,
    v_reward.reward_type,
    v_reward.item_id,
    v_reward_amount,
    v_reward.weight,
    jsonb_build_object(
      'wheel_name', v_wheel.name,
      'reward_label', v_reward.reward_label,
      'item_name', v_reward.item_name,
      'is_jackpot', v_reward.is_jackpot
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Cark cevrildi.',
    'wheel_id', v_wheel.id,
    'wheel_name', v_wheel.name,
    'spent_currency', v_wheel.currency_type,
    'spent_amount', v_wheel.price,
    'reward', jsonb_build_object(
      'type', v_reward.reward_type,
      'item_id', v_reward.item_id,
      'name',
        CASE
          WHEN v_reward.reward_type = 'item' THEN COALESCE(v_reward.item_name, 'Item')
          WHEN v_reward.reward_type = 'gold' THEN 'Gold'
          ELSE 'Elmas'
        END,
      'icon', COALESCE(v_reward.icon, ''),
      'quantity', v_reward_amount,
      'amount', v_reward_amount,
      'is_jackpot', v_reward.is_jackpot
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_loot_boxes_with_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_loot_box_drops(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.open_loot_box(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_spin_wheels_with_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_spin_wheel_rewards(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.spin_wheel(TEXT) TO authenticated;

-- -----------------------------------------------------
-- Seed: 50 loot boxes (all items included in each drop pool)
-- Gold boxes: more expensive, lower reward multiplier and weaker rarity odds.
-- Gem boxes: cheaper than equivalent gold sink, better rarity odds.
-- -----------------------------------------------------
INSERT INTO public.loot_box_configs (
  id,
  name,
  description,
  currency_type,
  price,
  reward_multiplier,
  art_asset,
  is_active,
  display_order
)
SELECT
  'box_' || lpad(gs::text, 2, '0') AS id,
  CASE
    WHEN gs <= 25 THEN 'Prizma Kasasi #' || lpad(gs::text, 2, '0')
    ELSE 'Han Hazinesi #' || lpad(gs::text, 2, '0')
  END AS name,
  CASE
    WHEN gs <= 25 THEN 'Elmasla acilan premium kasa. Nadir item sansi daha yuksek.'
    ELSE 'Goldla acilan agir ekonomi kasasi. Maliyet yuksek, ortalama odul dusuk.'
  END AS description,
  CASE WHEN gs <= 25 THEN 'gems' ELSE 'gold' END AS currency_type,
  CASE
    WHEN gs <= 25 THEN 35 + (gs * 7)
    ELSE 600000 + ((gs - 25) * 180000)
  END AS price,
  CASE
    WHEN gs <= 25 THEN 1.00 + (gs * 0.01)
    ELSE 0.65 + ((gs - 25) * 0.004)
  END AS reward_multiplier,
  'assets/elements/redcase512px.png' AS art_asset,
  TRUE AS is_active,
  gs AS display_order
FROM generate_series(1, 50) AS gs
ON CONFLICT (id) DO UPDATE
SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  currency_type = EXCLUDED.currency_type,
  price = EXCLUDED.price,
  reward_multiplier = EXCLUDED.reward_multiplier,
  art_asset = EXCLUDED.art_asset,
  is_active = EXCLUDED.is_active,
  display_order = EXCLUDED.display_order,
  updated_at = now();

INSERT INTO public.loot_box_drop_entries (
  box_id,
  item_id,
  weight,
  min_quantity,
  max_quantity,
  show_in_preview,
  is_active
)
SELECT
  b.id AS box_id,
  i.id AS item_id,
  (
    CASE
      WHEN COALESCE(i.rarity, 'common') = 'mythic' THEN CASE WHEN b.currency_type = 'gems' THEN 0.020 ELSE 0.004 END
      WHEN COALESCE(i.rarity, 'common') = 'legendary' THEN CASE WHEN b.currency_type = 'gems' THEN 0.060 ELSE 0.012 END
      WHEN COALESCE(i.rarity, 'common') = 'epic' THEN CASE WHEN b.currency_type = 'gems' THEN 0.250 ELSE 0.070 END
      WHEN COALESCE(i.rarity, 'common') = 'rare' THEN CASE WHEN b.currency_type = 'gems' THEN 0.900 ELSE 0.350 END
      WHEN COALESCE(i.rarity, 'common') = 'uncommon' THEN CASE WHEN b.currency_type = 'gems' THEN 2.000 ELSE 1.500 END
      ELSE CASE WHEN b.currency_type = 'gems' THEN 4.500 ELSE 8.000 END
    END
  )
  * (1.0 + (b.display_order::numeric / 260.0))
  AS weight,
  1 AS min_quantity,
  CASE
    WHEN COALESCE(i.is_stackable, FALSE) = FALSE THEN 1
    WHEN b.currency_type = 'gems' THEN GREATEST(1, LEAST(COALESCE(i.max_stack, 1), 1 + (b.display_order / 7)))
    ELSE GREATEST(1, LEAST(COALESCE(i.max_stack, 1), 1 + (b.display_order / 14)))
  END AS max_quantity,
  (COALESCE(i.rarity, 'common') IN ('legendary', 'mythic')) AS show_in_preview,
  TRUE AS is_active
FROM public.loot_box_configs b
CROSS JOIN public.items i
WHERE i.id IS NOT NULL
ON CONFLICT (box_id, item_id) DO UPDATE
SET
  weight = EXCLUDED.weight,
  min_quantity = EXCLUDED.min_quantity,
  max_quantity = EXCLUDED.max_quantity,
  show_in_preview = EXCLUDED.show_in_preview,
  is_active = EXCLUDED.is_active,
  updated_at = now();

-- -----------------------------------------------------
-- Seed: spin wheels (fully configurable from Supabase)
-- -----------------------------------------------------
INSERT INTO public.spin_wheel_configs (
  id,
  name,
  description,
  currency_type,
  price,
  daily_limit,
  is_active,
  display_order
)
VALUES
  ('wheel_gem_01', 'Prizma Cark I', 'Elmas ile premium cark.', 'gems', 35, NULL, TRUE, 1),
  ('wheel_gem_02', 'Prizma Cark II', 'Daha iyi odul havuzu.', 'gems', 55, NULL, TRUE, 2),
  ('wheel_gem_03', 'Prizma Cark III', 'Yuksek risk yuksek odul.', 'gems', 85, NULL, TRUE, 3),
  ('wheel_gold_01', 'Han Carki I', 'Gold ile cevrilen agir ekonomi carki.', 'gold', 750000, NULL, TRUE, 4),
  ('wheel_gold_02', 'Han Carki II', 'Daha pahali ama limitli premium.', 'gold', 1250000, NULL, TRUE, 5),
  ('wheel_gold_03', 'Han Carki III', 'En yuksek gold sink carki.', 'gold', 2200000, NULL, TRUE, 6)
ON CONFLICT (id) DO UPDATE
SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  currency_type = EXCLUDED.currency_type,
  price = EXCLUDED.price,
  daily_limit = EXCLUDED.daily_limit,
  is_active = EXCLUDED.is_active,
  display_order = EXCLUDED.display_order,
  updated_at = now();

-- Item rewards for each wheel (all items included)
INSERT INTO public.spin_wheel_reward_entries (
  wheel_id,
  reward_type,
  item_id,
  amount_min,
  amount_max,
  weight,
  show_in_preview,
  is_jackpot,
  label,
  is_active
)
SELECT
  w.id,
  'item' AS reward_type,
  i.id,
  1 AS amount_min,
  CASE
    WHEN COALESCE(i.is_stackable, FALSE) = FALSE THEN 1
    WHEN w.currency_type = 'gems' THEN GREATEST(1, LEAST(COALESCE(i.max_stack, 1), 4 + (w.display_order * 2)))
    ELSE GREATEST(1, LEAST(COALESCE(i.max_stack, 1), 2 + w.display_order))
  END AS amount_max,
  (
    CASE
      WHEN COALESCE(i.rarity, 'common') = 'mythic' THEN CASE WHEN w.currency_type = 'gems' THEN 0.010 ELSE 0.002 END
      WHEN COALESCE(i.rarity, 'common') = 'legendary' THEN CASE WHEN w.currency_type = 'gems' THEN 0.040 ELSE 0.008 END
      WHEN COALESCE(i.rarity, 'common') = 'epic' THEN CASE WHEN w.currency_type = 'gems' THEN 0.180 ELSE 0.050 END
      WHEN COALESCE(i.rarity, 'common') = 'rare' THEN CASE WHEN w.currency_type = 'gems' THEN 0.700 ELSE 0.250 END
      WHEN COALESCE(i.rarity, 'common') = 'uncommon' THEN CASE WHEN w.currency_type = 'gems' THEN 1.500 ELSE 1.000 END
      ELSE CASE WHEN w.currency_type = 'gems' THEN 3.000 ELSE 6.000 END
    END
  ) * (1 + w.display_order::numeric / 20.0) AS weight,
  (COALESCE(i.rarity, 'common') IN ('legendary', 'mythic')) AS show_in_preview,
  (COALESCE(i.rarity, 'common') IN ('legendary', 'mythic')) AS is_jackpot,
  NULL AS label,
  TRUE AS is_active
FROM public.spin_wheel_configs w
CROSS JOIN public.items i
WHERE i.id IS NOT NULL
ON CONFLICT DO NOTHING;

-- Currency rewards for each wheel (editable from Supabase)
INSERT INTO public.spin_wheel_reward_entries (
  wheel_id,
  reward_type,
  item_id,
  amount_min,
  amount_max,
  weight,
  show_in_preview,
  is_jackpot,
  label,
  is_active
)
VALUES
  ('wheel_gem_01', 'gold', NULL, 75000, 200000, 2.0, TRUE, FALSE, 'Gold Paketi', TRUE),
  ('wheel_gem_01', 'gems', NULL, 5, 12, 0.35, TRUE, FALSE, 'Elmas Iade', TRUE),
  ('wheel_gem_02', 'gold', NULL, 150000, 420000, 1.8, TRUE, FALSE, 'Gold Paketi', TRUE),
  ('wheel_gem_02', 'gems', NULL, 8, 18, 0.30, TRUE, FALSE, 'Elmas Iade', TRUE),
  ('wheel_gem_03', 'gold', NULL, 300000, 900000, 1.6, TRUE, FALSE, 'Gold Paketi', TRUE),
  ('wheel_gem_03', 'gems', NULL, 12, 30, 0.26, TRUE, TRUE, 'Buyuk Elmas Iade', TRUE),

  ('wheel_gold_01', 'gold', NULL, 90000, 250000, 1.7, TRUE, FALSE, 'Gold Bonus', TRUE),
  ('wheel_gold_01', 'gems', NULL, 1, 3, 0.08, TRUE, FALSE, 'Mini Elmas', TRUE),
  ('wheel_gold_02', 'gold', NULL, 160000, 500000, 1.5, TRUE, FALSE, 'Gold Bonus', TRUE),
  ('wheel_gold_02', 'gems', NULL, 2, 4, 0.07, TRUE, FALSE, 'Mini Elmas', TRUE),
  ('wheel_gold_03', 'gold', NULL, 250000, 800000, 1.3, TRUE, FALSE, 'Gold Bonus', TRUE),
  ('wheel_gold_03', 'gems', NULL, 2, 6, 0.06, TRUE, TRUE, 'Nadir Elmas', TRUE)
ON CONFLICT DO NOTHING;

COMMIT;
