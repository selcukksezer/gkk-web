# Store Release Test Master Plan

Bu dokuman, App Store ve Google Play cikisi oncesi oyunun canliya hazirlik kalitesini sistematik olarak dogrulamak icin test katmanlarini ve kabul kriterlerini tanimlar.

## 1) Release Gate (P0)

P0 gecmeden build store'a girmemeli.

1. Crash-free session rate >= 99.8%
2. Login success rate >= 99.5%
3. Dungeon transaction integrity >= 99.99%
4. Economy exploit testleri %100 PASS
5. Data loss (inventory, gold, xp, gems) = 0
6. Client-server state divergence < 0.1%
7. Store policy checklist (privacy, account deletion, age rating, permissions) = PASS

## 2) Test Piramidi

1. Unit test: formuller, RNG sinirlari, utility fonksiyonlar
2. Integration test: RPC + DB + auth session
3. E2E gameplay test: login -> dungeon -> reward -> inventory -> heal -> progression
4. Soak / long-run test: 6-24 saat kesintisiz
5. Chaos / fault-injection: timeout, rate-limit, stale cache, network drop
6. Device matrix test: farkli RAM/CPU/GPU profilleri

## 3) Gameplay Core Testleri

### 3.1 Dungeon Sonuc Butunlugu

Her run icin zorunlu invariant:

1. success=true ise su alanlar deterministic olarak dolu olmali:
   - gold_earned >= dungeon.gold_min
   - xp_earned >= 1
   - energy azaltimi dogru
2. success=false ise:
   - odul verilmemeli
   - hospitalized/is_hospital durumlari tutarli olmali
3. Ayni run icin tekrar eden RPC cagrisinda duplicate odul yazilmamali (idempotency)

Kabul kriteri:

1. 10.000 run'da zero-reward-success = 0
2. Duplicate reward = 0
3. Transaction rollback ihlali = 0

### 3.2 Progression Dogrulugu

1. XP -> level up threshold gecisleri dogru
2. Level up oldugunda stat/limit guncellemeleri tam
3. Dungu: level artisiyla bir ust dungeon'a gecis
4. Basarisizlik/hospital ile bir alt dungeon fallback

Kabul kriteri:

1. 1.000 adaptif run'da progression deadlock = 0
2. Dungeonda soft-lock = 0

### 3.3 Class Balance Testleri

Her class icin ayni seed setiyle 5.000 run simule edilmeli.

Olculer:

1. Win rate
2. Hospital rate
3. Ortalama gold/run
4. Ortalama xp/run
5. Item drop value/run

Kabul kriteri:

1. Siniflar arasi toplam kazanc farki (p95) <= %12
2. Her class icin en az 1 guclu ve 1 zayif matchup beklenir, ama ezici dengesizlik olmamali

## 4) Economy ve Anti-Exploit Testleri

### 4.1 Economy Stability

1. Gold faucet/sink gunluk dengesini izle
2. Gem harcamalari (heal, upgrade vb.) beklenen aralikta olmali
3. Item vendor degerlerinin tier ile monotonic artisi
4. Drop rarity dagilimi hedef tabloya yakin olmali

Kabul kriteri:

1. Simule 7 gunluk ekonomide enflasyon <= %8
2. Tek bir aktiviteden toplam gelir payi <= %35

### 4.2 Exploit Paketleri

1. Cift istek (double submit) ile odul katlama denemesi
2. Paralel 20 istek ile race condition
3. Eski token ile islem denemesi
4. Baska oyuncu auth_id ile RPC cagirma denemesi
5. Inventory doluyken odul dusurme/satma/trash sirasi manipule etme

Kabul kriteri:

1. Yetkisiz veri degisimi = 0
2. Odul duplikasyonu = 0
3. Negatif bakiye ve integer overflow = 0

## 5) Data Integrity ve DB Testleri

### 5.1 Migration Guvenligi

1. Forward migration
2. Rollback migration
3. Tekrar calistirma (idempotent migration)
4. Eski veri setinde backfill dogrulugu

Ozellikle izlenecek tablo/fonksiyonlar:

1. users.power cache tutarliligi
2. enter_dungeon hesaplamalari
3. calculate_user_total_power cagrilari

### 5.2 Constraint ve Trigger Testleri

1. Foreign key ihlali olusmuyor
2. Null veya out-of-range alanlar reject ediliyor
3. Trigger yan etkileri deterministic

Kabul kriteri:

1. DB logunda critical hata = 0
2. Veri tutarsizligi alarmi = 0

## 6) Network ve Offline Dayaniklilik

Senaryolar:

1. Dungeon RPC sirasinda 2G/3G gecis
2. %10 packet loss
3. 500ms-1500ms latency jitter
4. Request timeout + retry
5. Uygulama arka plana alip geri donme

Kabul kriteri:

1. Yanlis cift odul olusmaz
2. State bozulmaz
3. Retry sonucu deterministic olur

## 7) Mobile Device Matrix

### 7.1 Android

1. Dusuk seviye: 3-4 GB RAM
2. Orta seviye: 6-8 GB RAM
3. Yuksek seviye: 12+ GB RAM

### 7.2 iOS

1. Eski cihaz (2-3 jenerasyon once)
2. Orta jenerasyon
3. Son jenerasyon

Her cihazda:

1. Cold start suresi
2. Ortalama FPS (battle ve inventory ekranlari)
3. Jank oranlari
4. ANR / freeze
5. Arka plan -> on plan state devamlıligi

Kabul kriteri:

1. p95 cold start <= 4.0s
2. Ortalama FPS >= 55
3. ANR = 0
4. OOM crash = 0

## 8) UX, Accessibility, Localization

1. Metin tasmasi testleri (TR/EN uzun metin)
2. Dynamic type / font scaling
3. Color contrast kontrolu
4. Ses kapali/acik senaryolari
5. Onboarding drop-off adimlari

Kabul kriteri:

1. Kritik ekranda metin kirpma bug'i = 0
2. Tutorial completion >= %85

## 9) Push, Notification, Deep Link

1. Deep link ile dogru ekrana acilis
2. Notification tap -> dogru context
3. Arka planda gelen event sync

Kabul kriteri:

1. Deep link success >= %99
2. Yanlis route = 0

## 10) Security ve Store Compliance

1. Privacy manifest
2. Tracking/analytics izin akisi
3. Hesap silme akisi tam
4. KVKK/GDPR veri ihrac/silme
5. Root/jailbreak ortaminda kritik aksiyon limitleri

Kabul kriteri:

1. Policy blocker = 0
2. Yuksek riskli zafiyet = 0

## 11) Canli Operasyon ve Gozlemlenebilirlik

1. Her RPC icin request_id
2. Dungeon run event zinciri: enter, resolve, reward, inventory, heal
3. Alert kurallari:
   - zero_reward_success > 0
   - hospital_rate ani sicrama
   - gold faucet anomalisi
4. Dashboard:
   - DAU, retention, ARPDAU, crash, economy drift

Kabul kriteri:

1. Kritik anomaly tespiti <= 5 dakika
2. Incident response runbook hazir

## 12) Mevcut Scriptlere Eklenmesi Gereken Testler

Mevcutta dungeon ve pvp smoke var. Asagidaki ek paketler oncelikli:

1. Full Coverage Dungeon Sweep:
   - adaptif moda ek olarak tum 65 dungeon'a zorunlu en az 1 run
2. Idempotency Test Modu:
   - ayni oyuncu + ayni dungeon + ayni request fingerprint ile tekrar cagri
3. Concurrency Test Modu:
   - ayni oyuncu icin eszamanli 10-20 enter_dungeon
4. Auth Tamper Test Modu:
   - auth_id degistirme ve cross-user call denemesi
5. Long Soak Modu:
   - 6 saat + 24 saat run
6. Economy Drift Modu:
   - 10.000 run sonunda expected vs actual dagilim
7. Inventory Boundary Modu:
   - 19/20/21 slot etrafinda odul-satis-trashing
8. Network Fault Modu:
   - timeout/retry/cancel simulasyonu

## 13) CI/CD Pipeline Kapilari

PR acildiginda:

1. Unit + integration zorunlu
2. Kisa smoke (60 run) zorunlu

Nightly:

1. 1.000 run detailed smoke
2. Concurrency + exploit suite
3. Performance budget kontrolu

Release candidate:

1. 10.000 run economy + progression
2. Cihaz matrixi
3. Store compliance checklist

## 14) Hemen Uygulanacak Ilk 10 Gorev

1. Release gate metriklerini CI'da hard-fail kosulu yap
2. Dungeon smoke'a full coverage sweep ekle
3. Idempotency suite ekle
4. Concurrency/race suite ekle
5. Auth tamper suite ekle
6. 24 saat soak job ekle
7. Economy drift raporunu JSON + grafik ciktisiyla sakla
8. Device matrix benchmark tablolarini olustur
9. Store compliance checklist'i release template'e bagla
10. Incident runbook ve alert thresholdlerini finalize et

## 15) Cikis Karari (Go / No-Go)

Go icin asgari:

1. P0 kapilari %100 PASS
2. Son 7 gunde kritik regression = 0
3. Crash-free >= 99.8%
4. Economy exploit suite PASS
5. RC build cihaz matrixi PASS

No-Go tetikleyiciler:

1. Zero-reward-success > 0
2. Veri kaybi vakasi > 0
3. Yetkisiz islem acigi > 0
4. Critical crash orani artisi > %0.2

## 16) Son Kosu Sonucu ve TODO (2026-05-03, 1000 run)

### Sonuc Ozeti

1. assertions_pass=8/10
2. Total attempts: 1000
3. Successes: 797 (%79.7)
4. Failures: 203 (%20.3)
5. Hospitalizations: 3 (%0.3)
6. Total gold earned: 20.205.671
7. Total XP earned: 107.874
8. Total items gathered: 467
9. Zero-reward successes: 0 (duzeldi)
10. Dungeon coverage: 10/65 (FAIL)
11. Warrior Class Bonus assertion: FAIL (%79.5, hedef >=%85)

### Kritik Gozlem

1. Yuksek sayida `boss_daily_limit` hatasi goruldu (ozellikle dng_010).
2. Bu durum adaptif ilerleyisi sikistiriyor ve coverage metriğini dusuruyor.
3. Coverage FAIL ve class bonus FAIL, release oncesi kapatilmasi gereken P0/P1 kalemler.

### TODO (Aksiyon Listesi)

1. `dungeon_detailed_smoke_test.mjs` icin `FULL_COVERAGE_MODE` ekle:
   - adaptif donguden bagimsiz olarak tum dungeonlar icin en az 1 zorunlu deneme yap.
2. `boss_daily_limit` olan denemeleri ayri metrikte say:
   - `blocked_by_daily_limit` sayaci ekle,
   - bunlari normal gameplay failure ile karistirma.
3. Assertionlari guncelle:
   - `All Dungeon Coverage` icin `eligible coverage` ve `raw coverage` olarak iki metrik raporla.
4. Warrior bonus validasyonu icin class dogrulama adimi ekle:
   - preflight'ta test account class'i beklenen config ile birebir esit mi kontrol et,
   - uyusmazsa testi hard-fail et.
5. Warrior bonus assertionini normalize et:
   - daily-limit nedeniyle bloklanan denemeler disarida tutularak net class performansi hesaplansin.
6. Fail reason dagilim raporu ekle:
   - `boss_daily_limit`, `insufficient_energy`, `auth_error`, `hospitalized`, `combat_loss` ayri ayri toplansin.
7. dng_010 icin limit stratejisi belirle:
   - ya test account havuzunu genislet,
   - ya daily reset windowunda kos,
   - ya da boss-limitli dungeonlari coverage sweepten ayir.
8. Nightly pipeline'a iki profil ekle:
   - `economy_profile` (adaptif, uzun sure),
   - `coverage_profile` (tum dungeonlar, limit-aware).
9. Test ciktilarini dosyaya yaz:
   - her kosu sonunda JSON ozet (`scripts/output/dungeon_detailed_summary.json`) olustur,
   - CI artifact olarak sakla.
10. Release gate'e yeni bloklayici kosul ekle:
   - `coverage >= 95%` olmadan RC build onayi verilmesin.
