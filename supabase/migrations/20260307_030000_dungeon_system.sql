
-- =========================================================================================
-- MIGRATION: PLAN_04_DUNGEON_SYSTEM
-- =========================================================================================

-- 1. Create Dungeons Catalog Table
CREATE TABLE IF NOT EXISTS public.dungeons (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  name_tr TEXT NOT NULL,
  description TEXT DEFAULT '',
  zone INTEGER NOT NULL,
  zone_name TEXT NOT NULL,
  dungeon_order INTEGER NOT NULL,
  
  -- Difficulty
  power_requirement INTEGER DEFAULT 0,
  energy_cost INTEGER DEFAULT 5,
  is_boss BOOLEAN DEFAULT false,
  daily_boss_limit INTEGER DEFAULT 3,
  
  -- Rewards
  gold_min INTEGER DEFAULT 0,
  gold_max INTEGER DEFAULT 0,
  xp_reward INTEGER DEFAULT 0,
  
  -- Risk
  hospital_chance NUMERIC DEFAULT 0.0,
  hospital_min_minutes INTEGER DEFAULT 0,
  hospital_max_minutes INTEGER DEFAULT 0,
  
  -- Loot
  equipment_drop_chance NUMERIC DEFAULT 0.15,
  resource_drop_chance NUMERIC DEFAULT 0.40,
  catalyst_drop_chance NUMERIC DEFAULT 0.05,
  scroll_drop_chance NUMERIC DEFAULT 0.02,
  loot_rarity_weights JSONB DEFAULT '{}'::jsonb,
  
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_dungeons_zone ON public.dungeons(zone);
CREATE INDEX IF NOT EXISTS idx_dungeons_order ON public.dungeons(dungeon_order);

-- 2. Seed 65 Dungeons
INSERT INTO public.dungeons (
  id, name, name_tr, zone, zone_name, dungeon_order, power_requirement, energy_cost, 
  gold_min, gold_max, xp_reward, is_boss, hospital_min_minutes, hospital_max_minutes,
  equipment_drop_chance, resource_drop_chance, catalyst_drop_chance, scroll_drop_chance, loot_rarity_weights
) VALUES
  ('dng_001', 'Luporum Cubile', 'Kurt İni', 1, 'Silva Obscura', 1, 0, 5, 5000, 12000, 30, false, 15, 45, 0.15, 0.40, 0.05, 0.02, '{"common": 0.80, "uncommon": 0.18, "rare": 0.02}'),
  ('dng_002', 'Aranearum Nidus', 'Örümcek Yuvası', 1, 'Silva Obscura', 2, 1500, 5, 6000, 14000, 40, false, 15, 45, 0.15, 0.40, 0.05, 0.02, '{"common": 0.80, "uncommon": 0.18, "rare": 0.02}'),
  ('dng_003', 'Goblinorum Castra', 'Goblin Kampı', 1, 'Silva Obscura', 3, 2500, 5, 7000, 16000, 50, false, 15, 45, 0.15, 0.40, 0.05, 0.02, '{"common": 0.80, "uncommon": 0.18, "rare": 0.02}'),
  ('dng_004', 'Fungorum Caverna', 'Mantar Mağarası', 1, 'Silva Obscura', 4, 3500, 6, 8000, 18000, 60, false, 15, 45, 0.15, 0.40, 0.05, 0.02, '{"common": 0.80, "uncommon": 0.18, "rare": 0.02}'),
  ('dng_005', 'Silvani Templum', 'Orman Tapınağı', 1, 'Silva Obscura', 5, 4500, 6, 9000, 20000, 75, false, 15, 45, 0.15, 0.40, 0.05, 0.02, '{"common": 0.80, "uncommon": 0.18, "rare": 0.02}'),
  ('dng_006', 'Veneficae Domus', 'Cadı Kulübesi', 1, 'Silva Obscura', 6, 5500, 6, 10000, 23000, 90, false, 15, 45, 0.15, 0.40, 0.05, 0.02, '{"common": 0.80, "uncommon": 0.18, "rare": 0.02}'),
  ('dng_007', 'Mortuorum Silva', 'Ölü Orman', 1, 'Silva Obscura', 7, 6500, 7, 11000, 26000, 105, false, 15, 45, 0.15, 0.40, 0.05, 0.02, '{"common": 0.80, "uncommon": 0.18, "rare": 0.02}'),
  ('dng_008', 'Lupus Rex Tana', 'Kurt Kralın İni', 1, 'Silva Obscura', 8, 7500, 7, 13000, 30000, 120, false, 15, 45, 0.15, 0.40, 0.05, 0.02, '{"common": 0.80, "uncommon": 0.18, "rare": 0.02}'),
  ('dng_009', 'Arbor Antiqua', 'Kadim Ağaç', 1, 'Silva Obscura', 9, 8500, 7, 15000, 34000, 140, false, 15, 45, 0.15, 0.40, 0.05, 0.02, '{"common": 0.80, "uncommon": 0.18, "rare": 0.02}'),
  ('dng_010', 'Silva Maledictus', 'Lanetli Orman Kalbi', 1, 'Silva Obscura', 10, 10000, 8, 18000, 40000, 160, true, 15, 45, 0.15, 0.40, 0.05, 0.02, '{"common": 0.80, "uncommon": 0.18, "rare": 0.02}'),

  ('dng_011', 'Fodina Deserta', 'Terk Edilmiş Maden', 2, 'Caverna Profunda', 11, 12000, 8, 20000, 45000, 180, false, 30, 90, 0.18, 0.45, 0.07, 0.03, '{"common": 0.50, "uncommon": 0.35, "rare": 0.13, "epic": 0.02}'),
  ('dng_012', 'Crystallorum Camera', 'Kristal Odası', 2, 'Caverna Profunda', 12, 14500, 8, 22000, 50000, 200, false, 30, 90, 0.18, 0.45, 0.07, 0.03, '{"common": 0.50, "uncommon": 0.35, "rare": 0.13, "epic": 0.02}'),
  ('dng_013', 'Vermium Tunnelus', 'Solucan Tüneli', 2, 'Caverna Profunda', 13, 17000, 9, 25000, 56000, 225, false, 30, 90, 0.18, 0.45, 0.07, 0.03, '{"common": 0.50, "uncommon": 0.35, "rare": 0.13, "epic": 0.02}'),
  ('dng_014', 'Subterraneum Lacus', 'Yeraltı Gölü', 2, 'Caverna Profunda', 14, 19500, 9, 28000, 62000, 250, false, 30, 90, 0.18, 0.45, 0.07, 0.03, '{"common": 0.50, "uncommon": 0.35, "rare": 0.13, "epic": 0.02}'),
  ('dng_015', 'Pipistrellorum Caverna', 'Yarasa Mağarası', 2, 'Caverna Profunda', 15, 22000, 9, 31000, 68000, 280, false, 30, 90, 0.18, 0.45, 0.07, 0.03, '{"common": 0.50, "uncommon": 0.35, "rare": 0.13, "epic": 0.02}'),
  ('dng_016', 'Trogloditarum Oppidum', 'Troglodyt Şehri', 2, 'Caverna Profunda', 16, 25000, 10, 35000, 75000, 310, false, 30, 90, 0.18, 0.45, 0.07, 0.03, '{"common": 0.50, "uncommon": 0.35, "rare": 0.13, "epic": 0.02}'),
  ('dng_017', 'Aquae Subterraneae', 'Yeraltı Nehri', 2, 'Caverna Profunda', 17, 28000, 10, 39000, 83000, 340, false, 30, 90, 0.18, 0.45, 0.07, 0.03, '{"common": 0.50, "uncommon": 0.35, "rare": 0.13, "epic": 0.02}'),
  ('dng_018', 'Fungorum Regnum', 'Mantar Krallığı', 2, 'Caverna Profunda', 18, 31000, 10, 43000, 92000, 380, false, 30, 90, 0.18, 0.45, 0.07, 0.03, '{"common": 0.50, "uncommon": 0.35, "rare": 0.13, "epic": 0.02}'),
  ('dng_019', 'Dracunculus Nidus', 'Genç Ejder Yuvası', 2, 'Caverna Profunda', 19, 35000, 11, 48000, 102000, 420, false, 30, 90, 0.18, 0.45, 0.07, 0.03, '{"common": 0.50, "uncommon": 0.35, "rare": 0.13, "epic": 0.02}'),
  ('dng_020', 'Abyssi Ostium', 'Uçurumun Kapısı', 2, 'Caverna Profunda', 20, 40000, 12, 55000, 115000, 470, true, 30, 90, 0.18, 0.45, 0.07, 0.03, '{"common": 0.50, "uncommon": 0.35, "rare": 0.13, "epic": 0.02}'),

  ('dng_021', 'Scorpionis Vallis', 'Akrep Vadisi', 3, 'Desertum Ignis', 21, 44000, 12, 60000, 130000, 520, false, 45, 150, 0.20, 0.50, 0.10, 0.05, '{"common": 0.20, "uncommon": 0.40, "rare": 0.30, "epic": 0.09, "legendary": 0.01}'),
  ('dng_022', 'Oasis Venenata', 'Zehirli Vaha', 3, 'Desertum Ignis', 22, 50000, 12, 66000, 143000, 570, false, 45, 150, 0.20, 0.50, 0.10, 0.05, '{"common": 0.20, "uncommon": 0.40, "rare": 0.30, "epic": 0.09, "legendary": 0.01}'),
  ('dng_023', 'Pyramidis Ruinae', 'Piramit Harabeleri', 3, 'Desertum Ignis', 23, 56000, 13, 73000, 158000, 630, false, 45, 150, 0.20, 0.50, 0.10, 0.05, '{"common": 0.20, "uncommon": 0.40, "rare": 0.30, "epic": 0.09, "legendary": 0.01}'),
  ('dng_024', 'Sphingis Aenigma', 'Sfenks Bilmecesi', 3, 'Desertum Ignis', 24, 62000, 13, 80000, 173000, 690, false, 45, 150, 0.20, 0.50, 0.10, 0.05, '{"common": 0.20, "uncommon": 0.40, "rare": 0.30, "epic": 0.09, "legendary": 0.01}'),
  ('dng_025', 'Tempestas Arenae', 'Kum Fırtınası Tapınağı', 3, 'Desertum Ignis', 25, 68000, 14, 88000, 190000, 760, false, 45, 150, 0.20, 0.50, 0.10, 0.05, '{"common": 0.20, "uncommon": 0.40, "rare": 0.30, "epic": 0.09, "legendary": 0.01}'),
  ('dng_026', 'Mummiarum Crypta', 'Mumya Mezarı', 3, 'Desertum Ignis', 26, 74000, 14, 97000, 210000, 830, false, 45, 150, 0.20, 0.50, 0.10, 0.05, '{"common": 0.20, "uncommon": 0.40, "rare": 0.30, "epic": 0.09, "legendary": 0.01}'),
  ('dng_027', 'Solis Templum', 'Güneş Tapınağı', 3, 'Desertum Ignis', 27, 80000, 15, 107000, 231000, 910, false, 45, 150, 0.20, 0.50, 0.10, 0.05, '{"common": 0.20, "uncommon": 0.40, "rare": 0.30, "epic": 0.09, "legendary": 0.01}'),
  ('dng_028', 'Djinn Palatium', 'Cin Sarayı', 3, 'Desertum Ignis', 28, 86000, 15, 118000, 255000, 1000, false, 45, 150, 0.20, 0.50, 0.10, 0.05, '{"common": 0.20, "uncommon": 0.40, "rare": 0.30, "epic": 0.09, "legendary": 0.01}'),
  ('dng_029', 'Pharaonis Maledictio', 'Firavunun Laneti', 3, 'Desertum Ignis', 29, 93000, 16, 130000, 281000, 1100, false, 45, 150, 0.20, 0.50, 0.10, 0.05, '{"common": 0.20, "uncommon": 0.40, "rare": 0.30, "epic": 0.09, "legendary": 0.01}'),
  ('dng_030', 'Ignis Cor', 'Çölün Ateş Kalbi', 3, 'Desertum Ignis', 30, 100000, 18, 145000, 310000, 1200, true, 45, 150, 0.20, 0.50, 0.10, 0.05, '{"common": 0.20, "uncommon": 0.40, "rare": 0.30, "epic": 0.09, "legendary": 0.01}'),

  ('dng_031', 'Caprarum Via', 'Keçi Yolu Geçidi', 4, 'Mons Tempestatis', 31, 110000, 18, 160000, 340000, 1320, false, 60, 240, 0.22, 0.50, 0.12, 0.06, '{"common": 0.05, "uncommon": 0.20, "rare": 0.40, "epic": 0.28, "legendary": 0.06, "mythic": 0.01}'),
  ('dng_032', 'Aquilae Nidus', 'Kartal Yuvası', 4, 'Mons Tempestatis', 32, 122000, 18, 177000, 375000, 1450, false, 60, 240, 0.22, 0.50, 0.12, 0.06, '{"common": 0.05, "uncommon": 0.20, "rare": 0.40, "epic": 0.28, "legendary": 0.06, "mythic": 0.01}'),
  ('dng_033', 'Gigantum Rupes', 'Dev Kayalıkları', 4, 'Mons Tempestatis', 33, 134000, 19, 195000, 413000, 1590, false, 60, 240, 0.22, 0.50, 0.12, 0.06, '{"common": 0.05, "uncommon": 0.20, "rare": 0.40, "epic": 0.28, "legendary": 0.06, "mythic": 0.01}'),
  ('dng_034', 'Glaciei Caverna', 'Buz Mağarası', 4, 'Mons Tempestatis', 34, 146000, 19, 215000, 454000, 1750, false, 60, 240, 0.22, 0.50, 0.12, 0.06, '{"common": 0.05, "uncommon": 0.20, "rare": 0.40, "epic": 0.28, "legendary": 0.06, "mythic": 0.01}'),
  ('dng_035', 'Fulminis Turris', 'Yıldırım Kulesi', 4, 'Mons Tempestatis', 35, 158000, 20, 237000, 500000, 1920, false, 60, 240, 0.22, 0.50, 0.12, 0.06, '{"common": 0.05, "uncommon": 0.20, "rare": 0.40, "epic": 0.28, "legendary": 0.06, "mythic": 0.01}'),
  ('dng_036', 'Nanorum Fodina', 'Cüce Madeni', 4, 'Mons Tempestatis', 36, 170000, 20, 261000, 550000, 2110, false, 60, 240, 0.22, 0.50, 0.12, 0.06, '{"common": 0.05, "uncommon": 0.20, "rare": 0.40, "epic": 0.28, "legendary": 0.06, "mythic": 0.01}'),
  ('dng_037', 'Draconis Scopulus', 'Ejder Kayalığı', 4, 'Mons Tempestatis', 37, 182000, 22, 288000, 606000, 2320, false, 60, 240, 0.22, 0.50, 0.12, 0.06, '{"common": 0.05, "uncommon": 0.20, "rare": 0.40, "epic": 0.28, "legendary": 0.06, "mythic": 0.01}'),
  ('dng_038', 'Ventorum Templum', 'Rüzgar Tapınağı', 4, 'Mons Tempestatis', 38, 194000, 22, 317000, 667000, 2550, false, 60, 240, 0.22, 0.50, 0.12, 0.06, '{"common": 0.05, "uncommon": 0.20, "rare": 0.40, "epic": 0.28, "legendary": 0.06, "mythic": 0.01}'),
  ('dng_039', 'Titanis Ossa', 'Titanın Kemikleri', 4, 'Mons Tempestatis', 39, 207000, 24, 350000, 734000, 2800, false, 60, 240, 0.22, 0.50, 0.12, 0.06, '{"common": 0.05, "uncommon": 0.20, "rare": 0.40, "epic": 0.28, "legendary": 0.06, "mythic": 0.01}'),
  ('dng_040', 'Caelum Vertex', 'Gökyüzü Zirvesi', 4, 'Mons Tempestatis', 40, 220000, 25, 385000, 808000, 3080, true, 60, 240, 0.22, 0.50, 0.12, 0.06, '{"common": 0.05, "uncommon": 0.20, "rare": 0.40, "epic": 0.28, "legendary": 0.06, "mythic": 0.01}'),

  ('dng_041', 'Lavae Flumen', 'Lav Nehri', 5, 'Infernum Subterra', 41, 230000, 25, 425000, 890000, 3380, false, 90, 360, 0.25, 0.55, 0.15, 0.08, '{"uncommon": 0.05, "rare": 0.25, "epic": 0.40, "legendary": 0.25, "mythic": 0.05}'),
  ('dng_042', 'Daemonum Porta', 'Şeytan Kapısı', 5, 'Infernum Subterra', 42, 242000, 26, 470000, 980000, 3720, false, 90, 360, 0.25, 0.55, 0.15, 0.08, '{"uncommon": 0.05, "rare": 0.25, "epic": 0.40, "legendary": 0.25, "mythic": 0.05}'),
  ('dng_043', 'Ossium Palatium', 'Kemik Sarayı', 5, 'Infernum Subterra', 43, 254000, 26, 520000, 1080000, 4090, false, 90, 360, 0.25, 0.55, 0.15, 0.08, '{"uncommon": 0.05, "rare": 0.25, "epic": 0.40, "legendary": 0.25, "mythic": 0.05}'),
  ('dng_044', 'Animarum Carcer', 'Ruh Hapishanesi', 5, 'Infernum Subterra', 44, 268000, 28, 570000, 1190000, 4500, false, 90, 360, 0.25, 0.55, 0.15, 0.08, '{"uncommon": 0.05, "rare": 0.25, "epic": 0.40, "legendary": 0.25, "mythic": 0.05}'),
  ('dng_045', 'Necromantis Lab', 'Ölü Büyücünün Lab.', 5, 'Infernum Subterra', 45, 282000, 28, 630000, 1310000, 4950, false, 90, 360, 0.25, 0.55, 0.15, 0.08, '{"uncommon": 0.05, "rare": 0.25, "epic": 0.40, "legendary": 0.25, "mythic": 0.05}'),
  ('dng_046', 'Sanguinis Fons', 'Kan Çeşmesi', 5, 'Infernum Subterra', 46, 296000, 30, 695000, 1440000, 5440, false, 90, 360, 0.25, 0.55, 0.15, 0.08, '{"uncommon": 0.05, "rare": 0.25, "epic": 0.40, "legendary": 0.25, "mythic": 0.05}'),
  ('dng_047', 'Umbrae Labyrinthus', 'Gölge Labirenti', 5, 'Infernum Subterra', 47, 310000, 30, 766000, 1590000, 5990, false, 90, 360, 0.25, 0.55, 0.15, 0.08, '{"uncommon": 0.05, "rare": 0.25, "epic": 0.40, "legendary": 0.25, "mythic": 0.05}'),
  ('dng_048', 'Mortis Thronus', 'Ölüm Tahtı', 5, 'Infernum Subterra', 48, 320000, 32, 845000, 1750000, 6580, false, 90, 360, 0.25, 0.55, 0.15, 0.08, '{"uncommon": 0.05, "rare": 0.25, "epic": 0.40, "legendary": 0.25, "mythic": 0.05}'),
  ('dng_049', 'Inferni Cor', 'Cehennem Kalbi', 5, 'Infernum Subterra', 49, 330000, 32, 932000, 1925000, 7240, false, 90, 360, 0.25, 0.55, 0.15, 0.08, '{"uncommon": 0.05, "rare": 0.25, "epic": 0.40, "legendary": 0.25, "mythic": 0.05}'),
  ('dng_050', 'Abyssi Rex', 'Uçurum Kralı', 5, 'Infernum Subterra', 50, 340000, 35, 1030000, 2120000, 7960, true, 90, 360, 0.25, 0.55, 0.15, 0.08, '{"uncommon": 0.05, "rare": 0.25, "epic": 0.40, "legendary": 0.25, "mythic": 0.05}'),

  ('dng_051', 'Nubium Insula', 'Bulut Adası', 6, 'Caelum Fractum', 51, 350000, 35, 1140000, 2330000, 8760, false, 120, 480, 0.28, 0.55, 0.18, 0.10, '{"rare": 0.10, "epic": 0.35, "legendary": 0.40, "mythic": 0.15}'),
  ('dng_052', 'Angelorum Ruinae', 'Melek Harabeleri', 6, 'Caelum Fractum', 52, 358000, 36, 1250000, 2560000, 9630, false, 120, 480, 0.28, 0.55, 0.18, 0.10, '{"rare": 0.10, "epic": 0.35, "legendary": 0.40, "mythic": 0.15}'),
  ('dng_053', 'Stellarum Via', 'Yıldız Yolu', 6, 'Caelum Fractum', 53, 366000, 36, 1380000, 2820000, 10590, false, 120, 480, 0.28, 0.55, 0.18, 0.10, '{"rare": 0.10, "epic": 0.35, "legendary": 0.40, "mythic": 0.15}'),
  ('dng_054', 'Lunae Palatium', 'Ay Sarayı', 6, 'Caelum Fractum', 54, 374000, 38, 1520000, 3100000, 11650, false, 120, 480, 0.28, 0.55, 0.18, 0.10, '{"rare": 0.10, "epic": 0.35, "legendary": 0.40, "mythic": 0.15}'),
  ('dng_055', 'Solis Forgia', 'Güneş Dökümhanesi', 6, 'Caelum Fractum', 55, 382000, 38, 1680000, 3410000, 12810, false, 120, 480, 0.28, 0.55, 0.18, 0.10, '{"rare": 0.10, "epic": 0.35, "legendary": 0.40, "mythic": 0.15}'),
  ('dng_056', 'Temporis Fissura', 'Zaman Yarığı', 6, 'Caelum Fractum', 56, 390000, 40, 1850000, 3750000, 14100, false, 120, 480, 0.28, 0.55, 0.18, 0.10, '{"rare": 0.10, "epic": 0.35, "legendary": 0.40, "mythic": 0.15}'),
  ('dng_057', 'Dimensionis Nexus', 'Boyut Kavşağı', 6, 'Caelum Fractum', 57, 398000, 40, 2040000, 4130000, 15500, false, 120, 480, 0.28, 0.55, 0.18, 0.10, '{"rare": 0.10, "epic": 0.35, "legendary": 0.40, "mythic": 0.15}'),
  ('dng_058', 'Deorum Atrium', 'Tanrılar Avlusu', 6, 'Caelum Fractum', 58, 406000, 42, 2250000, 4540000, 17050, false, 120, 480, 0.28, 0.55, 0.18, 0.10, '{"rare": 0.10, "epic": 0.35, "legendary": 0.40, "mythic": 0.15}'),
  ('dng_059', 'Fati Thronus', 'Kader Tahtı', 6, 'Caelum Fractum', 59, 414000, 42, 2480000, 5000000, 18750, false, 120, 480, 0.28, 0.55, 0.18, 0.10, '{"rare": 0.10, "epic": 0.35, "legendary": 0.40, "mythic": 0.15}'),
  ('dng_060', 'Omnium Finis', 'Her Şeyin Sonu', 6, 'Caelum Fractum', 60, 420000, 45, 2730000, 5500000, 20650, true, 120, 480, 0.28, 0.55, 0.18, 0.10, '{"rare": 0.10, "epic": 0.35, "legendary": 0.40, "mythic": 0.15}'),

  ('dng_061', 'Chronos Aeternus', 'Sonsuz Zaman', 7, 'Mythica Pericula', 61, 425000, 45, 3000000, 6050000, 22700, true, 180, 720, 0.35, 0.60, 0.25, 0.15, '{"epic": 0.15, "legendary": 0.45, "mythic": 0.40}'),
  ('dng_062', 'Chaos Primordiale', 'İlkel Kaos', 7, 'Mythica Pericula', 62, 432000, 48, 3300000, 6650000, 25000, true, 180, 720, 0.35, 0.60, 0.25, 0.15, '{"epic": 0.15, "legendary": 0.45, "mythic": 0.40}'),
  ('dng_063', 'Nihilum Absolutum', 'Mutlak Hiçlik', 7, 'Mythica Pericula', 63, 438000, 48, 3630000, 7320000, 27500, true, 180, 720, 0.35, 0.60, 0.25, 0.15, '{"epic": 0.15, "legendary": 0.45, "mythic": 0.40}'),
  ('dng_064', 'Creatrix Nexus', 'Yaratıcı Bağlantı', 7, 'Mythica Pericula', 64, 444000, 50, 4000000, 8050000, 30200, true, 180, 720, 0.35, 0.60, 0.25, 0.15, '{"epic": 0.15, "legendary": 0.45, "mythic": 0.40}'),
  ('dng_065', 'Ultimus Provocatio', 'Son Meydan Okuma', 7, 'Mythica Pericula', 65, 450000, 50, 4400000, 8860000, 33200, true, 180, 720, 0.35, 0.60, 0.25, 0.15, '{"epic": 0.15, "legendary": 0.45, "mythic": 0.40}')
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  name_tr = EXCLUDED.name_tr,
  zone = EXCLUDED.zone,
  zone_name = EXCLUDED.zone_name,
  dungeon_order = EXCLUDED.dungeon_order,
  power_requirement = EXCLUDED.power_requirement,
  energy_cost = EXCLUDED.energy_cost,
  gold_min = EXCLUDED.gold_min,
  gold_max = EXCLUDED.gold_max,
  xp_reward = EXCLUDED.xp_reward,
  is_boss = EXCLUDED.is_boss,
  hospital_min_minutes = EXCLUDED.hospital_min_minutes,
  hospital_max_minutes = EXCLUDED.hospital_max_minutes,
  equipment_drop_chance = EXCLUDED.equipment_drop_chance,
  resource_drop_chance = EXCLUDED.resource_drop_chance,
  catalyst_drop_chance = EXCLUDED.catalyst_drop_chance,
  scroll_drop_chance = EXCLUDED.scroll_drop_chance,
  loot_rarity_weights = EXCLUDED.loot_rarity_weights;

-- 3. Create Dungeon Runs Table
CREATE TABLE IF NOT EXISTS public.dungeon_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  dungeon_id TEXT NOT NULL REFERENCES public.dungeons(id),
  
  -- Result
  success BOOLEAN NOT NULL,
  is_critical BOOLEAN DEFAULT false,
  
  -- Rewards earned
  gold_earned INTEGER DEFAULT 0,
  xp_earned INTEGER DEFAULT 0,
  items_dropped JSONB DEFAULT '[]'::jsonb,
  
  -- Hospital
  hospitalized BOOLEAN DEFAULT false,
  hospital_until TIMESTAMPTZ,
  
  -- Stats at time of run
  player_power INTEGER DEFAULT 0,
  success_rate_at_run NUMERIC DEFAULT 0,
  
  -- First clear bonus
  is_first_clear BOOLEAN DEFAULT false,
  
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_dungeon_runs_player ON public.dungeon_runs(player_id);
CREATE INDEX IF NOT EXISTS idx_dungeon_runs_date ON public.dungeon_runs(created_at);

-- 4. Create Player Dungeon Stats Table
CREATE TABLE IF NOT EXISTS public.player_dungeon_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  dungeon_id TEXT NOT NULL REFERENCES public.dungeons(id),
  
  total_attempts INTEGER DEFAULT 0,
  total_successes INTEGER DEFAULT 0,
  total_failures INTEGER DEFAULT 0,
  first_clear_at TIMESTAMPTZ,
  best_power_at_clear INTEGER DEFAULT 0,
  today_attempts INTEGER DEFAULT 0,
  today_boss_attempts INTEGER DEFAULT 0,
  today_date DATE DEFAULT CURRENT_DATE,
  
  UNIQUE(player_id, dungeon_id)
);

CREATE INDEX IF NOT EXISTS idx_player_dungeon_player ON public.player_dungeon_stats(player_id);

-- 5. RLS Policies
ALTER TABLE public.dungeons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dungeon_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.player_dungeon_stats ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Dungeons are viewable by everyone' AND tablename = 'dungeons') THEN
    CREATE POLICY "Dungeons are viewable by everyone" ON public.dungeons FOR SELECT USING (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can view their own dungeon runs' AND tablename = 'dungeon_runs') THEN
    CREATE POLICY "Users can view their own dungeon runs" ON public.dungeon_runs FOR SELECT USING (auth.uid() = player_id);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can view their own dungeon stats' AND tablename = 'player_dungeon_stats') THEN
    CREATE POLICY "Users can view their own dungeon stats" ON public.player_dungeon_stats FOR SELECT USING (auth.uid() = player_id);
  END IF;
END $$;

-- 6. Enter Dungeon RPC
CREATE OR REPLACE FUNCTION public.enter_dungeon(
  p_player_id UUID,
  p_dungeon_id TEXT
) RETURNS JSONB AS $$
DECLARE
  v_dungeon RECORD;
  v_player RECORD;
  v_power INTEGER;
  v_success_rate NUMERIC;
  v_success BOOLEAN;
  v_is_critical BOOLEAN;
  v_gold INTEGER;
  v_xp INTEGER;
  v_hospitalized BOOLEAN := false;
  v_hospital_until TIMESTAMPTZ;
  v_hospital_minutes INTEGER;
  v_is_first BOOLEAN := false;
  v_items JSONB := '[]'::JSONB;
  v_today_attempts INTEGER;
  v_today_boss INTEGER;
  v_luck_for_loot NUMERIC;
  v_ratio NUMERIC;
  v_hospital_chance NUMERIC;
  v_defense_mitigation NUMERIC;
BEGIN
  IF p_player_id != auth.uid() THEN
    RETURN jsonb_build_object('error', 'Yetkisiz işlem');
  END IF;

  -- Get dungeon
  SELECT * INTO v_dungeon FROM public.dungeons WHERE id = p_dungeon_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'dungeon_not_found');
  END IF;
  
  -- Get player (use auth_id)
  SELECT * INTO v_player FROM public.users WHERE auth_id = p_player_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'player_not_found');
  END IF;
  
  -- Hospital check
  IF v_player.hospital_until IS NOT NULL AND v_player.hospital_until > now() THEN
    RETURN jsonb_build_object('error', 'in_hospital');
  END IF;
  
  -- Prison check
  IF v_player.prison_until IS NOT NULL AND v_player.prison_until > now() THEN
    RETURN jsonb_build_object('error', 'in_prison');
  END IF;
  
  -- Energy check
  IF v_player.energy < v_dungeon.energy_cost THEN
    RETURN jsonb_build_object('error', 'insufficient_energy');
  END IF;
  
  -- Get/create daily stats
  INSERT INTO public.player_dungeon_stats (player_id, dungeon_id)
  VALUES (p_player_id, p_dungeon_id)
  ON CONFLICT (player_id, dungeon_id) DO NOTHING;
  
  -- Reset daily counters if new day
  UPDATE public.player_dungeon_stats 
  SET today_attempts = 0, today_boss_attempts = 0, today_date = CURRENT_DATE
  WHERE player_id = p_player_id AND dungeon_id = p_dungeon_id AND today_date < CURRENT_DATE;
  
  SELECT today_boss_attempts INTO v_today_boss
  FROM public.player_dungeon_stats 
  WHERE player_id = p_player_id AND dungeon_id = p_dungeon_id;
  
  -- Boss daily limit check
  IF v_dungeon.is_boss AND v_today_boss >= v_dungeon.daily_boss_limit THEN
    RETURN jsonb_build_object('error', 'boss_daily_limit');
  END IF;
  
  -- Calculate total power
  v_power := COALESCE(v_player.power, 0);
  IF v_power = 0 THEN
    v_power := v_player.level * 500
             + floor(COALESCE(v_player.reputation, 0) * 0.1)
             + floor(COALESCE(v_player.luck, 0) * 50);
  END IF;
  
  -- Calculate success rate
  IF v_dungeon.power_requirement = 0 THEN
    v_success_rate := 1.0;
  ELSE
    v_ratio := v_power::NUMERIC / v_dungeon.power_requirement;
    IF v_ratio >= 1.5 THEN v_success_rate := 0.95;
    ELSIF v_ratio >= 1.0 THEN v_success_rate := 0.70 + (v_ratio - 1.0) * 0.50;
    ELSIF v_ratio >= 0.5 THEN v_success_rate := 0.25 + (v_ratio - 0.5) * 0.90;
    ELSIF v_ratio >= 0.25 THEN v_success_rate := 0.10 + (v_ratio - 0.25) * 0.60;
    ELSE v_success_rate := GREATEST(0.05, v_ratio * 0.40);
    END IF;
  END IF;
  
  -- Apply luck bonus (PLAN_11)
  v_success_rate := v_success_rate + COALESCE(v_player.luck, 0) * 0.001;
  
  -- Apply Warrior class dungeon success bonus (PLAN_11)
  IF COALESCE(v_player.character_class, '') = 'warrior' THEN
    v_success_rate := v_success_rate + 0.05;
  END IF;
  
  v_success_rate := LEAST(0.95, v_success_rate);
  
  -- Roll for success
  v_success := random() <= v_success_rate;
  v_is_critical := v_success AND random() <= 0.10;
  
  -- Calculate rewards
  IF v_success THEN
    v_gold := v_dungeon.gold_min + floor(random() * (v_dungeon.gold_max - v_dungeon.gold_min));
    v_xp := v_dungeon.xp_reward;
    IF v_is_critical THEN
      v_gold := floor(v_gold * 1.5);
      v_xp := floor(v_xp * 1.5);
    END IF;
    
    -- Luck-based loot bonus (PLAN_11)
    v_luck_for_loot := COALESCE(v_player.luck, 0);
    IF COALESCE(v_player.character_class, '') = 'shadow' THEN
      v_luck_for_loot := v_luck_for_loot * 1.40;  -- Gölge: +40% loot luck
    END IF;
    v_gold := floor(v_gold * (1 + v_luck_for_loot * 0.002));
    v_xp   := floor(v_xp   * (1 + COALESCE(v_player.luck, 0) * 0.001));
    
    -- Warrior boss damage modelled as +15% gold reward on boss dungeons
    IF COALESCE(v_player.character_class, '') = 'warrior' AND v_dungeon.is_boss THEN
      v_gold := floor(v_gold * 1.15);
    END IF;
  ELSE
    v_gold := floor(v_dungeon.gold_min * 0.3);
    v_xp := floor(v_dungeon.xp_reward * 0.2);
    
    -- Hospital check on failure
    v_hospital_chance := GREATEST(0.05, LEAST(0.90, 1.0 - v_success_rate));
    v_hospital_chance := v_hospital_chance * (1 - COALESCE(v_player.luck, 0) * 0.003);
    IF random() <= v_hospital_chance THEN
      v_hospitalized := true;
      v_hospital_minutes := v_dungeon.hospital_min_minutes
        + floor(random() * GREATEST(0, v_dungeon.hospital_max_minutes - v_dungeon.hospital_min_minutes));
      
      -- Defense-based mitigation: max 30%
      v_defense_mitigation := LEAST(0.30, COALESCE(v_player.defense, 0) * 0.001);
      v_hospital_minutes := floor(v_hospital_minutes * (1 - v_defense_mitigation));
      
      -- Warrior class: additional -20% hospital duration
      IF COALESCE(v_player.character_class, '') = 'warrior' THEN
        v_hospital_minutes := floor(v_hospital_minutes * 0.80);
      END IF;
      
      v_hospital_until := now() + (v_hospital_minutes || ' minutes')::INTERVAL;
      UPDATE public.users SET hospital_until = v_hospital_until WHERE auth_id = p_player_id;
    END IF;
  END IF;
  
  -- First clear check
  IF v_success THEN
    SELECT (first_clear_at IS NULL) INTO v_is_first
    FROM public.player_dungeon_stats
    WHERE player_id = p_player_id AND dungeon_id = p_dungeon_id;
    
    IF v_is_first THEN
      v_gold := v_gold + (v_dungeon.gold_max * 5);
      v_xp := v_xp + (v_dungeon.xp_reward * 10);
    END IF;
  END IF;
  
  -- Update player (energy, gold, xp)
  UPDATE public.users SET
    energy = energy - v_dungeon.energy_cost,
    gold = gold + v_gold,
    xp = xp + v_xp
  WHERE auth_id = p_player_id AND energy >= v_dungeon.energy_cost;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Yetersiz enerji veya işlem çakışması');
  END IF;
  
  -- Update dungeon stats
  UPDATE public.player_dungeon_stats SET
    total_attempts = total_attempts + 1,
    total_successes = total_successes + CASE WHEN v_success THEN 1 ELSE 0 END,
    total_failures = total_failures + CASE WHEN v_success THEN 0 ELSE 1 END,
    first_clear_at = CASE WHEN v_success AND first_clear_at IS NULL THEN now() ELSE first_clear_at END,
    today_attempts = today_attempts + 1,
    today_boss_attempts = today_boss_attempts + CASE WHEN v_dungeon.is_boss THEN 1 ELSE 0 END,
    today_date = CURRENT_DATE,
    best_power_at_clear = CASE WHEN v_success AND v_power > best_power_at_clear THEN v_power ELSE best_power_at_clear END
  WHERE player_id = p_player_id AND dungeon_id = p_dungeon_id;
  
  -- Insert run record
  INSERT INTO public.dungeon_runs (
    player_id, dungeon_id, success, is_critical,
    gold_earned, xp_earned, items_dropped,
    hospitalized, hospital_until,
    player_power, success_rate_at_run, is_first_clear
  ) VALUES (
    p_player_id, p_dungeon_id, v_success, v_is_critical,
    v_gold, v_xp, v_items,
    v_hospitalized, v_hospital_until,
    v_power, v_success_rate, v_is_first
  );
  
  RETURN jsonb_build_object(
    'success', v_success,
    'is_critical', v_is_critical,
    'gold_earned', v_gold,
    'xp_earned', v_xp,
    'items_dropped', v_items,
    'hospitalized', v_hospitalized,
    'hospital_until', v_hospital_until,
    'is_first_clear', v_is_first,
    'success_rate', round(v_success_rate * 100, 1)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.enter_dungeon(UUID, TEXT) TO authenticated;
