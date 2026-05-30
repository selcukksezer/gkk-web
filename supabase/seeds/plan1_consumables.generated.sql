-- AUTO-GENERATED consumables from PLAN_01_ITEMS_EQUIPMENT.md

INSERT INTO public.items (id, name, type, description, icon, rarity, base_price, vendor_sell_price, is_tradeable, is_stackable, max_stack, required_level, can_enhance)
VALUES
('potion_health_minor', 'Minor Healing Draught', 'potion', 'health (+5,000 HP) / Küçük Can İksiri', '✨', 'common', 500, 250, true, true, 99, 1, false),
('potion_health_major', 'Major Healing Potion', 'potion', 'health (+20,000 HP) / Büyük Can İksiri', '✨', 'common', 500, 250, true, true, 99, 1, false),
('potion_health_supreme', 'Supreme Health Flask', 'potion', 'health (+50,000 HP) / Yüce Can İksiri', '✨', 'common', 500, 250, true, true, 99, 1, false),
('potion_energy_minor', 'Minor Energy Vial', 'potion', 'energy (+10 energia) / Küçük Enerji Şişesi', '✨', 'common', 500, 250, true, true, 99, 1, false),
('potion_energy_major', 'Major Energy Potion', 'potion', 'energy (+25 energia) / Büyük Enerji İksiri', '✨', 'common', 500, 250, true, true, 99, 1, false),
('potion_energy_supreme', 'Supreme Energy Flask', 'potion', 'energy (+50 energia) / Yüce Enerji İksiri', '✨', 'common', 500, 250, true, true, 99, 1, false),
('potion_attack_buff', 'Vial of Warlust', 'potion', 'buff (+20% attack 30 dk) / Savaş Hırsı İksiri', '✨', 'common', 500, 250, true, true, 99, 1, false),
('potion_defense_buff', 'Flask of Iron Skin', 'potion', 'buff (+20% defense 30 dk) / Demir Deri İksiri', '✨', 'common', 500, 250, true, true, 99, 1, false),
('potion_luck_buff', 'Draught of Golden Fortune', 'potion', 'buff (+30% luck 30 dk) / Altın Şans İksiri', '✨', 'common', 500, 250, true, true, 99, 1, false),
('potion_xp_buff', 'Elixir of Rapid Wisdom', 'potion', 'buff (+50% XP 60 dk) / Hızlı Bilgelik İksiri', '✨', 'common', 500, 250, true, true, 99, 1, false),
('scroll_upgrade_low', 'Lesser Upgrade Scroll', 'scroll', 'Common/Uncommon enhancement / Küçük Geliştirme Parşömeni', '✨', 'common', 2000, 1000, true, true, 99, 1, false),
('scroll_upgrade_middle', 'Standard Upgrade Scroll', 'scroll', 'Rare/Epic enhancement / Orta Geliştirme Parşömeni', '✨', 'rare', 2000, 1000, true, true, 99, 1, false),
('scroll_upgrade_high', 'Greater Upgrade Scroll', 'scroll', 'Legendary/Mythic enhancement / Büyük Geliştirme Parşömeni', '✨', 'legendary', 2000, 1000, true, true, 99, 1, false),
('catalyst_common', 'Common Catalyst Crystal', 'catalyst', 'Common crafting / Sıradan Katalizör Kristali', '✨', 'common', 5000, 2500, true, true, 99, 1, false),
('catalyst_uncommon', 'Uncommon Reactant', 'catalyst', 'Uncommon crafting / Sıradışı Reaktant', '✨', 'uncommon', 5000, 2500, true, true, 99, 1, false),
('catalyst_rare', 'Rare Alchemical Core', 'catalyst', 'Rare crafting / Nadir Simya Çekirdeği', '✨', 'rare', 5000, 2500, true, true, 99, 1, false),
('catalyst_epic', 'Epic Transmutation Heart', 'catalyst', 'Epic crafting / Epik Dönüşüm Kalbi', '✨', 'epic', 5000, 2500, true, true, 99, 1, false),
('catalyst_legendary', 'Legendary Creation Essence', 'catalyst', 'Legendary crafting / Efsanevi Yaratılış Özü', '✨', 'legendary', 5000, 2500, true, true, 99, 1, false),
('catalyst_mythic', 'Mythic Primordial Spark', 'catalyst', 'Mythic crafting / Mistik İlksel Kıvılcım', '✨', 'mythic', 5000, 2500, true, true, 99, 1, false)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  rarity = EXCLUDED.rarity,
  type = EXCLUDED.type;
