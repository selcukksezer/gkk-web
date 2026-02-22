# Godot ↔ Web App — Kapsamlı Ekran Karşılaştırma Raporu

> Tarih: 2026-02 | Godot: `scenes/ui/screens/*.gd` | Web: `gkk-web/src/app/(game)/*/page.tsx`

---

## Özet Tablosu

| # | Godot Ekranı | Web Sayfası | Durum |
|---|---|---|---|
| 1 | HomeScreen.gd | home/page.tsx | ✅ Eşleşiyor |
| 2 | HospitalScreen.gd | ba/page.tsx | ✅ Eşleşiyor |
| 3 | PrisonScreen.gd | prison/page.tsx | ✅ Eşleşiyor |
| 4 | DungeonScreen.gd | dungeon/page.tsx | ✅ Eşleşiyor |
| 5 | DungeonBattleScreen.gd | dungeon/page.tsx (modal) | ⚠️ Kısmi — Web'de ayrı ekran yok |
| 6 | PvPScreen.gd | pvp/page.tsx | ✅ Eşleşiyor |
| 7 | QuestScreen.gd | quests/page.tsx | ✅ Eşleşiyor |
| 8 | CraftingScreen.gd | crafting/page.tsx | ✅ Eşleşiyor |
| 9 | PazarScreen.gd | market/page.tsx | ✅ Eşleşiyor |
| 10 | EquipmentScreen.gd | equipment/page.tsx | ✅ Eşleşiyor |
| 11 | InventoryScreen.gd | inventory/page.tsx | ✅ Eşleşiyor |
| 12 | ProfileScreen.gd | profile/page.tsx | ✅ Eşleşiyor |
| 13 | SettingsScreen.gd | settings/page.tsx | ⚠️ Kısmi — Eksik özellikler |
| 14 | ShopScreen.gd | shop/page.tsx | ✅ Eşleşiyor |
| 15 | GuildScreen.gd | guild/page.tsx | ✅ Eşleşiyor |
| 16 | TradeScreen.gd | trade/page.tsx | ✅ Eşleşiyor |
| 17 | BankScreen.gd | bank/page.tsx | ✅ Eşleşiyor |
| 18 | AchievementScreen.gd | achievements/page.tsx | ⚠️ Kısmi — Web mock data |
| 19 | LeaderboardScreen.gd | leaderboard/page.tsx | ✅ Eşleşiyor |
| 20 | ReputationScreen.gd | reputation/page.tsx | ⚠️ Farklı yaklaşım |
| 21 | SeasonScreen.gd | season/page.tsx | ✅ Eşleşiyor |
| 22 | WarehouseScreen.gd | warehouse/page.tsx | ✅ Eşleşiyor |
| 23 | EventScreen.gd | events/page.tsx | ✅ Eşleşiyor |
| 24 | ProductionScreen.gd | production/page.tsx | ✅ Eşleşiyor |
| 25 | GuildWarScreen.gd | guild-war/page.tsx | ✅ Eşleşiyor |
| 26 | MapScreen.gd | map/page.tsx | ✅ Eşleşiyor |
| 27 | AnvilScreen.gd | enhancement/page.tsx | ✅ Birleştirilmiş |
| 28 | BlacksmithScreen.gd | enhancement/page.tsx | ✅ Birleştirilmiş |
| 29 | CharacterScreen.gd | character/page.tsx | ✅ Eşleşiyor |
| 30 | BuildingScreen.gd | ❌ YOK | 🔴 Web sayfası eksik |
| 31 | FacilityDetailScreen.gd | facilities/page.tsx + facilities/[type]/page.tsx | ✅ TEPKİ — Detay sayfası ve tarif listesi tamamlandı |
| — | (ChatManager autoload) | chat/page.tsx | ⚠️ Godot'ta ayrı ekran yok |

---

## Detaylı Ekran Karşılaştırması

---

### 1. HomeScreen.gd ↔ home/page.tsx

**Godot API Çağrıları:** Doğrudan API yok — `State` autoload'dan okur
**Web API Çağrıları:** `usePlayerStore` (Zustand)

| Özellik | Godot | Web | Fark |
|---|---|---|---|
| Oyuncu adı/seviye/altın | ✅ | ✅ | — |
| Enerji çubuğu | ✅ | ✅ | — |
| Tolerans çubuğu | ✅ | ✅ | — |
| Hastane bildirimi | ✅ | ✅ | — |
| Düşük enerji bildirimi | ✅ | ✅ | — |
| Yüksek tolerans bildirimi | ✅ | ✅ | — |
| Hapishane bildirimi | ✅ | ✅ | — |
| Aktif görev listesi | ✅ | ❌ | **Web'de eksik** — Godot `_update_quests()` fonksiyonu aktif görevleri listeliyor |
| İksir kullan (hızlı aksiyon) | ✅ | ❌ | **Web'de eksik** — Godot'ta `_use_potion()` butonu var |
| Sınırsız enerji (dev butonu) | ✅ | ❌ | Geliştirici özelliği, web'de gereksiz |
| Hızlı aksiyon grid (16 link) | ❌ | ✅ | **Godot'ta yok** — Web'de 16 kısayol butonu var |

---

### 2. HospitalScreen.gd ↔ hospital/page.tsx

**Godot API:** `HospitalManager.fetch_hospital_status()`, `HospitalManager.release_with_gems()`
**Web API:** `api.rpc("hospital_release_with_gems")`

| Özellik | Godot | Web | Fark |
|---|---|---|---|
| Geri sayım timer | ✅ (1s tick) | ✅ (useCountdown hook) | — |
| Gem ile çıkış | ✅ | ✅ | — |
| Onay dialogu | ✅ | ✅ (Modal) | — |
| Yetersiz gem → Mağazaya yönlendirme | ✅ | ❌ | **Web'de eksik** |
| Progress bar | ❌ | ✅ | **Godot'ta yok** — Web'de progress bar var |
| Gem maliyeti hesaplama | ✅ (hours + ceil(min)) | ✅ (hours + ceil(min)) | Aynı formül |

---

### 3. PrisonScreen.gd ↔ prison/page.tsx

**Godot API:** `PrisonManager.pay_bail()`
**Web API:** `api.rpc("prison_bail")`

| Özellik | Godot | Web | Fark |
|---|---|---|---|
| Geri sayım timer | ✅ | ✅ | — |
| Kefalet (gem ile) | ✅ | ✅ | — |
| Onay dialogu | ✅ | ✅ | — |
| Progress bar | ✅ | ✅ | — |
| Hapishane nedeni gösterimi | ✅ | ✅ | — |
| Otomatik serbest bırakma kontrolü | ✅ (`State.check_prison_status()`) | ❌ | **Web'de eksik** — Otomatik state kontrolü yok |
| Gem maliyet formülü | ✅ (ceil(seconds/60)) | ✅ (ceil(seconds/60)) | Aynı |

---

### 4. DungeonScreen.gd ↔ dungeon/page.tsx

**Godot API:** `DungeonManager` (local mock data)
**Web API:** `api.rpc("get_dungeons")`, `api.rpc("enter_dungeon")`

| Özellik | Godot | Web | Fark |
|---|---|---|---|
| Zindan listesi | ✅ | ✅ | — |
| Zorluk etiketi | ✅ | ✅ | — |
| Enerji maliyeti | ✅ | ✅ | — |
| Ödül aralığı | ✅ | ✅ | — |
| Başarı oranı gösterimi | ✅ (base/gear/level/difficulty/penalty detaylı) | ✅ (tek yüzde) | **Web'de basitleştirilmiş** — Godot detaylı breakdown veriyor |
| Solo/Grup modu sekmeleri | ✅ | ❌ | **Web'de eksik** — Godot'ta solo/group tab var |
| Bilgi butonu (loot table preview) | ✅ | ❌ | **Web'de eksik** |
| Sezon modifiye edici gösterimi | ✅ | ❌ | **Web'de eksik** |
| Hastane kontrolü (giriş öncesi) | ✅ | ✅ | — |
| Giriş onay dialogu | ✅ | ✅ (Modal) | — |
| Savaş sonucu gösterimi | ✅ (DungeonBattleScreen) | ✅ (Modal) | Web'de modal, Godot'ta ayrı ekran |

---

### 5. DungeonBattleScreen.gd ↔ dungeon/page.tsx (modal)

**Godot API:** Lokal hesaplama + `State` güncelleme + `Telemetry`
**Web API:** `api.rpc("enter_dungeon")` — backend hesaplıyor

| Özellik | Godot | Web | Fark |
|---|---|---|---|
| 3 saniyelik savaş gecikmesi | ✅ | ❌ | **Web'de yok** — Anında sonuç |
| Başarı/Başarısızlık RNG | ✅ (client) | ✅ (server) | Farklı yürütme yeri |
| Ödül hesaplama (gold, xp, loot) | ✅ (client) | ✅ (server) | — |
| Hastaneye düşme (%25 şans, 2-6 saat) | ✅ (client hesaplıyor) | ✅ (server tarafından) | — |
| Telemetri izleme | ✅ | ❌ | **Web'de eksik** |
| Ödüllerin State'e uygulanması | ✅ (auto-apply) | ✅ (store update) | — |

---

### 6. PvPScreen.gd ↔ pvp/page.tsx

**Godot API:** `PvPManager.get_player_stats()`, `get_attack_history()`, `get_defense_history()`, `search_player()`, `initiate_attack()`
**Web API:** `api.rpc("attack_player")`, `api.rpc("get_pvp_history")`

| Özellik | Godot | Web | Fark |
|---|---|---|---|
| Saldırı/Savunma geçmişi sekmeleri | ✅ | ✅ (attack/history) | — |
| Oyuncu arama | ✅ | ✅ (hedef listesi) | Web'de önceden yüklü liste, Godot'ta arama tabanlı |
| İstatistik paneli (win/loss/rating/rank) | ✅ | ✅ | — |
| Savaş detay dialogu | ✅ | ✅ (Modal) | — |
| Savunma geçmişi ayrı sekmesi | ✅ | ❌ | **Web'de eksik** — Godot ayrı defense tab, web combined history |
| Altın/puan değişim detayı | ✅ | ✅ | — |

---

### 7. QuestScreen.gd ↔ quests/page.tsx

**Godot API:** `QuestManager.get_available_quests()`, `get_active_quests()`, `get_completed_quests()`, `start_quest()`
**Web API:** `api.rpc("get_available_quests")`, `api.rpc("start_quest")`

| Özellik | Godot | Web | Fark |
|---|---|---|---|
| Filtre (Tümü/Müsait/Aktif/Tamamlanan) | ✅ | ✅ | — |
| Görev detay paneli | ✅ | ✅ (expandable card) | — |
| Görev başlatma | ✅ | ✅ | — |
| İlerleme çubuğu | ✅ | ✅ | — |
| Zorluk renkleri (Kolay→Elit→Zindan) | ❌ | ✅ (5 difficulty tier) | **Godot'ta eksik** — Web 5 tier difficultyConfig var |
| Ödül gösterimi (altın, xp) | ✅ | ✅ | — |
| Seviye gereksiniimi kontrolü | ✅ | ✅ | — |

---

### 8. CraftingScreen.gd ↔ crafting/page.tsx

**Godot API:** `CraftingManager.load_all_recipes()`, `craft_item(recipe_id, batch_count)`, `is_queue_full()`
**Web API:** `useCraftingStore` → RPC calls

| Özellik | Godot | Web | Fark |
|---|---|---|---|
| Kategori sekmeleri (weapon/armor/potion/rune/scroll/accessory) | ✅ (6 kategori) | ❌ | **Web'de eksik** — Web sadece recipes/queue tab var, kategori filtresi yok |
| Tarif listesi | ✅ | ✅ | — |
| Batch miktarı seçimi | ✅ (1-5) | ✅ (1-10) | Web 10'a kadar, Godot 5'te sınırlı |
| Gem maliyeti (qty-1) | ✅ | ❌ | **Web'de eksik** — Godot'ta batch>1 gem cost var |
| Malzeme listesi (sahip olunan/gereken) | ✅ | ✅ (× batchSize) | — |
| Üretim kuyruğu | ❌ | ✅ (queue tab) | **Godot'ta eksik** — Web'de queue tab ve countdown timer var |
| Kuyruk dolu kontrolü | ✅ | ❌ | Godot `is_queue_full()` kontrolü var |
| Süre gösterimi | ❌ | ✅ | **Godot'ta eksik** — Web craft_time_seconds gösteriyor |
| Tarif detay modal | ✅ (detail panel) | ✅(Modal) | — |

---

### 9. PazarScreen.gd ↔ market/page.tsx

**Godot API:** `PazarManager.fetch_active_listings()`, `fetch_my_orders()`, `cancel_order()`, `purchase_listing()`
**Web API:** `useMarketStore` → store methods

| Özellik | Godot | Web | Fark |
|---|---|---|---|
| Gözat/Sat/Siparişlerim sekmeleri | ✅ | ✅ | — |
| Filtre paneli (arama, kategori, nadirlik) | ✅ (search + category + rarity) | ✅ (search only) | **Web'de eksik** — Kategori ve nadirlik filtresi yok |
| Listeleme satırları | ✅ | ✅ (ticker card) | — |
| Satın alma onay dialogu | ✅ | ✅ (Modal) | — |
| Envanterden satış | ✅ | ✅ | — |
| Sipariş iptali | ✅ | ✅ | — |
| Fiyat değişim göstergesi (▲▼ yüzdesi) | ❌ | ✅ | **Godot'ta yok** — Web price_change % gösteriyor |
| İşlem hacmi gösterimi | ❌ | ✅ | **Godot'ta yok** — Web volume bilgisi gösteriyor |

---

### 10. EquipmentScreen.gd ↔ equipment/page.tsx

**Godot API:** `Equipment.equip_item()`, `Equipment.get_total_stats()`
**Web API:** `useInventoryStore` → `equipItem()`, `unequipItem()`

| Özellik | Godot | Web | Fark |
|---|---|---|---|
| Paperdoll (8 slot) | ✅ (weapon, helmet, chest, gloves, pants, boots, acc1, acc2) | ✅ (weapon, head, chest, legs, boots, gloves, ring, necklace) | Slot isimleri farklı: Godot acc1/acc2 ↔ Web ring/necklace |
| Toplam stat gösterimi (ATK/DEF/HP/PWR) | ✅ | ✅ (4 stat) | — |
| Enhancement bonus hesaplama | ❌ | ✅ (1 + level × 0.1) | **Godot'ta eksik** — Web enhancement mevcut |
| Eşya çıkarma | ✅ | ✅ | — |
| Eşya seçme modal (bottom sheet) | ❌ | ✅ | **Godot'ta eksik** — Web item picker modal var |
| Slot tıklama → equip/unequip | ✅ | ✅ | — |

---

### 11. InventoryScreen.gd ↔ inventory/page.tsx

**Godot API:** `InventoryManager.use_item()`, `Equipment.equip_item()`, `Equipment.fetch_equipped_items()`
**Web API:** `useInventoryStore`

| Özellik | Godot | Web | Fark |
|---|---|---|---|
| 20 sabit slot grid (5×4) | ✅ | ✅ | — |
| Filtre (Tümü/Silahlar/Zırhlar/Tüketim/Malzeme) | ✅ | ✅ | — |
| Sıralama (isim/tür/nadirlik/seviye) | ✅ | ❌ | **Web'de eksik** |
| Drag & Drop | ✅ | ❌ | **Web'de eksik** |
| Eşya detay paneli | ✅ | ✅ (ItemDetailPanel component) | — |
| Çift tıkla kuşanma | ✅ | ✅ (onDoubleClick) | — |
| Çöp slotu | ✅ | ❌ | **Web'de eksik** |
| Eşya kullanma/satma | ✅ | ✅ | — |
| Ekipman slotu entegrasyonu | ✅ | ✅ | — |

---

### 12. ProfileScreen.gd ↔ profile/page.tsx

**Godot API:** `Network.http_get("/v1/player/profile")`
**Web API:** `usePlayerStore`

| Özellik | Godot | Web | Fark |
|---|---|---|---|
| Temel bilgiler (isim, seviye) | ✅ | ✅ | — |
| İstatistikler (güç, dayanıklılık, çeviklik, zeka, şans) | ✅ | ✅ | — |
| Servet (altın, gem) | ✅ | ✅ | — |
| PvP istatistikleri | ✅ | ✅ | — |
| Başarımlar bölümü | ✅ | ❌ | **Web'de eksik** — Godot'ta profil içinde achievement section var |
| İtibar durumu | ✅ | ✅ | — |
| Aktivite (kayıt tarihi, son giriş) | ✅ | ✅ | — |
| XP ilerleme çubuğu | ❌ | ✅ | **Godot'ta eksik** — Web XP bar gösteriyor |
| Lonca bilgisi | ❌ | ✅ | **Godot'ta eksik** — Web guild_name gösteriyor |
| Unvan | ❌ | ✅ | **Godot'ta eksik** — Web title gösteriyor |

---

### 13. SettingsScreen.gd ↔ settings/page.tsx

**Godot API:** `Config` autoload (local), `SessionManager.logout()`
**Web API:** `useAuthStore.logout()`, `useAudioStore`, `useUiStore`

| Özellik | Godot | Web | Fark |
|---|---|---|---|
| Müzik slider | ✅ | ✅ | — |
| Efekt (SFX) slider | ✅ | ✅ | — |
| Bildirim toggle | ✅ | ✅ | — |
| Çıkış yap butonu | ✅ | ✅ | — |
| Çıkış onay dialogu | ❌ | ✅ | **Godot'ta eksik** — Web logout confirm modal var |
| Otomatik savaş toggle | ✅ | ❌ | **Web'de eksik** |
| Dil seçimi (TR/EN) | ✅ | ❌ | **Web'de eksik** |
| Hesap silme butonu | ✅ | ❌ | **Web'de eksik** |
| Tüm sesleri kapat toggle | ❌ | ✅ | **Godot'ta eksik** |

---

### 14. ShopScreen.gd ↔ shop/page.tsx

**Godot API:** `Network.http_get("/shop/offers")`, `http_get("/shop/battle_pass")`, `http_post("/shop/battle_pass/claim")`, `http_patch("/rest/v1/users")`
**Web API:** `useShop` hook, `useSeason` hook

| Özellik | Godot | Web | Fark |
|---|---|---|---|
| 4 sekme (Gem/Teklif/BattlePass/Eşya) | ✅ | ✅ | — |
| Gem paketleri (altın→gem) | ✅ | ✅ | — |
| Altın paketleri (gem→altın) | ✅ | ❌ | **Web'de eksik** — Gold→Gem var ama Gem→Gold yok |
| Özel teklifler | ✅ | ✅ | — |
| Battle Pass ödülleri | ✅ | ✅ | — |
| Eşya mağazası | ✅ (ItemDatabase'den) | ✅ (hardcoded SHOP_ITEMS) | — |
| Bakiye gösterimi | ❌ | ✅ | **Godot'ta eksik** — Web gems+gold balance card gösteriyor |

---

### 15. GuildScreen.gd ↔ guild/page.tsx

**Godot API:** `GuildManager.get_player_guild()`, `leave_guild()`
**Web API:** `api.rpc("get_my_guild")`, `api.rpc("search_guilds")`, `api.rpc("join_guild")`, `api.rpc("leave_guild")`, `api.rpc("create_guild")`

| Özellik | Godot | Web | Fark |
|---|---|---|---|
| Lonca bilgi kartı | ✅ | ✅ | — |
| Üye listesi (rol emojiyle) | ✅ | ✅ | — |
| Ayrılma butonu | ✅ | ✅ | — |
| Üye yönetimi (terfi/tenzil/kovma) | ✅ | ❌ | **Web'de eksik** |
| Lonca kurma | ❌ | ✅ | **Godot'ta eksik** — Web create guild modal var |
| Lonca arama ve katılma | ✅ | ✅ | — |
| Davet etme | ✅ | ❌ | **Web'de eksik** |
| Online durumu gösterimi | ❌ | ✅ | **Godot'ta eksik** — Web is_online göstergesi var |
| Toplam güç gösterimi | ❌ | ✅ | **Godot'ta eksik** |

---

### 16. TradeScreen.gd ↔ trade/page.tsx

**Godot API:** `Network.http_post("/v1/trade/initiate")`, `.../confirm"`, `.../cancel"`
**Web API:** Mock/simulated (no real API calls)

| Özellik | Godot | Web | Fark |
|---|---|---|---|
| Oyuncu arama | ✅ | ✅ | — |
| Ticaret başlatma | ✅ | ✅ (simulated) | Web'de mock, Godot'ta gerçek API |
| Eşya ekleme | ✅ | ✅ (placeholder UI) | — |
| Onayla/İptal | ✅ | ✅ | — |
| İki taraflı eşya gösterimi | ✅ | ✅ (grid cols-2) | — |
| **Gerçek API entegrasyonu** | ✅ | ❌ | **Web'de eksik** — Tamamen simulated/mock |

---

### 17. BankScreen.gd ↔ bank/page.tsx

**Godot API:** `Network.http_get("/v1/bank/items")`, `http_post("/v1/bank/expand")`, `http_post("/v1/bank/withdraw")`
**Web API:** Mock/local state (no real API calls)

| Özellik | Godot | Web | Fark |
|---|---|---|---|
| Eşya deposu | ✅ | ✅ | — |
| Filtre sekmeleri (tümü/silah/zırh/iksir) | ✅ | ✅ | — |
| Slot genişletme (25 per expansion, gem) | ✅ | ✅ | — |
| Yatır/Çek butonları | ✅ | ✅ | — |
| **Gerçek API entegrasyonu** | ✅ | ❌ | **Web'de eksik** — Mock state, API çağrısı yok |
| Maks kapasite sınırı | ✅ | ✅ (200 max) | — |

---

### 18. AchievementScreen.gd ↔ achievements/page.tsx

**Godot API:** `Network.http_get("/v1/achievements")`, `http_post("/v1/achievements/claim")`
**Web API:** Mock data (MOCK_ACHIEVEMENTS hardcoded)

| Özellik | Godot | Web | Fark |
|---|---|---|---|
| Başarım listesi | ✅ | ✅ | — |
| İlerleme çubukları | ✅ | ✅ | — |
| Ödül toplama | ✅ | ✅ | — |
| Toplam ilerleme özeti | ❌ | ✅ | **Godot'ta eksik** — Web summary card var |
| **Gerçek API entegrasyonu** | ✅ | ❌ | **Web'de eksik** — Hardcoded mock data |

---

### 19. LeaderboardScreen.gd ↔ leaderboard/page.tsx

**Godot API:** `Network.http_get("/v1/season/current")`, `http_get("/v1/leaderboard/{category}")`
**Web API:** `useSeason` hook → `fetchLeaderboard()`, `fetchPlayerRank()`

| Özellik | Godot | Web | Fark |
|---|---|---|---|
| Kategori sekmeleri (5) | ✅ (servet/pvp/görev/ekonomi/lonca) | ✅ (gold/pvp/level/power/guild) | Kategori isimleri farklı |
| Top-3 özel stil | ✅ | ✅ (🥇🥈🥉) | — |
| Oyuncu sıralaması | ✅ | ✅ | — |
| Sezon bilgisi | ✅ | ❌ | **Web'de eksik** — Godot sezon bilgisi gösteriyor |
| Ödül kademe gösterimi | ✅ | ❌ | **Web'de eksik** — Godot reward tiers var |
| Oyuncunun kendi sırası | ❌ | ✅ | **Godot'ta eksik** — Web playerRank gösteriyor |

---

### 20. ReputationScreen.gd ↔ reputation/page.tsx

**Godot API:** `Network.http_get("/v1/player/reputation")`
**Web API:** Mock data (FACTIONS hardcoded)

| Özellik | Godot | Web | Fark |
|---|---|---|---|
| İtibar durumu gösterimi | ✅ (6 tier: Efsane→Kara Liste) | ✅ (8 tier: Nefret→Efsane) | **Farklı tier sistemi** |
| İtibar yapısı | ✅ (tek global itibar) | ✅ (5 fraksiyon bazlı itibar) | **Tamamen farklı yaklaşım** — Godot tek puan, Web 5 ayrı fraksiyon |
| İlerleme çubuğu | ❌ | ✅ | **Godot'ta eksik** |
| Aktif bonus efektler | ✅ | ✅ (bonuses per faction) | — |
| Son geçmiş | ✅ | ❌ | **Web'de eksik** — Godot recent history gösteriyor |
| Tüm tier bilgileri | ✅ | ✅ | — |
| **Gerçek API entegrasyonu** | ✅ | ❌ | **Web'de eksik** — Hardcoded mock data |

---

### 21. SeasonScreen.gd ↔ season/page.tsx

**Godot API:** Mock data
**Web API:** `useSeason` hook

| Özellik | Godot | Web | Fark |
|---|---|---|---|
| Sezon başlığı/ilerlemesi | ✅ | ✅ | — |
| Mücadele listesi + ilerleme çubukları | ✅ | ✅ (MOCK_CHALLENGES) | — |
| Ödül toplama | ✅ | ✅ | — |
| Battle Pass gösterimi | ❌ | ✅ | **Godot'ta eksik** — Web battle pass section var |
| Premium pass satın alma | ❌ | ✅ | **Godot'ta eksik** |

---

### 22. WarehouseScreen.gd ↔ warehouse/page.tsx

**Godot API:** `Network.http_get("/v1/warehouses")`, `http_get("/v1/warehouses?type={type}")`, `http_post("/v1/warehouses/upgrade")`
**Web API:** Mock data (MOCK_ITEMS hardcoded)

| Özellik | Godot | Web | Fark |
|---|---|---|---|
| Bina tipi sekmeleri (mine/lumber/alchemy/blacksmith/leather) | ✅ | ✅ | — |
| Depolama kapasitesi | ✅ | ❌ | **Web'de eksik** — Storage capacity gösterimi yok |
| Transfer/yükseltme butonları | ✅ | ❌ | **Web'de eksik** |
| Malzeme listesi | ✅ | ✅ | — |
| **Gerçek API entegrasyonu** | ✅ | ❌ | **Web'de eksik** — Mock data, API yok |

---

### 23. EventScreen.gd ↔ events/page.tsx

**Godot API:** `http_get("/v1/events/active")`, `.../upcoming"`, `.../history"`, `http_post("/v1/events/participate")`, `http_post("/v1/events/claim_reward")`
**Web API:** Mock data (MOCK_EVENTS hardcoded)

| Özellik | Godot | Web | Fark |
|---|---|---|---|
| Aktif/Yaklaşan/Geçmiş sekmeleri | ✅ | ✅ | — |
| Etkinlik katılma | ✅ | ✅ (button) | — |
| Ödül toplama | ✅ | ❌ | **Web'de eksik** — Godot claim_reward API var, web'de yok |
| İlerleme çubuğu | ❌ | ✅ | **Godot'ta eksik** — Web progress bar var |
| **Gerçek API entegrasyonu** | ✅ | ❌ | **Web'de eksik** — Tümü mock |

---

### 24. ProductionScreen.gd ↔ production/page.tsx

**Godot API:** `http_get("/v1/production/active")`, `http_post("/v1/production/start")`, `http_post("/v1/production/speedup")`, `http_post("/v1/production/cancel")`, `http_get("/v1/production/history")`
**Web API:** Local state (no API calls)

| Özellik | Godot | Web | Fark |
|---|---|---|---|
| Aktif üretimler | ✅ | ✅ | — |
| Tarif listesi (aynı 5 tarif) | ✅ | ✅ | İçerik eşleşiyor |
| Hızlandırma (speedup) | ✅ | ❌ | **Web'de eksik** |
| İptal | ✅ | ❌ | **Web'de eksik** |
| Geçmiş | ✅ | ✅ (placeholder) | Web'de boş placeholder |
| **Gerçek API entegrasyonu** | ✅ | ❌ | **Web'de eksik** — Tamamen local state |

---

### 25. GuildWarScreen.gd ↔ guild-war/page.tsx

**Godot API:** `http_get("/v1/guild_war/season")`, `.../tournaments"`, `.../territories"`, `.../rankings"`, `http_post("/v1/guild_war/join")`, `http_post("/v1/guild_war/attack")`
**Web API:** Mock data (MOCK_TOURNAMENTS hardcoded)

| Özellik | Godot | Web | Fark |
|---|---|---|---|
| Turnuvalar/Bölgeler/Sıralama sekmeleri | ✅ | ✅ | — |
| Sezon bilgisi | ✅ | ❌ | **Web'de eksik** |
| Turnuva listesi | ✅ | ✅ (mock) | — |
| Bölge haritası | ✅ | ❌ (placeholder) | **Web'de eksik** — "Yükleniyor" placeholder |
| Sıralama | ✅ | ❌ (placeholder) | **Web'de eksik** — "Bekleniyor" placeholder |
| Katılma/saldırı API | ✅ | ❌ | **Web'de eksik** |
| **Gerçek API entegrasyonu** | ✅ | ❌ | **Web'de eksik** — Mock + placeholders |

---

### 26. MapScreen.gd ↔ map/page.tsx

**Godot API:** `Network.http_get("/v1/map/regions")`, `http_post("/v1/map/travel")`
**Web API:** `api.get("/api/v1/map/regions")` + local travel simulation

| Özellik | Godot | Web | Fark |
|---|---|---|---|
| Bölge listesi | ✅ | ✅ | — |
| Tehlike seviyesi | ✅ | ✅ (⭐ 1-5) | — |
| Enerji maliyeti | ✅ | ✅ | — |
| Seyahat butonu | ✅ | ✅ | — |
| Seyahat onay dialogu | ❌ | ✅ (ConfirmDialog) | **Godot'ta eksik** |
| Seyahat API | ✅ (gerçek API) | ⚠️ (local simülasyon) | **Web kısmen eksik** — API çağrısı yapılıyor ama seyahat local simüle |
| Fallback bölgeler | ❌ | ✅ (FALLBACK_REGIONS) | Web'de offline fallback var |

---

### 27. AnvilScreen.gd ↔ enhancement/page.tsx

**Godot API:** `Network.http_post("/v1/anvil/upgrade")`
**Web API:** `useEnhancement` hook → `enhance()`

| Özellik | Godot | Web | Fark |
|---|---|---|---|
| Eşya seçimi | ✅ | ✅ | — |
| +0→+10 yükseltme | ✅ | ✅ | — |
| Başarı şansı tablosu | ✅ (rate table) | ✅ (UPGRADE_RATES aynı) | Oranlar eşleşiyor |
| Altın maliyet tablosu | ✅ | ✅ (UPGRADE_COSTS) | Maliyetler eşleşiyor |
| Rün yuvaları (3 adet) | ✅ | ✅ | — |
| Risk gösterimi (+7 seviye düşme, +8 yıkılma) | ✅ | ✅ | — |
| Yükseltme animasyonu | ✅ | ✅ (framer-motion) | — |
| Sonuç gösterimi | ✅ | ✅ (AnimatePresence) | — |

---

### 28. BlacksmithScreen.gd ↔ enhancement/page.tsx

**Godot API:** `EnhancementManager`
**Web API:** `useEnhancement` hook (birleştirilmiş)

| Özellik | Godot | Web | Fark |
|---|---|---|---|
| Drag & Drop (input/component/output slot) | ✅ | ❌ | **Web'de eksik** — Web'de liste seçimi var, D&D yok |
| Scroll uyumluluk kontrolü | ✅ | ❌ | **Web'de eksik** — Godot detaylı scroll check var |
| Başarı oranı hesaplama | ✅ | ✅ | — |

> **Not:** Web, AnvilScreen ve BlacksmithScreen'i tek bir `enhancement/page.tsx` olarak birleştirmiş. Blacksmith'e özgü özellikler (drag & drop, scroll check) web'de eksik.

---

### 29. CharacterScreen.gd ↔ character/page.tsx

**Godot API:** `State.fetch_player_profile()`
**Web API:** `usePlayerStore`, `useInventoryStore`

| Özellik | Godot | Web | Fark |
|---|---|---|---|
| Karakter bilgileri | ✅ | ✅ | — |
| İstatistikler | ✅ | ✅ (HP/ATK/DEF/Şans) | — |
| Ekipman listesi | ✅ | ✅ (6 slot) | — |
| Kaynaklar (altın/gem/enerji/tolerans) | ❌ | ✅ | **Godot'ta eksik** — Web resource section var |
| Ekipman yönetimine yönlendirme | ❌ | ✅ | **Godot'ta eksik** — Web "Teçhizat Yönetimi →" butonu var |

---

### 30. BuildingScreen.gd ↔ ❌ WEB SAYFASI YOK

**Godot API:** `http_get("/v1/buildings")`, `http_post("/v1/buildings/collect")`, `http_post("/v1/buildings/upgrade")`, `http_post("/v1/buildings/build")`

| Özellik | Godot | Web | Fark |
|---|---|---|---|
| Üretim binaları (mine/lumber/alchemy/blacksmith/leatherwork) | ✅ | ❌ | **Web sayfası tamamen eksik** |
| Kaynak toplama | ✅ | ❌ | |
| Bina yükseltme | ✅ | ❌ | |
| Yeni bina inşa etme | ✅ | ❌ | |

> **Aksiyon Gerekli:** `building/page.tsx` oluşturulmalı veya `facilities/` sayfası genişletilmeli.

---

### 31. FacilityDetailScreen.gd ↔ facilities/[type]/page.tsx

**Godot API:** `FacilityManager.fetch_recipes()`, `get_rarity_distribution()`
**Web API:** `useFacilityStore.fetchRecipes()`

| Özellik | Godot | Web | Fark |
|---|---|---|---|
| Üretim sekmesi (şüphe/rüşvet, üretim kuyruğu) | ✅ | ✅ | Tamamlandı |
| Üretim başlatma (energy cost) | ✅ | ✅ | Tamamlandı |
| Tarif listesi | ✅ | ✅ | **Tamamlandı** — `fetchRecipes()` entegrasyonu |
| Kaynaklar sekmesi (rarity rates by level) | ✅ | ✅ | **Tamamlandı** — Seviye bazlı nadirlik oranları gösteriliyor |
| Tesis seviye bazlı nadirlik oranları | ✅ | ✅ | **Tamamlandı** — Rarity distribution display eklendi |
| Yükseltme | ✅ | ✅ | Tamamlandı (cost formula fixed) |
| Üretim kuyruğu görüntüleme | ✅ | ✅ | **İyileştirildi** — Rarity ve quantity bilgisi gösteriliyor |

> **Durum:** ✅ **Tamamlandı** — Detay sayfası tamamen implementasyonu yapıldı.

---

### 32. Chat (ChatManager.gd autoload) ↔ chat/page.tsx

**Godot:** `ChatManager.gd` autoload (264 satır), ekran değil
**Web API:** `useChat` hook

| Özellik | Godot | Web | Fark |
|---|---|---|---|
| Kanal seçimi (global/trade/guild/dm) | ✅ | ✅ | — |
| Mesaj gönderme | ✅ | ✅ | — |
| Mesaj listesi (auto-scroll) | ✅ | ✅ | — |
| Oyuncu susturma (mute) | ✅ | ✅ | — |
| Mesaj raporlama | ✅ | ✅ | — |
| Karakter sınırı | ✅ | ✅ (counter gösterimi) | — |
| Sistem mesajları | ✅ | ✅ (yellow styling) | — |
| **Godot'ta ayrı ekran** | ❌ | ✅ | **Godot'ta chat/page yok** — Autoload olarak çalışıyor |

---

## Kritik Boşluklar Özeti

### Web'de Eksik Sayfalar
| Eksik Sayfa | Godot Karşılığı | Öncelik |
|---|---|---|
| `building/page.tsx` | BuildingScreen.gd | 🔴 Yüksek |

### Web'de Eksik API Entegrasyonları (Mock/Placeholder)
| Sayfa | Durum | Öncelik |
|---|---|---|
| trade/page.tsx | Tamamen simulated | 🟡 Orta |
| bank/page.tsx | Mock local state | 🟡 Orta |
| achievements/page.tsx | Hardcoded MOCK_ACHIEVEMENTS | 🟡 Orta |
| reputation/page.tsx | Hardcoded FACTIONS (farklı yapı) | 🟡 Orta |
| warehouse/page.tsx | Mock MOCK_ITEMS | 🟡 Orta |
| events/page.tsx | Hardcoded MOCK_EVENTS | 🟡 Orta |
| production/page.tsx | Local state, API yok | 🟡 Orta |
| guild-war/page.tsx | Mock + placeholders | 🟡 Orta |

### Web'de Eksik Özellikler (Mevcut Sayfalarda)
| Sayfa | Eksik Özellik | Öncelik |
|---|---|---|
| home/page.tsx | Aktif görev listesi, iksir kullanma | 🟢 Düşük |
| hospital/page.tsx | Yetersiz gem → mağaza yönlendirmesi | 🟢 Düşük |
| prison/page.tsx | Otomatik serbest bırakma kontrolü | 🟢 Düşük |
| dungeon/page.tsx | Solo/group mod, loot table preview, sezon modifiye, savaş gecikmesi | 🟡 Orta |
| pvp/page.tsx | Ayrı savunma geçmişi sekmesi | 🟢 Düşük |
| crafting/page.tsx | Kategori filtreleri (6 tür), gem maliyet (batch>1) | 🟡 Orta |
| market/page.tsx | Kategori ve nadirlik filtreleri | 🟢 Düşük |
| inventory/page.tsx | Sıralama, drag & drop, çöp slotu | 🟡 Orta |
| settings/page.tsx | Otomatik savaş, dil seçimi, hesap silme | 🟡 Orta |
| shop/page.tsx | Gem→altın paketleri | 🟢 Düşük |
| guild/page.tsx | Üye yönetimi (terfi/tenzil/kovma), davet | 🟡 Orta |
| leaderboard/page.tsx | Sezon bilgisi, ödül kademeleri | 🟢 Düşük |
| warehouse/page.tsx | Depolama kapasitesi, transfer/yükseltme | 🟡 Orta |
| production/page.tsx | Hızlandırma, iptal | 🟡 Orta |
| enhancement/page.tsx | Blacksmith drag & drop, scroll uyumluluk kontrolü | 🟢 Düşük |

### Godot'ta Eksik Özellikler
| Ekran | Eksik Özellik | Öncelik |
|---|---|---|
| HomeScreen.gd | 16 hızlı aksiyon kısayolu | 🟢 Düşük |
| EquipmentScreen.gd | Enhancement bonus hesaplama, item picker modal | 🟡 Orta |
| ProfileScreen.gd | XP bar, lonca/unvan gösterimi | 🟢 Düşük |
| SettingsScreen.gd | Çıkış onay dialogu, tüm ses kapat | 🟢 Düşük |
| ShopScreen.gd | Bakiye gösterimi | 🟢 Düşük |
| GuildScreen.gd | Lonca kurma, online durumu, toplam güç | 🟡 Orta |
| LeaderboardScreen.gd | Oyuncunun kendi sırası | 🟢 Düşük |
| ReputationScreen.gd | İlerleme çubuğu | 🟢 Düşük |
| SeasonScreen.gd | Battle pass, premium pass | 🟡 Orta |
| CharacterScreen.gd | Kaynaklar bölümü, ekipman yönlendirmesi | 🟢 Düşük |
| MapScreen.gd | Seyahat onay dialogu, fallback bölgeler | 🟢 Düşük |
| EventScreen.gd | İlerleme çubuğu | 🟢 Düşük |
| MarketScreen (Pazar) | Fiyat değişim göstergesi, işlem hacmi | 🟡 Orta |

---

## Sonraki Adımlar

1. **Acil:** `building/page.tsx` ve `facilities/[type]/page.tsx` oluştur
2. **Kısa vadede:** Mock data kullanan 8 sayfayı gerçek API'ye bağla
3. **Orta vadede:** Eksik özellikleri her iki platformda da eşitle
4. **Uzun vadede:** İtibar sistemi yapı farkını çöz (tek global vs. fraksiyon bazlı)
