BEGIN;

-- Scroll'lar (PLAN_05 - Enhancement)
INSERT INTO public.items (id, name, name_tr, description, item_type, rarity, is_stackable, max_stack)
VALUES
  ('scroll_upgrade_low', 'Liber Ascensionis Minor', 'Küçük Yükseltim Scroll\'u', 'Common-Uncommon itemler için enhancement', 'scroll', 'uncommon', true, 999),
  ('scroll_upgrade_middle', 'Liber Ascensionis Medius', 'Orta Yükseltim Scroll\'u', 'Rare-Epic itemler için enhancement', 'scroll', 'rare', true, 999),
  ('scroll_upgrade_high', 'Liber Ascensionis Major', 'Büyük Yükseltim Scroll\'u', 'Legendary-Mythic itemler için enhancement', 'scroll', 'legendary', true, 999),

  -- Rune'lar (PLAN_05 - Enhancement)
  ('rune_basic', 'Basic Rune', 'Temel Rune', '+5% enhancement başarı', 'rune', 'uncommon', false, 1),
  ('rune_advanced', 'Advanced Rune', 'Gelişmiş Rune', '+10% enhancement başarı', 'rune', 'rare', false, 1),
  ('rune_superior', 'Superior Rune', 'Üstün Rune', '+15% başarı, %50 yıkım azalma', 'rune', 'epic', false, 1),
  ('rune_legendary', 'Legendary Rune', 'Efsanevi Rune', '+25% başarı, %75 yıkım azalma', 'rune', 'legendary', false, 1),
  ('rune_protection', 'Protection Rune', 'Koruma Rune', '%100 yıkım koruması', 'rune', 'legendary', false, 1),
  ('rune_blessed', 'Blessed Rune', 'Kutsal Rune', '+20% başarı, seviye düşüş koruması', 'rune', 'mythic', false, 1),

  -- Detox içecekleri (PLAN_08 - Tolerans)
  ('detox_minor', 'Minor Detox Drink', 'Küçük Arındırma İçeceği', 'Toleransı -15 azaltır', 'potion', 'uncommon', true, 999),
  ('detox_major', 'Major Detox Drink', 'Büyük Arındırma İçeceği', 'Toleransı -35 azaltır, bağımlılık -1', 'potion', 'rare', true, 999),
  ('detox_supreme', 'Supreme Detox Drink', 'Yüce Arındırma İçeceği', 'Toleransı -60 azaltır, bağımlılık -2', 'potion', 'epic', true, 999),
  ('detox_elixir', 'Full Cleanse Elixir', 'Tam Temizlenme İksiri', 'Tolerans ve bağımlılık tamamen sıfırlanır', 'potion', 'legendary', true, 999)
ON CONFLICT (id) DO NOTHING;

COMMIT;
