-- ============================================================
-- Shop Items — shop_items tablosu ve get_shop_items RPC
-- Kaynak: ShopScreen.gd ItemCard setup
-- ============================================================

CREATE TABLE IF NOT EXISTS public.shop_items (
  id          text        PRIMARY KEY,
  name        text        NOT NULL,
  icon        text        NOT NULL,
  price       integer     NOT NULL CHECK (price >= 0),
  currency    text        NOT NULL CHECK (currency IN ('gold', 'gems')),
  description text        NOT NULL DEFAULT '',
  rarity      text        NOT NULL DEFAULT 'common' CHECK (rarity IN ('common', 'uncommon', 'rare', 'epic', 'legendary', 'mythic')),
  max_stack   integer     NOT NULL DEFAULT 99,
  is_active   boolean     NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.shop_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read active shop items"
  ON public.shop_items
  FOR SELECT
  USING (is_active = true);

INSERT INTO public.shop_items (id, name, icon, price, currency, description, rarity, max_stack) VALUES
  ('si1', 'Sağlık İksiri',    '🧪', 100,  'gold', '50 HP yeniler',              'common',    99),
  ('si2', 'Mana İksiri',      '💧', 150,  'gold', '30 MP yeniler',              'common',    99),
  ('si3', 'Güç Scrollu',      '📜', 500,  'gold', '+10% saldırı (5dk)',         'uncommon',  10),
  ('si4', 'Koruma Scrollu',   '🛡️', 500,  'gold', '+10% savunma (5dk)',         'uncommon',  10),
  ('si5', 'Enerji İksiri',    '⚡',  50,  'gems', '20 enerji yeniler',          'rare',      99),
  ('si6', 'Deneyim Kitabı',   '📖', 200,  'gems', '5,000 XP verir',             'rare',      10),
  ('si7', 'Nadir Sandık',     '🎁', 300,  'gems', 'Nadir+ eşya garantili',      'epic',       5),
  ('si8', 'Efsanevi Sandık',  '✨', 800,  'gems', 'Efsanevi eşya şansı!',       'legendary',  3)
ON CONFLICT (id) DO NOTHING;

-- get_shop_items: aktif eşyaları döndür
CREATE OR REPLACE FUNCTION public.get_shop_items()
RETURNS TABLE (
  id          text,
  name        text,
  icon        text,
  price       integer,
  currency    text,
  description text,
  rarity      text,
  max_stack   integer
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT id, name, icon, price, currency, description, rarity, max_stack
  FROM   public.shop_items
  WHERE  is_active = true
  ORDER BY
    CASE currency WHEN 'gold' THEN 0 ELSE 1 END,
    price;
$$;

GRANT EXECUTE ON FUNCTION public.get_shop_items() TO anon, authenticated;
