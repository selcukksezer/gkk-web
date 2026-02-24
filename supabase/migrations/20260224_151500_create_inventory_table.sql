-- Migration: create inventory table

create table IF NOT EXISTS public.inventory (
  row_id uuid not null default gen_random_uuid (),
  user_id uuid not null,
  item_id text not null,
  quantity integer not null default 1,
  slot_position integer null,
  is_equipped boolean null default false,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  equip_slot text null,
  description text null,
  icon text null,
  weapon_type text null,
  armor_type text null,
  material_type text null,
  potion_type text null,
  base_price integer null default 0,
  vendor_sell_price integer null default 0,
  is_tradeable boolean null default true,
  is_stackable boolean null default true,
  max_stack integer null default 999,
  max_enhancement integer null default 0,
  can_enhance boolean null default false,
  heal_amount integer null default 0,
  tolerance_increase integer null default 0,
  overdose_risk double precision null default 0.0,
  required_level integer null default 0,
  required_class text null,
  recipe_requirements jsonb null default '{}'::jsonb,
  recipe_result_item_id text null,
  recipe_building_type text null,
  recipe_production_time integer null default 0,
  recipe_required_level integer null default 0,
  rune_enhancement_type text null,
  rune_success_bonus double precision null default 0.0,
  rune_destruction_reduction double precision null default 0.0,
  cosmetic_effect text null,
  cosmetic_bind_on_pickup boolean null default false,
  cosmetic_showcase_only boolean null default false,
  production_building_type text null,
  production_rate_per_hour integer null default 0,
  production_required_level integer null default 0,
  bound_to_player boolean null default false,
  pending_sync boolean null default false,
  enhancement_level integer null default 0,
  obtained_at bigint null,
  is_favorite boolean null default false,
  constraint inventory_pkey primary key (row_id),
  constraint inventory_item_id_fkey foreign KEY (item_id) references items (id),
  constraint inventory_user_id_fkey foreign KEY (user_id) references auth.users (id) on delete CASCADE,
  constraint inventory_quantity_check check ((quantity > 0))
) TABLESPACE pg_default;

create index IF not exists idx_inventory_user_id on public.inventory using btree (user_id) TABLESPACE pg_default;

create index IF not exists idx_inventory_item_id on public.inventory using btree (item_id) TABLESPACE pg_default;

create index IF not exists idx_inventory_slot_position on public.inventory using btree (user_id, slot_position) TABLESPACE pg_default;

create index IF not exists idx_inventory_equipped on public.inventory using btree (user_id, is_equipped) TABLESPACE pg_default
where
  (is_equipped = true);

create index IF not exists idx_inventory_user on public.inventory using btree (user_id) TABLESPACE pg_default;

create index IF not exists idx_inventory_item on public.inventory using btree (item_id) TABLESPACE pg_default;

create unique INDEX IF not exists idx_inventory_user_equip_slot_unique on public.inventory using btree (user_id, equip_slot) TABLESPACE pg_default
where
  (
    (is_equipped = true)
    and (equip_slot is not null)
  );

create unique INDEX IF not exists idx_inventory_user_slot_unique on public.inventory using btree (user_id, slot_position) TABLESPACE pg_default
where
  (
    (slot_position is not null)
    and (is_equipped = false)
  );
