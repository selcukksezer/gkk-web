# Smoke Test Setup (Supabase MCP)

Bu dosya Supabase MCP ile canli veriden hazirlanmistir.

## MCP Tespiti

- Uygun PvP mekan:
  - id: 13089ea3-b49d-4736-8870-a8d4fa3ca1cd
  - name: test
  - mekan_type: dovus_kulubu
- Uygun oyuncular (level >= 10):
  - warrior #1: edfda6a6-66ff-4c73-9c98-cf9299b4a637 (username: selcukksezer)
  - warrior #2: c57533ef-8592-4173-9be5-2f77bec03caa (username: testet)

## Not

Canli DB goruntusunde shadow ve neutral (warrior/shadow disi) test kullanicisi tespit edilmedi.
Bu nedenle script, shadow/neutral env verilmezse bu kontrolleri otomatik SKIP eder.

## .env.local Icın Hazir Blok

Asagidaki blokta UUID ve mekan id canli MCP sonucundan doldurulmustur.
Email/sifre alanlarini ilgili test hesaplarinizla doldurun.

```env
PVP_SMOKE_MEKAN_ID=13089ea3-b49d-4736-8870-a8d4fa3ca1cd

PVP_SMOKE_WARRIOR_A_UUID=edfda6a6-66ff-4c73-9c98-cf9299b4a637
PVP_SMOKE_WARRIOR_A_EMAIL=selcukksezer@gmail.com
PVP_SMOKE_WARRIOR_A_PASSWORD=selcuk123

PVP_SMOKE_WARRIOR_B_UUID=c57533ef-8592-4173-9be5-2f77bec03caa
PVP_SMOKE_WARRIOR_B_EMAIL=testet@gmail.com
PVP_SMOKE_WARRIOR_B_PASSWORD=123selcuk

# Opsiyonel (varsa doldurun, yoksa bos birakip SKIP edin)
PVP_SMOKE_SHADOW_A_UUID=
PVP_SMOKE_SHADOW_A_EMAIL=
PVP_SMOKE_SHADOW_A_PASSWORD=

PVP_SMOKE_NEUTRAL_A_UUID=
PVP_SMOKE_NEUTRAL_A_EMAIL=
PVP_SMOKE_NEUTRAL_A_PASSWORD=

# Opsiyonel test ayarlari
PVP_SMOKE_MAX_ATTEMPTS=12
PVP_SMOKE_COOLDOWN_MS=250
```

## Calistirma

```bash
npm run test:smoke:pvp
```

## Beklenen Cikti

- PASS/WARN tabanli assertion ozeti
- Attempt log
- Bloodlust set/streak/reset akisinin dogrulanmasi
- Shadow/neutral verilmemisse SKIP satirlari
