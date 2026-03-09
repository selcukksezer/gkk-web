const fs = require('fs');

// 1. generate_enhancement.js
let enh = fs.readFileSync('generate_enhancement.js', 'utf8');
const oldEnhText = "    IF v_item.enhancement_level >= 6 AND p_rune_type != 'protection' AND p_rune_type != 'blessed' THEN\n      IF random() <= v_destroy_rate THEN\n        v_destroyed := true;\n      END IF;\n    ELSIF p_rune_type = 'blessed' THEN\n      v_new_level := v_item.enhancement_level; -- Aynı kalır\n    ELSE\n      v_new_level := GREATEST(0, v_item.enhancement_level - 1);\n    END IF;";
const newEnhText = "    IF v_item.enhancement_level >= 6 AND p_rune_type != 'protection' AND p_rune_type != 'blessed' THEN\n      IF random() <= v_destroye_rate THEN\n        v_destroyed := true;\n      ELSE\n        v_new_level := GREATEST(0, v_item.enhancement_level - 1);\n      END IF;\n    ELSIF p_rune_type = 'blessed' THEN\n      v_new_level := v_item.enhancement_level; -- Aynı kalır\n    ELSE\n      v_new_level := GREATEST(0, v_item.enhancement_level - 1);\n    END IF;";
enh = enh.replace(oldEnhText, newEnhText);
fs.writeFileSync('generate_enhancement.js', enh);

// 2. generate_dungeons.js
let dng = fs.readFileSync('generate_dungeons.js', 'utf8');
const oldDngText = "    -- Warrior boss damage modelled as +15% gold reward on boss dungeons\n    IF COALESCE(v_player.character_class, '') = 'warrior' AND v_dungeon.is_boss THEN\n      v_gold := floor(v_gold * 1.15);\n    END IF;\n  ELSE";
const newDngText = "    -- Warrior boss damage modelled as +15% gold reward on boss dungeons\n    IF COALESCE(v_player.character_class, '') = 'warrior' AND v_dungeon.is_boss THEN\n      v_gold := floor(v_gold * 1.15);\n    END IF;\n\n    -- Loot Drop Logic\n    DECLARE\n      v_drop_roll NUMERIC;\n      v_dropped_item_id TEXT;\n      v_row_id UUID;\n    BEGIN\n      v_drop_roll := random();\n      IF v_drop_roll <= v_dungeon.equipment_drop_chance THEN\n        SELECT id INTO v_dropped_item_id FROM public.items WHERE type IN ('weapon', 'armor') ORDER BY random() LIMIT 1;\n        IF v_dropped_item_id IS NOT NULL THEN\n          v_row_id := gen_random_uuid();\n          INSERT INTO public.inventory (row_id, user_id, item_id, quantity, obtained_at) VALUES (v_row_id, p_player_id, v_dropped_item_id, 1, EXTRACT(EPOCH FROM NOW())::BIGINT);\n          v_items := v_items || jsonb_build_object('id', v_dropped_item_id, 'quantity', 1);\n        END IF;\n      ELSIF v_drop_roll <= v_dungeon.equipment_drop_chance + v_dungeon.resource_drop_chance THEN\n        SELECT id INTO v_dropped_item_id FROM public.items WHERE type = 'material' ORDER BY random() LIMIT 1;\n        IF v_dropped_item_id IS NOT NULL THEN\n          v_row_id := gen_random_uuid();\n          INSERT INTO public.inventory (row_id, user_id, item_id, quantity, obtained_at) VALUES (v_row_id, p_player_id, v_dropped_item_id, 1, EXTRACT(EPOCH FROM NOW())::BIGINT);\n          v_items := v_items || jsonb_build_object('id', v_dropped_item_id, 'quantity', 1);\n        END IF;\n      END IF;\n    END;\n  ELSE";
dng = dng.replace(oldDngText, newDngText);
fs.writeFileSync('generate_dungeons.js', dng);

// 3. supabase/migrations/20260307_020000_plan_01_items_equipment_missing.sql
let eq = fs.readFileSync('supabase/migrations/20260307_020000_plan_01_items_equipment_missing.sql', 'utf8');
eq = eq.replace('SELECT level, reputation INTO v_user', 'SELECT level, reputation, attack, defense, health INTO v_user');
const oldEqText = "  v_total_power := v_equipment_power \n                   + (COALESCE(v_user.level, 1) * 500) \n                   + (COALESCE(v_user.reputation, 0) * 0.1);";
const newEqText = "  v_total_power := v_equipment_power \n                   + (COALESCE(v_user.level, 1) * 500) \n                   + (COALESCE(v_user.reputation, 0) * 0.1)\n                   + COALESCE(v_user.attack, 0)\n                   + COALESCE(v_user.defense, 0)\n                   + ( COALESCE(v_user.health, 0) / 10.0);";
eq = eq.replace(oldEqText, newEqText);
fs.writeFileSync('supabase/migrations/20260307_020000_plan_01_items_equipment_missing.sql', eq);

console.log('Fixed all files successfully');