# DEPLOY_PENDING — Supabase Migrationlar (pr-6)

Bu dosya, branch `pr-6` içindeki ve henüz deploy edilmemiş/yerelde uygulanmamış görünen Supabase migration SQL dosyalarını ve önerilen uygulama sırasını listeler.

> Not: Sıralama dosya adındaki zaman damgasına göre (artarak) yapılmıştır. Önceki migration'lar varsa önce onlar uygulanmalıdır.

## Dosyalar (uygulanma sırası)

1. `supabase/migrations/20260307_010000_character_classes_system.sql` — Status: A (staged/added)
2. `supabase/migrations/20260307_020000_plan_01_items_equipment_missing.sql` — Status: A (staged/added)
3. `supabase/migrations/20260307_030000_dungeon_system.sql` — Status: AM (staged, modified)
4. `supabase/migrations/20260307_040000_plan_05_enhancement_system.sql` — Status: AM (staged, modified)
5. `supabase/migrations/20260307_050000_plan_07_mekan_system.sql` — Status: AM (staged, modified)
6. `supabase/migrations/20260307_055000_stock_mekan_item.sql` — Status: ?? (untracked)
7. `supabase/migrations/20260307_060000_plan_08_tolerance_system.sql` — Status: ?? (untracked)
8. `supabase/migrations/20260307_070000_plan_09_reputation_pvp.sql` — Status: ?? (untracked)
9. `supabase/migrations/20260307_080000_plan_10_guild_monument.sql` — Status: ?? (untracked)
10. `supabase/migrations/20260307_090000_apply_monument_and_class_bonuses.sql` — Status: ?? (untracked)

## Açıklamalar & Öneriler

- `A` veya `AM` ile başlayan dosyalar repository'de staged/committed değişiklik olarak gözüküyor. `??` olanlar henüz git tarafından takip edilmiyor (untracked).
- Deploy sırasında **dosyaları listede verilen sırayla** uygulayın (zaman damgası artan sıraya göre). Bu, migration bağımlılıklarını korur.
- Eğer Supabase CLI kullanıyorsanız, yerelde test için öncelikle bir staging/branch DB üzerinde çalıştırın. Örnek komutlar:

```bash
# Supabase CLI ile (yerel/staging bağlantınız hazırsa)
supabase db push
# veya tek migration uygulamak isterseniz (CLI sürümüne göre değişir):
supabase migration apply 20260307_010000
```

- Eğer manuel uygulama tercih ediyorsanız, SQL dosyalarını sırayla Supabase Dashboard → SQL Editor'de `DROP FUNCTION IF EXISTS ...; CREATE FUNCTION ...;` mantığıyla çalıştırın.

## Sonraki Adımlar

- Onay verirseniz, ben bu dosyaların her birini tek tek kontrol edip (içerik/iyimserlik/`auth.uid()` kontrolleri) deploy için ek açıklamalar hazırlayabilirim.
- Ayrıca `??` (untracked) dosyaları git'e eklemek isterseniz hangi mesajla commit etmeyi tercih ettiğinizi belirtin, ben öneri hazırlayıp commit mesajlarıyla birlikte listeleyebilirim.

---
Generated: 2026-03-09
