---
agent: agent
---
Define the task to achieve, including specific requirements, constraints, and success criteria.---
applyTo: "**/*"
---

# GKK Universal Game Development Standards

Bu belge, GKK oyun projesinde tutarlı, güvenli ve tekrarlanabilir geliştirme, migration ve dağıtım süreçleri için rehber olarak kullanılacaktır. Aşağıda teknik kurallar, dağıtım adımları, şablonlar ve güvenlik kuralları bulunur.

**Hızlı Başlangıç** — Kısa ve hızlı adımlar:
1. **Kaynak Kuralı — `yedek` klasörü:** Tüm veritabanı-schema, tablo yapıları ve SQL fonksiyonları için birincil kaynak `gkk-web/yedek` klasörüdür. Yeni RPC/DDL yazmadan önce bu klasörü inceleyin ve tam eşleşme hedefleyin. İstisna gerekiyorsa (acil düzeltme), PR açıklamasında gerekçeyi ve manuel adımları belirtin.


## Amaç ve Kapsam
- Amaç: Sunucu (Supabase/Postgres) ile istemci (Next.js/TypeScript) arasındaki sözleşmeyi katı tutmak, migration'ları güvenli şekilde dağıtmak ve oyun mantığını (Godot) web'e 1:1 taşıyabilmektir.
- Kapsam: Backend migrations, RPC (PL/pgSQL) fonksiyonları, tip güvenliği, hata yönetimi, CI, ve dağıtım süreçleri.

## Uygulama Direktifleri (Eksiksiz ve Açık)
2. **Tam Uygulama (Zero Abstraction):** Kodda `// TODO` veya "..." ile bırakılan eksik kısımlar kabul edilmez. PR kabul edilmeden önce işleyen, test edilebilir ve derlenen tam uygulama sağlanmalıdır.
3. **Mantık Eşleşmesi (Logic Parity):** Godot tarafındaki oyun mantığı (signal, state machine, hesaplamalar) TypeScript'e taşınırken algoritma azaltımı yapılmaz; davranışlar aynı kalmalı.
4. **Sıkı Tipleme:** Projede `any` kullanılmaz. Her oyun nesnesi (`ItemInstance`, `EquipSlot`, `PlayerState`) için açık interface/type tanımları olmalıdır.
5. **Hata Yönetimi:** Tüm asenkron Supabase/RPC çağrıları `try/catch` içinde yapılmalı; hata log'ları telemetry'ye gönderilmeli ve kullanıcıya anlaşılır bir fallback sağlanmalıdır.
6. **Kod Örnekleri ve Şablonlar:** Aşağıdaki bölümlerde RPC, TypeScript tipleri, ve deployment şablonları örneklenmiştir — bunları kopyala-yapıştır ile kullanabilirsiniz.

## `yedek` İncelemesi ve İstisna Prosedürü
- Her migration veya yeni RPC eklemeden önce `gkk-web/yedek` içindeki SQL dump ve fonksiyonları okuyun.
- Eğer `yedek`'te karşılık gelen fonksiyon yoksa, önce oradaki yapıyı güncelleyin (yedek → migration). Acil değişiklik gerekiyorsa PR açıklamasında: sebep, risk, geri alma adımları, ve canlı DB'de elle çalıştırılacak SQL'yi belirtin.

### Yedek İnceleme Kontrol Listesi (PR/Migration Öncesi)
- **Schema eşleştirme:** `yedek` içindeki tabloları, sütunları, tipleri ve NOT NULL/DEFAULT kurallarını yeni migration/TS modelleriyle karşılaştırın.
- **Fonksiyon/RPC imzaları:** `yedek`teki PL/pgSQL fonksiyonlarının isim, parametre isimleri, tipleri ve dönüş tiplerinin istemci çağrılarıyla uyumlu olduğunu doğrulayın. (Parametre isim değişikliği BREAKING değişikliktir.)
- **Fonksiyon davranışı:** Fonksiyonların UPDATE/DELETE gibi yan etkileri, transaction kullanımı ve `SECURITY DEFINER` gereksinimlerini kontrol edin; yeni istemci kodu bu davranışları güvenli şekilde çağırıyor mu?
- **Yetkilendirme / Grants:** `anon`, `authenticated` veya özel roller için gerekli `GRANT EXECUTE` ve tablo/row erişim izinleri `yedek`te tanımlı mı?
- **Referential integrity & constraints:** FK, unique ve check constraint'ler ile sequence/serial durumları yeni modelle uyumlu mu?
- **Data migration & rollback planı:** Kolon/parametre rename veya breaking değişiklikler için veri taşıma adımları ve geri alma SQL'i (`DROP`+`CREATE` veya eski fonksiyonu yeniden CREATE edecek script) hazır mı?
- **Index & performans:** Yeni sorgular için gerekli index'lerin `yedek`te tanımlı olduğunu doğrulayın; potansiyel yavaş sorgular için not bırakın.
- **Trigger / View / Materialized View:** Bu nesneler yeni değişikliklerle uyumlu mu? Etkileşim riskleri var mı?
- **Test RPC örnekleri:** `yedek`teki fonksiyonlar için basit test SQL veya RPC çağrı örnekleri ekleyin veya mevcut olanları güncelleyin.
- **Migration-history uyumu:** Local migration dosyaları ile `yedek`/canlı DB dump'ı arasındaki versiyon farkları tespit edildi mi? (Supabase migration-history mismatch kontrolleri)
- **Güvenlik / anahtar yönetimi:** Service-role anahtarları ve `.env` kurallarının doğru kullanıldığını doğrulayın.
- **Dokümantasyon & PR notları:** Her migration için kısa açıklama, riskler, test senaryoları ve rollback adımları PR açıklamasına eklenmiş mi?

## Migration & RPC Şablonları (SQL)
- Örnek: `equip_item` için güvenli DROP + CREATE şablonu (çalıştırmadan önce parametreleri kontrol edin):

```sql
-- DROP önce eski signature temizlenir (örnek):
DROP FUNCTION IF EXISTS public.equip_item(uuid, text);

-- CREATE: yeni, beklenen parametre isimleriyle
CREATE FUNCTION public.equip_item(p_row_id uuid, p_slot text)
RETURNS void AS $$
BEGIN
  -- Örnek gövde: inventory satırını is_equipped=true yap
  UPDATE inventory
  SET is_equipped = true, equip_slot = p_slot
  WHERE row_id = p_row_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.equip_item(uuid, text) TO anon;
```

- Not: Postgres, parametre isim değişikliği durumunda `ERROR 42P13` verir — bu yüzden `ALTER` ile isim değiştirilemez; *mutlaka* `DROP` + `CREATE` izlenmelidir.

## TypeScript Şablonları ve Örnek RPC Çağrıları
- Tip tanımı örneği:

```ts
export interface ItemInstance {
  row_id: string; // uuid
  item_id: string;
  quantity: number;
  is_equipped: boolean;
  equip_slot?: string;
}
```

- Supabase RPC çağrı örneği (try/catch, tipli):

```ts
import { supabase } from '../lib/supabase';

export async function equipItem(rowId: string, slot: string): Promise<void> {
  try {
    const { error } = await supabase.rpc('equip_item', { p_row_id: rowId, p_slot: slot });
    if (error) throw error;
  } catch (err) {
    // Telemetry veya log
    console.error('equipItem failed', err);
    throw err;
  }
}
```

## Dağıtım Rehberi (Supabase CLI & Manuel Yol)
1. Lokal hazırlık:
   - `git checkout -b feat/your-change`
   - Migration dosyasını `supabase/migrations/` içinde oluşturun.
2. Supabase CLI (önerilen yol):
   - `supabase link` — projeye düzgün şekilde bağlandığından emin olun.
   - `supabase db push` — eğer migration-history mismatch hatası alırsanız aşağıya bakın.
3. Migration-history mismatch çözümü (sık karşılaşılan adımlar):
   - Hata mesajı `remote database's migration history does not match local files` ise `supabase migration repair --apply <timestamp>` veya gerektiğinde `--revert` kullanın, fakat bunu dikkatle yapın.
   - Eğer CLI ile çözemiyorsanız manuel yöntem kullanın.
4. Manuel güvenli yol (en güvenilir, uzmanlar tarafından):
   - Supabase Dashboard → SQL Editor'e girin.
   - Önce `DROP FUNCTION IF EXISTS ...` ile eski function signature'larını kaldırın (ör: `DROP FUNCTION IF EXISTS public.equip_item(uuid, text);`).
   - Ardından yeni `CREATE FUNCTION ...` içeren SQL'i (migration içeriğini) çalıştırın.
   - Grants (yetkiler) ve `SECURITY DEFINER` ayarlarını unutmayın.
5. Doğrulama:
   - İstemciyi yeniden başlatın: `npm run dev` ve işlevselliği test edin.
   - RPC çağrıları 404/400 veriyorsa SQL signature'ını ve parametre isimlerini kontrol edin.

## CI / Pre-commit / Kontroller
- Her PR için:
  - Lint & Format (`npm run lint && npm run format`)
  - Unit test / entegrasyon test (varsa)
  - Migration sanity check: yeni migration'ların `yedek` ile çelişmediğini doğrulayan küçük betik çalıştırın.
- Örnek GitHub Action (basit):

```yaml
name: CI
on: [pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v2
      - run: pnpm install --frozen-lockfile
      - run: pnpm -w run lint
      - run: pnpm -w run test
```

## Güvenlik & Anahtar Yönetimi
- **Service Role Keys:** Asla repoya commit etmeyin. Bu anahtarlar sadece sunucu tarafında ve CI secret'larında saklanmalıdır.
- `.env.example` dosyası projede olmalı; gerçek değerler `.env` ve CI secrets içinde tutulur.
- RPC fonksiyonları `SECURITY DEFINER` gerektiriyorsa, rol ve yetkileri review edin.

## Sürümleme ve Breaking-Change Prosedürü
- Migration'larda parametre isim değişikliği BREAKING CHANGE'tir. Bu durumda:
  1. Eski fonksiyonu `DROP` et.
  2. Yeni fonksiyon `CREATE` et.
  3. İstemci kodunu deploy sırasını yönetmek için feature flag veya sürümleme kullanın.

## Ek Bilgiler ve Komutlar
- Yararlı komutlar:

```bash
cd gkk-web
npm run dev
supabase link
supabase db push
supabase migration repair --apply <timestamp>
```

- DB'de hata alırsanız, önce `DROP FUNCTION IF EXISTS ...` sonra `CREATE FUNCTION ...` adımını uygulayın.

---
Güncellemeler: Bu belge, proje ihtiyaçlarına göre düzenli olarak güncellenecektir. Yeni kurallar eklenmeden önce `yedek` klasörü audit'i ve bir PR açıklaması gereklidir.
