-- PLAN 11: Karakter SÄ±nÄ±fÄ± & Stat Sistemi
-- 1. Tablolara yeni sÃ¼tunlar ekleme
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS character_class text,
  ADD COLUMN IF NOT EXISTS luck integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS class_selected_at timestamptz;

-- SÄ±nÄ±f sadece 'warrior', 'alchemist', 'shadow' olabilir
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'users_character_class_check'
  ) THEN
    ALTER TABLE public.users ADD CONSTRAINT users_character_class_check CHECK (character_class IN ('warrior', 'alchemist', 'shadow'));
  END IF;
END $$;

ALTER TABLE public.items
  ADD COLUMN IF NOT EXISTS luck integer NOT NULL DEFAULT 0;

-- 2. character_classes referans tablosu
CREATE TABLE IF NOT EXISTS public.character_classes (
  id text PRIMARY KEY,
  name_tr text NOT NULL,
  name_en text NOT NULL,
  description_tr text,
  
  -- Baz statlar (Level 1)
  base_attack integer NOT NULL DEFAULT 10,
  base_defense integer NOT NULL DEFAULT 10,
  base_health integer NOT NULL DEFAULT 100,
  base_luck integer NOT NULL DEFAULT 0,
  
  -- Level baÅŸÄ±na bÃ¼yÃ¼me
  attack_per_level integer NOT NULL DEFAULT 2,
  defense_per_level integer NOT NULL DEFAULT 2,
  health_per_level integer NOT NULL DEFAULT 15,
  luck_per_level integer NOT NULL DEFAULT 1,
  
  -- Pasif bonus multiplier'larÄ± (JSONB)
  passive_bonuses jsonb NOT NULL DEFAULT '{}',
  
  -- GÃ¶rsel
  icon_url text,
  color_hex text,
  
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Seed data
INSERT INTO public.character_classes (
  id, name_tr, name_en, description_tr,
  base_attack, base_defense, base_health, base_luck,
  attack_per_level, defense_per_level, health_per_level, luck_per_level,
  passive_bonuses, icon_url, color_hex
) VALUES
  (
    'warrior', 'SavaÅŸÃ§Ä±', 'Warrior',
    'YeraltÄ± dÃ¼nyasÄ±nÄ±n sert dÃ¶vÃ¼ÅŸÃ§Ã¼sÃ¼. PvP ve boss uzmanÄ±.',
    18, 12, 120, 5,
    3, 2, 15, 1,
    '{
      "pvp_damage_bonus": 0.20,
      "boss_damage_bonus": 0.15,
      "pvp_crit_bonus": 0.10,
      "dungeon_success_bonus": 0.05,
      "hospital_duration_reduction": 0.20
    }',
    NULL, '#E53935'
  ),
  (
    'alchemist', 'SimyacÄ±', 'Alchemist',
    'Ä°ksirlerin ve formÃ¼llerin efendisi. Crafting odaklÄ±.',
    10, 12, 140, 12,
    1, 2, 20, 2,
    '{
      "potion_effectiveness_bonus": 0.30,
      "tolerance_increase_reduction": 0.25,
      "overdose_chance_reduction": 0.20,
      "crafting_success_bonus": 0.15,
      "han_craft_time_reduction": 0.20,
      "detox_effectiveness_bonus": 0.25
    }',
    NULL, '#7B1FA2'
  ),
  (
    'shadow', 'GÃ¶lge', 'Shadow',
    'ÅÃ¼phe altÄ±nda faaliyet gÃ¶steren gizli operatÃ¶r.',
    12, 10, 110, 18,
    2, 1, 12, 3,
    '{
      "facility_suspicion_reduction": 0.30,
      "bribe_cost_reduction": 0.25,
      "prison_escape_bonus": 0.20,
      "loot_luck_bonus": 0.40,
      "pvp_dodge_bonus": 0.15,
      "black_market_risk_reduction": 0.20
    }',
    NULL, '#212121'
  )
ON CONFLICT (id) DO UPDATE SET
  passive_bonuses = EXCLUDED.passive_bonuses,
  name_tr = EXCLUDED.name_tr,
  name_en = EXCLUDED.name_en,
  description_tr = EXCLUDED.description_tr,
  base_attack = EXCLUDED.base_attack,
  base_defense = EXCLUDED.base_defense,
  base_health = EXCLUDED.base_health,
  base_luck = EXCLUDED.base_luck,
  attack_per_level = EXCLUDED.attack_per_level,
  defense_per_level = EXCLUDED.defense_per_level,
  health_per_level = EXCLUDED.health_per_level,
  luck_per_level = EXCLUDED.luck_per_level;

-- 3. Karakter SeÃ§im RPC
CREATE OR REPLACE FUNCTION public.select_character_class(
  p_class_id text
)
RETURNS jsonb AS $$
DECLARE
  v_user_id uuid;
  v_user record;
  v_class record;
  v_grace_minutes integer := 30;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- SÄ±nÄ±f geÃ§erliliÄŸini kontrol et
  SELECT * INTO v_class FROM public.character_classes WHERE id = p_class_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'GeÃ§ersiz sÄ±nÄ±f: ' || p_class_id);
  END IF;

  -- Mevcut kullanÄ±cÄ± bilgisini al
  SELECT * INTO v_user FROM public.users WHERE auth_id = v_user_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'KullanÄ±cÄ± bulunamadÄ±');
  END IF;

  -- SÄ±nÄ±f zaten seÃ§ilmiÅŸ mi ve grace period geÃ§ti mi?
  IF v_user.character_class IS NOT NULL
     AND v_user.class_selected_at IS NOT NULL
     AND v_user.class_selected_at < (now() - (v_grace_minutes || ' minutes')::interval) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'SÄ±nÄ±f deÄŸiÅŸtirilemez. Grace period (' || v_grace_minutes || ' dk) dolmuÅŸ.',
      'selected_class', v_user.character_class,
      'selected_at', v_user.class_selected_at
    );
  END IF;

  -- KullanÄ±cÄ±yÄ± gÃ¼ncelle: sÄ±nÄ±f statlarÄ±nÄ± uygula
  UPDATE public.users SET
    character_class     = p_class_id,
    class_selected_at   = COALESCE(class_selected_at, now()),
    attack              = v_class.base_attack + (v_class.attack_per_level * (COALESCE(v_user.level, 1) - 1)),
    defense             = v_class.base_defense + (v_class.defense_per_level * (COALESCE(v_user.level, 1) - 1)),
    health              = v_class.base_health + (v_class.health_per_level * (COALESCE(v_user.level, 1) - 1)),
    max_health          = v_class.base_health + (v_class.health_per_level * (COALESCE(v_user.level, 1) - 1)),
    luck                = v_class.base_luck + (v_class.luck_per_level * (COALESCE(v_user.level, 1) - 1))
  WHERE auth_id = v_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'class_id', p_class_id,
    'class_name', v_class.name_tr,
    'stats', jsonb_build_object(
      'attack', v_class.base_attack,
      'defense', v_class.base_defense,
      'health', v_class.base_health,
      'luck', v_class.base_luck
    ),
    'passive_bonuses', v_class.passive_bonuses
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.select_character_class(text) TO authenticated;

-- 4. Karakter SÄ±nÄ±flarÄ± Sorgulama RPC
CREATE OR REPLACE FUNCTION public.get_character_classes()
RETURNS jsonb AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object(
      'success', true,
      'classes', COALESCE(jsonb_agg(
        jsonb_build_object(
          'id', id,
          'name_tr', name_tr,
          'name_en', name_en,
          'description_tr', description_tr,
          'base_stats', jsonb_build_object(
            'attack', base_attack,
            'defense', base_defense,
            'health', base_health,
            'luck', base_luck
          ),
          'growth', jsonb_build_object(
            'attack_per_level', attack_per_level,
            'defense_per_level', defense_per_level,
            'health_per_level', health_per_level,
            'luck_per_level', luck_per_level
          ),
          'passive_bonuses', passive_bonuses,
          'color_hex', color_hex,
          'icon_url', icon_url
        )
        ORDER BY id
      ), '[]'::jsonb)
    )
    FROM public.character_classes
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_character_classes() TO anon, authenticated;

-- 5. Level Atlama Stat GÃ¼ncelleme
CREATE OR REPLACE FUNCTION public.apply_level_up_stats(
  p_user_id uuid,
  p_new_level integer
) RETURNS void AS $$
DECLARE
  v_user record;
  v_class record;
  v_levels_gained integer;
BEGIN
  -- KullanÄ±cÄ±yÄ± al
  SELECT * INTO v_user FROM public.users WHERE auth_id = p_user_id;
  IF NOT FOUND OR v_user.character_class IS NULL THEN
    RETURN; -- SÄ±nÄ±f seÃ§ilmemiÅŸse gÃ¼ncelleme yapma
  END IF;

  -- SÄ±nÄ±f bÃ¼yÃ¼me verilerini al
  SELECT * INTO v_class FROM public.character_classes WHERE id = v_user.character_class;
  IF NOT FOUND THEN
    RETURN;
  END IF;

  v_levels_gained := p_new_level - v_user.level; 
  IF v_levels_gained <= 0 THEN
    RETURN;
  END IF;

  UPDATE public.users SET
    attack     = attack     + (v_class.attack_per_level  * v_levels_gained),
    defense    = defense    + (v_class.defense_per_level * v_levels_gained),
    max_health = max_health + (v_class.health_per_level  * v_levels_gained),
    health     = health     + (v_class.health_per_level  * v_levels_gained),
    luck       = luck       + (v_class.luck_per_level    * v_levels_gained),
    level      = p_new_level
  WHERE auth_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Herkese aÃ§Ä±k eriÅŸimi kapat ve sadece yetkili (Ã¶rn. service_role) Ã§aÄŸÄ±rabilsin
REVOKE EXECUTE ON FUNCTION public.apply_level_up_stats(uuid, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.apply_level_up_stats(uuid, integer) TO service_role;

-- 6. get_current_user RPC
CREATE OR REPLACE FUNCTION public.get_current_user()
RETURNS jsonb AS $$
DECLARE
  v_user_id uuid;
  v_user record;
  v_class record;
  v_result jsonb;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT * INTO v_user FROM public.users WHERE auth_id = v_user_id;
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  -- BaÅŸlangÄ±Ã§ objesi
  v_result := to_jsonb(v_user);

  -- Pasif bonuslarÄ± ekle (sÄ±nÄ±f varsa)
  IF v_user.character_class IS NOT NULL THEN
    SELECT * INTO v_class FROM public.character_classes WHERE id = v_user.character_class;
    IF FOUND THEN
      v_result := v_result || jsonb_build_object(
        'class_passive_bonuses', v_class.passive_bonuses
      );
    END IF;
  END IF;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_current_user() TO authenticated;
