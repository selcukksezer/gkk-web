# PLAN 12 — UI Eksiklikleri ve Güncellemeleri

Bu plan, veritabanı (SQL) tarafında uygulanmış ancak UI (React) tarafında henüz entegre edilmemiş veya eski kalmış fonksiyonların güncellenmesini kapsar.

## Hedefler

2. **Pazar Yeri (Market) Listeleme Güncellemesi:** `place_sell_order` yerine `market_list_item` kullanılması ve trade edilemez (Han-only) eşyaların UI'da engellenmesi.
3. **Crafting (Üretim) RPC Güncellemesi:** `craft_item_async` yerine sınıf ve lonca bonuslarını içeren yeni `start_crafting` RPC'sinin kullanılması.

---

## Adım 2: Pazar Yeri (Market) Güncellemesi

`is_market_tradeable` bayrağının çalışması için UI tarafı güncellenecektir.

- **Dosya:** `src/stores/marketStore.ts`
  - `createOrder` fonksiyonu içindeki `api.rpc("place_sell_order", ...)` çağrısı `api.rpc("market_list_item", ...)` olarak değiştirilecektir.
- **Dosya:** `src/components/game/InventoryDetailPanel.tsx` (Pazar sekmesi/Satış Modalı)
  - Eşyanın detaylarında `is_market_tradeable` değeri `false` ise, "Pazarda Sat" (veya benzeri) butonu **devre dışı (disabled)** bırakılacak ve üzerine "Bu eşya pazarda satılamaz (Han-only)" gibi bir tooltip/mesaj eklenecektir.

---

## Adım 3: Crafting Sistemi RPC Güncellemesi

Crafting işlemlerinde Simyacı sınıfı ve Lonca Anıtı bonuslarının aktif olabilmesi için doğru fonksiyonun çağrılması gereklidir.

- **Dosya:** `src/stores/craftingStore.ts`
  - `craftItem` metodundaki `api.rpc("craft_item_async", { p_recipe_id, p_batch_count })` çağrısı, yeni fonksiyona göre güncellenecektir:
    ```javascript
    api.rpc("start_crafting", {
      p_user_id: user.id, // Veya Auth ID
      p_recipe_id: recipeId,
      p_quantity: batchCount
    })
    ```
  - İşlem sonucunda dönen olası yeni hata mesajları UI'da gösterilecek şekilde (toast mesajları vb.) yakalanacaktır.

---

## Çalışma Sırası

1. `craftingStore.ts` dosyasındaki RPC'yi güncelle ve test et.
2. `marketStore.ts` dosyasındaki RPC'yi güncelle ve UI tarafındaki buton engellemelerini ekle.
