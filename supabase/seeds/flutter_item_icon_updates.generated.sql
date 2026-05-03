-- Generated fallback updates when API update could not persist
-- Apply in Supabase SQL Editor if needed

UPDATE public.items SET icon = 'assets/icons/armor/boots_moccasins_common.png' WHERE id = 'boots_moccasins_common';
UPDATE public.items SET icon = 'assets/icons/armor/boots_moccasins_epic.png' WHERE id = 'boots_moccasins_epic';
UPDATE public.items SET icon = 'assets/icons/armor/boots_moccasins_legendary.png' WHERE id = 'boots_moccasins_legendary';
