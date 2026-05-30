# Knight Online Esintili Lore Güncellemesi Raporu

Telif hakkı riskinden kaçınmak amacıyla, oyundaki Latince item, zırh, ve silah isimleri doğrudan Knight Online isimleri (Cleaver, Raptor vb.) yerine, o evrenin hissiyatını (vibe/temasını) verecek tamamen **özgün ve yeni** İngilizce isimlerle değiştirildi! (Örn: Shard -> Obsidian Skewer, Cleaver -> Bone Slicer vb.)

## Neler Yapıldı?
1. **Sözlük Oluşturuldu:** `exact_to_inspired.json` ve `id_to_inspired.json` üretilerek KO adları yerine "Knight Online esintili" (%100 özgün) fantastik isimler eşleştirildi. Tüm Item ID'leri oyun mantığını, animasyonları ve backend ilişkisini korumak için sabit tutuldu.
2. **PLAN Dosyaları Güncellendi:** Başta `PLAN_01_ITEMS_EQUIPMENT.md` ve `PLAN_02_FACILITIES_RESOURCES.md` olmak üzere tüm tasarım (markdown) dosyalarına ve yapay zeka (Midjourney) prompt meta verilerine baştan %100 özgün yeni lore isimleri yansıtıldı.
3. **Database Seed Güncellendi:** 
   - `supabase/seeds/plan1_items.generated.sql`
   - `supabase/seeds/plan2_resources.generated.sql`
   Yeni, telifsiz, orijinal KO-temalı lore formatına göre güncellenip SQL injectleri derlendi.

## Yapmanız Gereken Son Adım
Aktif canlı veritabanınıza bu değişimi saniyeler içinde uygulayabilmeniz için `update_items.sql` dosyasını da yepyeni özgün isimlerle güncelledim.

Zaten var olan uzak (remote) veritabanınızdaki eşyaları yenilemek için:
1. Supabase Dashboard'a girin.
2. **SQL Editor** kısmını açın.
3. Projedeki `update_items.sql` dosyasını kopyalayıp SQL Editor içerisine yapıştırın ve Run diyerek çalıştırın.

(Eğer lokal cihazınızda docker Supabase ile deneme yapıyorsanız `npx supabase db reset` komutu ile DB'yi sıfırlamanız doğrudan her şeyi %100 doğru kuracaktır çünkü seed'ler güncel.)

Oyunun tüm isim mantığı telif haklarından tamamen arındırılmış ancak "Knight" ruhunu sonuna kadar koruyacak şekle sokulmuştur. İyi geliştirmeler! 🛡️