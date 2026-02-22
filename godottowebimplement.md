# Gölge Krallık: Kadim Mühür'ün Çöküşü — Godot → Next.js Dönüşüm Planı

> **Tarih:** 21 Şubat 2026
> **Proje:** GKK (Gölge Krallık: Kadim Mühür'ün Çöküşü)
> **Kaynak:** Godot 4.6 + GDScript + Supabase
> **Hedef:** Next.js 15 (App Router) + Tailwind CSS + Framer Motion + Zustand + Capacitor

---

## İçindekiler

1. [Mimari Genel Bakış](#1-mimari-genel-bakış)
2. [Teknoloji Stack](#2-teknoloji-stack)
3. [Klasör Yapısı](#3-klasör-yapısı)
4. [Faz 0: Proje Scaffolding](#faz-0-proje-scaffolding)
5. [Faz 1: Altyapı — Supabase Client + Types](#faz-1-altyapı--supabase-client--types)
6. [Faz 2: Data Layer — ItemDatabase + Config](#faz-2-data-layer--itemdatabase--config)
7. [Faz 3: Zustand Store'lar](#faz-3-zustand-storelar)
8. [Faz 4: Custom Hooks — Manager Karşılıkları](#faz-4-custom-hooks--manager-karşılıkları)
9. [Faz 5: Telemetri + Request Queue](#faz-5-telemetri--request-queue)
10. [Faz 6: Layout + Navigation](#faz-6-layout--navigation)
11. [Faz 7: Auth Sayfaları](#faz-7-auth-sayfaları)
12. [Faz 8: Home Sayfası](#faz-8-home-sayfası)
13. [Faz 9: Envanter + Ekipman](#faz-9-envanter--ekipman)
14. [Faz 10: Tesisler (Facilities)](#faz-10-tesisler-facilities)
15. [Faz 11: Crafting (Üretim Atölyesi)](#faz-11-crafting-üretim-atölyesi)
16. [Faz 12: Market (Pazar)](#faz-12-market-pazar)
17. [Faz 13: PvP + Dungeon + Hospital + Prison + Guild](#faz-13-pvp--dungeon--hospital--prison--guild)
18. [Faz 14: Görevler + Sohbet + Ayarlar + Profil + Mağaza](#faz-14-görevler--sohbet--ayarlar--profil--mağaza)
19. [Faz 15: VFX + Enhancement + Shared UI](#faz-15-vfx--enhancement--shared-ui)
20. [Faz 16: Leaderboard + Diğer Prefab'lar](#faz-16-leaderboard--diğer-prefablar)
21. [Faz 17: Capacitor Build Pipeline](#faz-17-capacitor-build-pipeline)
22. [Faz 18: Tailwind Tema + Global Stiller](#faz-18-tailwind-tema--global-stiller)
23. [Dosya-Dosya Eşleme Tablosu](#dosya-dosya-eşleme-tablosu)
24. [Backend Durumu (Değişmeyecek)](#backend-durumu-değişmeyecek)
25. [Test Stratejisi](#test-stratejisi)
26. [CI/CD Pipeline](#cicd-pipeline)

---

## 1. Mimari Genel Bakış

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        KULLANICI CİHAZI                               │
│  ┌─────────────┐   ┌─────────────┐   ┌──────────────────────────────┐ │
│  │ iOS (Swift)  │   │  Android    │   │  Web Browser (PWA optional) │ │
│  │ Capacitor    │   │ Capacitor   │   │  Vercel / Static Host       │ │
│  └──────┬───────┘   └──────┬──────┘   └─────────────┬────────────────┘ │
│         │                  │                         │                 │
│         └──────────────────┼─────────────────────────┘                 │
│                            ▼                                           │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │                    Next.js 15 Static Export                       │ │
│  │  ┌──────────┐  ┌──────────┐  ┌───────────┐  ┌─────────────────┐ │ │
│  │  │ App      │  │ Zustand  │  │ Framer    │  │ Tailwind CSS    │ │ │
│  │  │ Router   │  │ Stores   │  │ Motion    │  │ + Dark Theme    │ │ │
│  │  └──────────┘  └──────────┘  └───────────┘  └─────────────────┘ │ │
│  └──────────────────────────┬────────────────────────────────────────┘ │
└─────────────────────────────┼──────────────────────────────────────────┘
                              │ HTTPS / WSS
                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         SUPABASE BACKEND                               │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌───────────────────────┐ │
│  │ Auth     │  │ PostgreSQL│ │ Edge Fn   │  │ Realtime (WebSocket) │ │
│  │ (GoTrue) │  │ + RLS     │ │ (Deno)    │  │ Channels             │ │
│  └──────────┘  └──────────┘  └──────────┘  └───────────────────────┘ │
│  Proje: znvsyzstmxhqvdkkmgdt                                         │
│  Schema: game (public üzerinden expose)                               │
└─────────────────────────────────────────────────────────────────────────┘
```

### Temel Kararlar

| Karar | Seçim | Neden |
|-------|-------|-------|
| Framework | Next.js 15 (App Router) | SSG + Static Export desteği, Capacitor uyumu |
| Rendering | `output: 'export'` (Static) | Capacitor `file://` protokolü for native |
| State | Zustand + persist middleware | Godot singleton pattern'ına en yakın |
| Styling | Tailwind CSS v4 | Utility-first, dark mode built-in |
| Animation | Framer Motion | Page transitions, modal animations, VFX |
| Audio | Howler.js | Web Audio API wrapper, mobile uyumlu |
| HTTP | @supabase/supabase-js | NetworkManager.gd'nin 289 satırı → 5 satır |
| Realtime | Supabase Realtime (built-in) | WebSocketClient.gd karşılığı |
| Mobile | Capacitor | iOS + Android native shell |
| Deploy | Vercel (web) + App Store/Play Store (mobile) | Static export dual-target |
| Testing | Vitest + Testing Library | Unit + integration |
| Type Safety | TypeScript strict | GDScript'in typed karşılığı |

---

## 2. Teknoloji Stack

### Production Dependencies
```json
{
  "dependencies": {
    "next": "^15.1.0",
    "@supabase/supabase-js": "^2.49.0",
    "zustand": "^5.0.0",
    "framer-motion": "^11.15.0",
    "howler": "^2.2.4",
    "@capacitor/core": "^7.0.0",
    "@capacitor/ios": "^7.0.0",
    "@capacitor/android": "^7.0.0",
    "@capacitor/status-bar": "^7.0.0",
    "@capacitor/splash-screen": "^7.0.0",
    "@capacitor/haptics": "^7.0.0",
    "@capacitor/keyboard": "^7.0.0",
    "date-fns": "^4.1.0",
    "clsx": "^2.1.1",
    "tailwind-merge": "^2.6.0"
  }
}
```

### Dev Dependencies
```json
{
  "devDependencies": {
    "@types/howler": "^2.2.12",
    "typescript": "^5.7.0",
    "vitest": "^3.0.0",
    "@testing-library/react": "^16.0.0",
    "@testing-library/jest-dom": "^6.6.0",
    "eslint": "^9.0.0",
    "eslint-config-next": "^15.1.0",
    "prettier": "^3.4.0",
    "prettier-plugin-tailwindcss": "^0.6.0",
    "@capacitor/cli": "^7.0.0"
  }
}
```

---

## 3. Klasör Yapısı

```
gkk-web/
├── capacitor.config.ts
├── next.config.ts
├── tailwind.config.ts
├── tsconfig.json
├── package.json
├── .env.local                      # NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_ANON_KEY
├── public/
│   ├── assets/
│   │   ├── sprites/                # Godot assets/sprites/ → buraya kopyalanacak
│   │   │   └── facilities/         # icon_mining.png, icon_farming.png, vb.
│   │   ├── character/              # Karakter layer PNG'leri (01-19)
│   │   ├── icons/                  # assets/icons/ → buraya
│   │   ├── audio/
│   │   │   ├── music/              # menu_theme.ogg, gameplay_ambient.ogg, vb.
│   │   │   └── sfx/               # button_click.ogg, success.ogg, vb.
│   │   └── homescreen/            # assets/homescreen/ → buraya
│   ├── favicon.ico
│   └── manifest.json               # PWA manifest (optional)
├── src/
│   ├── app/
│   │   ├── layout.tsx              # Root layout: providers, auth listener, meta
│   │   ├── globals.css             # Tailwind directives + CSS variables
│   │   ├── (auth)/
│   │   │   ├── layout.tsx          # Auth layout: redirect if logged in
│   │   │   ├── login/
│   │   │   │   └── page.tsx        # Login ekranı
│   │   │   └── register/
│   │   │       └── page.tsx        # Register ekranı
│   │   └── (game)/
│   │       ├── layout.tsx          # Game layout: TopBar + BottomNav + prison guard
│   │       ├── home/
│   │       │   └── page.tsx
│   │       ├── inventory/
│   │       │   └── page.tsx
│   │       ├── equipment/
│   │       │   └── page.tsx
│   │       ├── facilities/
│   │       │   └── page.tsx
│   │       ├── crafting/
│   │       │   └── page.tsx
│   │       ├── market/
│   │       │   └── page.tsx
│   │       ├── pvp/
│   │       │   └── page.tsx
│   │       ├── dungeon/
│   │       │   └── page.tsx
│   │       ├── hospital/
│   │       │   └── page.tsx
│   │       ├── prison/
│   │       │   └── page.tsx
│   │       ├── guild/
│   │       │   └── page.tsx
│   │       ├── quests/
│   │       │   └── page.tsx
│   │       ├── chat/
│   │       │   └── page.tsx
│   │       ├── shop/
│   │       │   └── page.tsx
│   │       ├── profile/
│   │       │   └── page.tsx
│   │       └── settings/
│   │           └── page.tsx
│   ├── components/
│   │   ├── auth/
│   │   │   └── AuthGuard.tsx
│   │   ├── layout/
│   │   │   ├── TopBar.tsx
│   │   │   └── BottomNav.tsx
│   │   ├── home/
│   │   │   └── PlayerSummaryCard.tsx
│   │   ├── inventory/
│   │   │   ├── InventoryGrid.tsx
│   │   │   ├── ItemSlot.tsx
│   │   │   ├── ItemCard.tsx
│   │   │   └── ItemDetailPopup.tsx
│   │   ├── equipment/
│   │   │   ├── CharacterPaperdoll.tsx
│   │   │   └── EquipmentSlot.tsx
│   │   ├── facilities/
│   │   │   ├── FacilityCard.tsx
│   │   │   ├── DetailModal.tsx
│   │   │   ├── ProductionQueueItem.tsx
│   │   │   ├── SuspicionBar.tsx
│   │   │   ├── BribeButton.tsx
│   │   │   └── UnlockFacilityCard.tsx
│   │   ├── crafting/
│   │   │   ├── RecipeCard.tsx
│   │   │   ├── BatchSelector.tsx
│   │   │   └── CraftingQueue.tsx
│   │   ├── market/
│   │   │   ├── PazarTradeView.tsx
│   │   │   ├── PazarFilterPanel.tsx
│   │   │   ├── ListingRow.tsx
│   │   │   └── MyOrderRow.tsx
│   │   ├── pvp/
│   │   │   └── PvPTargetCard.tsx
│   │   ├── dungeon/
│   │   │   └── RewardCard.tsx
│   │   ├── guild/
│   │   │   └── GuildMemberCard.tsx
│   │   ├── quests/
│   │   │   └── QuestCard.tsx
│   │   ├── vfx/
│   │   │   └── UpgradeResultEffect.tsx
│   │   ├── ui/
│   │   │   ├── EnergyBar.tsx
│   │   │   ├── ToleranceBar.tsx
│   │   │   └── RarityBadge.tsx
│   │   ├── dialogs/
│   │   │   ├── ConfirmDialog.tsx
│   │   │   └── ResultDialog.tsx
│   │   └── shared/
│   │       ├── LeaderboardRow.tsx
│   │       └── OfferCard.tsx
│   ├── stores/
│   │   ├── useSessionStore.ts
│   │   ├── usePlayerStore.ts
│   │   ├── useInventoryStore.ts
│   │   ├── useFacilityStore.ts
│   │   ├── useCraftingStore.ts
│   │   ├── useMarketStore.ts
│   │   ├── useAudioStore.ts
│   │   └── useConfigStore.ts
│   ├── hooks/
│   │   ├── useEnergy.ts
│   │   ├── usePotion.ts
│   │   ├── usePvP.ts
│   │   ├── useDungeon.ts
│   │   ├── useGuild.ts
│   │   ├── useHospital.ts
│   │   ├── usePrison.ts
│   │   ├── useEnhancement.ts
│   │   ├── useShop.ts
│   │   ├── useQuest.ts
│   │   ├── useChat.ts
│   │   └── useSeason.ts
│   ├── lib/
│   │   ├── supabase.ts             # Supabase client init
│   │   ├── api.ts                  # All RPC wrappers
│   │   ├── realtime.ts             # Realtime channel helpers
│   │   ├── telemetry.ts            # Event tracking
│   │   ├── requestQueue.ts         # Offline queue
│   │   ├── capacitor.ts            # Native plugin wrappers
│   │   └── utils/
│   │       ├── math.ts
│   │       ├── datetime.ts
│   │       ├── string.ts
│   │       ├── validation.ts
│   │       └── crypto.ts
│   ├── data/
│   │   ├── ItemDatabase.ts
│   │   ├── FacilityConfig.ts
│   │   ├── GameConstants.ts
│   │   └── QuestDatabase.ts
│   └── types/
│       ├── player.ts
│       ├── item.ts
│       ├── inventory.ts
│       ├── dungeon.ts
│       ├── guild.ts
│       ├── pvp.ts
│       ├── quest.ts
│       ├── facility.ts
│       ├── crafting.ts
│       └── market.ts
├── ios/                             # Capacitor iOS project (auto-generated)
├── android/                         # Capacitor Android project (auto-generated)
└── scripts/
    └── build-mobile.sh              # Build + sync + open native IDEs
```

**Toplam: ~115 dosya** (kaynak kodu)

---

## Faz 0: Proje Scaffolding

### Dosya 1: Proje Oluşturma Komutları

```bash
# 1. Next.js projesi oluştur
npx create-next-app@latest gkk-web --typescript --tailwind --app --src-dir --no-eslint

# 2. Kapsamlı paket kurulumu
cd gkk-web
npm install @supabase/supabase-js zustand framer-motion howler date-fns clsx tailwind-merge
npm install -D @types/howler vitest @testing-library/react @testing-library/jest-dom

# 3. Capacitor kurulumu
npm install @capacitor/core @capacitor/cli
npx cap init "Gölge Krallık" "com.selcukksezer.golgekrallik" --web-dir out
npm install @capacitor/ios @capacitor/android @capacitor/status-bar @capacitor/splash-screen @capacitor/haptics @capacitor/keyboard
npx cap add ios
npx cap add android
```

### Dosya 2: `next.config.ts`

**Kaynak:** Yok (yeni dosya)
**Amaç:** Static export + Capacitor uyumluluğu

```typescript
import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  output: 'export',               // Static HTML export → Capacitor
  trailingSlash: true,            // file:// protocol uyumu (Capacitor)
  images: {
    unoptimized: true,            // Static export'ta Image optimization yok
  },
  // Capacitor file:// asset path uyumu
  assetPrefix: process.env.NODE_ENV === 'production' ? undefined : undefined,
};

export default nextConfig;
```

### Dosya 3: `.env.local`

**Kaynak:** `NetworkManager.gd` satır 12-13 + `game_config.json` satır 6
**Supabase Proje ID:** `znvsyzstmxhqvdkkmgdt`

```env
NEXT_PUBLIC_SUPABASE_URL=https://znvsyzstmxhqvdkkmgdt.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=<anon_key_buraya>
```

> **NOT:** Godot projede `project.godot`'ta `service_role` key hardcode edilmiş. Frontend'de **kesinlikle** `anon` key kullanılacak, `service_role` key ASLA client'a konmayacak.

### Dosya 4: `capacitor.config.ts`

```typescript
import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.selcukksezer.golgekrallik',
  appName: 'Gölge Krallık',
  webDir: 'out',
  server: {
    androidScheme: 'https',  // Android'de HTTPS kullan (CORS uyumu)
  },
  plugins: {
    StatusBar: {
      style: 'DARK',
      backgroundColor: '#1a1a2e',  // dark_theme.tres bg_dark rengi
    },
    SplashScreen: {
      launchAutoHide: true,
      backgroundColor: '#1a1a2e',
      showSpinner: false,
    },
    Keyboard: {
      resize: 'body',
      style: 'DARK',
    },
  },
};

export default config;
```

---

## Faz 1: Altyapı — Supabase Client + Types

### Dosya 5: `src/lib/supabase.ts`

**Kaynak:** `autoload/NetworkManager.gd` (289 satır) + `autoload/SessionManager.gd` (310 satır)
**Satır eşleme:**
- `NetworkManager.gd:12` `BASE_URL` → `NEXT_PUBLIC_SUPABASE_URL`
- `NetworkManager.gd:13` `WS_URL` → Supabase JS otomatik yönetir
- `NetworkManager.gd:16` `_request_tokens: 60` → istemci tarafı rate limit (opsiyonel, Supabase JS retry ile)
- `SessionManager.gd:15-20` token yönetimi → Supabase JS otomatik (session persistence)
- `SessionManager.gd:30` `_generate_device_id()` → `crypto.randomUUID()`
- `SessionManager.gd:31` `_load_username_email_map()` → localStorage

```typescript
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,   // SessionManager.gd AUTO_REFRESH_TOKENS karşılığı
    detectSessionInUrl: false, // Capacitor'da URL redirect yok
  },
  realtime: {
    params: {
      eventsPerSecond: 10,
    },
  },
});
```

**Eliminasyon:**
- `NetworkManager.gd` → `_setup_http()`, `_setup_websocket()`, `_poll_websocket()`, `_get_headers()`, `_update_rate_limit_tokens()` fonksiyonlarının TAMAMI Supabase JS tarafından otomatik halledilir → `supabase.ts` 15 satır
- `SessionManager.gd` → Token persistence, refresh timer, auth header injection → Supabase JS otomatik

### Dosya 6: `src/lib/api.ts`

**Kaynak:** `core/network/APIEndpoints.gd` + `NetworkManager.gd` + Tüm Manager'ların RPC çağrıları
**Her RPC endpoint'i bir typed fonksiyon olacak.**

```typescript
import { supabase } from './supabase';
import type { PlayerProfile } from '@/types/player';
import type { FacilityData, ProductionQueueItem } from '@/types/facility';
// ... diğer type import'ları

// ==================== AUTH ====================
// Kaynak: SessionManager.gd login() (satır 47-108), register() (satır 110-169)

export async function loginWithEmail(email: string, password: string) {
  return supabase.auth.signInWithPassword({ email, password });
}

export async function loginEdgeFunction(email: string, password: string) {
  // SessionManager.gd satır 60: Edge Function "auth-login" kullanıyor
  return supabase.functions.invoke('auth-login', {
    body: { email, password },
  });
}

export async function registerEdgeFunction(email: string, username: string, password: string, referralCode?: string) {
  // SessionManager.gd satır 120: Edge Function "auth-register"
  return supabase.functions.invoke('auth-register', {
    body: { email, username, password, referral_code: referralCode },
  });
}

// ==================== PLAYER PROFILE ====================
// Kaynak: StateStore.gd load_player_data() / SessionManager.gd _fetch_profile()

export async function fetchPlayerProfile(authId: string): Promise<PlayerProfile | null> {
  const { data, error } = await supabase
    .from('users')
    .select('*')
    .eq('auth_id', authId)
    .single();
  if (error) return null;
  return data;
}

export async function updatePlayerProfile(playerId: string, updates: Partial<PlayerProfile>) {
  // StateStore.gd satır 137: PATCH /rest/v1/users
  return supabase.from('users').update(updates).eq('id', playerId);
}

// ==================== FACILITIES ====================
// Kaynak: FacilityManager.gd (1231 satır) - Tüm RPC fonksiyonları

export async function getPlayerFacilitiesWithQueue() {
  // FacilityManager.gd satır 265: /rest/v1/rpc/get_player_facilities_with_queue
  return supabase.rpc('get_player_facilities_with_queue');
}

export async function unlockFacility(facilityType: string) {
  // FacilityManager.gd satır 340: unlock_facility RPC
  return supabase.rpc('unlock_facility', { p_facility_type: facilityType });
}

export async function upgradeFacility(facilityType: string) {
  // FacilityManager.gd satır 396: upgrade_facility RPC
  return supabase.rpc('upgrade_facility', { p_facility_type: facilityType });
}

export async function startFacilityProduction(facilityId: string) {
  // FacilityManager.gd satır 453
  return supabase.rpc('start_facility_production', { p_facility_id: facilityId });
}

export async function collectFacilityProduction(facilityId: string) {
  // FacilityManager.gd satır 510
  return supabase.rpc('collect_facility_production', { p_facility_id: facilityId });
}

export async function collectFacilityResources(facilityId: string) {
  // FacilityManager.gd satır 577
  return supabase.rpc('collect_facility_resources_v2', { p_facility_id: facilityId });
}

export async function bribeOfficials(facilityType: string, gemCost: number) {
  // FacilityManager.gd satır 652
  return supabase.rpc('bribe_officials', { p_facility_type: facilityType, p_gem_cost: gemCost });
}

export async function incrementFacilitySuspicion(facilityId: string) {
  return supabase.rpc('increment_facility_suspicion', { p_facility_id: facilityId });
}

export async function reduceFacilitySuspicion(facilityId: string) {
  return supabase.rpc('reduce_facility_suspicion', { p_facility_id: facilityId });
}

export async function updateGlobalSuspicionLevel(level: number) {
  return supabase.rpc('update_global_suspicion_level', { p_level: level });
}

export async function resetAllFacilityProduction() {
  return supabase.rpc('reset_all_facility_production');
}

// ==================== INVENTORY ====================
// Kaynak: InventoryManager.gd (547 satır)

export async function getInventory() {
  // InventoryManager.gd satır 41: rpc/get_inventory
  return supabase.rpc('get_inventory');
}

export async function addInventoryItem(itemId: string, quantity: number = 1) {
  // InventoryManager.gd satır 83: add_inventory_item_v2
  return supabase.rpc('add_inventory_item_v2', { p_item_id: itemId, p_quantity: quantity });
}

export async function removeInventoryItem(itemId: string, quantity: number = 1) {
  // InventoryManager.gd satır 127: remove_inventory_item
  return supabase.rpc('remove_inventory_item', { p_item_id: itemId, p_quantity: quantity });
}

export async function removeInventoryItemByRow(rowId: string, quantity: number = 1) {
  // InventoryManager.gd satır 162
  return supabase.rpc('remove_inventory_item_by_row', { p_row_id: rowId, p_quantity: quantity });
}

export async function updateItemPositions(positions: Array<{ row_id: string; slot_position: number }>) {
  // InventoryManager.gd satır 360: update_item_positions
  return supabase.rpc('update_item_positions', { p_positions: positions });
}

export async function upgradeItemEnhancement(rowId: string, newLevel: number) {
  // InventoryManager.gd satır 400: upgrade_item_enhancement
  return supabase.rpc('upgrade_item_enhancement', { p_row_id: rowId, p_new_level: newLevel });
}

// ==================== CRAFTING ====================
// Kaynak: CraftingManager.gd (169 satır)

export async function getCraftRecipes() {
  // CraftingManager.gd satır 30
  return supabase.rpc('get_craft_recipes');
}

export async function craftItemAsync(recipeId: string, batchCount: number = 1) {
  // CraftingManager.gd satır 60
  return supabase.rpc('craft_item_async', { p_recipe_id: recipeId, p_batch_count: batchCount });
}

export async function claimCraftedItem(queueItemId: string) {
  // CraftingManager.gd satır 105
  return supabase.rpc('claim_crafted_item', { p_queue_item_id: queueItemId });
}

// ==================== PVP ====================
// Kaynak: core/managers/PvPManager.gd

export async function findPvPTargets() {
  return supabase.rpc('find_pvp_targets');
}

export async function pvpAttack(targetId: string) {
  return supabase.rpc('pvp_attack', { p_target_id: targetId });
}

// ==================== DUNGEON ====================
// Kaynak: core/managers/DungeonManager.gd

export async function enterDungeon(dungeonId: string, difficulty: string) {
  return supabase.rpc('enter_dungeon', { p_dungeon_id: dungeonId, p_difficulty: difficulty });
}

// ==================== HOSPITAL ====================
// Kaynak: core/managers/HospitalManager.gd

export async function hospitalAdmit(data: { reason: string; duration_hours: number }) {
  return supabase.functions.invoke('hospital-admit', { body: data });
}

export async function hospitalRelease() {
  return supabase.functions.invoke('hospital-release', {});
}

// ==================== ENHANCEMENT ====================
// Kaynak: core/managers/EnhancementManager.gd

export async function enhanceItem(itemRowId: string, scrollId?: string, runeId?: string) {
  return supabase.rpc('enhance_item', {
    p_item_row_id: itemRowId,
    p_scroll_id: scrollId ?? null,
    p_rune_id: runeId ?? null,
  });
}

// ==================== ENERGY ====================
// Kaynak: core/managers/EnergyManager.gd

export async function refillEnergy() {
  return supabase.functions.invoke('energy', { body: { action: 'refill' } });
}

// ==================== GUILD ====================
// Kaynak: core/managers/GuildManager.gd

export async function createGuild(name: string, description: string) {
  return supabase.rpc('create_guild', { p_name: name, p_description: description });
}

export async function joinGuild(guildId: string) {
  return supabase.rpc('join_guild', { p_guild_id: guildId });
}

export async function leaveGuild() {
  return supabase.rpc('leave_guild');
}

// ==================== SHOP ====================
// Kaynak: core/managers/ShopManager.gd

export async function buyItem(itemId: string, quantity: number = 1) {
  return supabase.rpc('buy_item', { p_item_id: itemId, p_quantity: quantity });
}

export async function sellItem(rowId: string, quantity: number = 1) {
  return supabase.rpc('sell_item', { p_row_id: rowId, p_quantity: quantity });
}

// ==================== MARKET ====================
// Kaynak: core/managers/PazarManager.gd

export async function createMarketOrder(itemId: string, quantity: number, pricePerUnit: number, orderType: 'buy' | 'sell') {
  return supabase.rpc('create_market_order', {
    p_item_id: itemId,
    p_quantity: quantity,
    p_price_per_unit: pricePerUnit,
    p_order_type: orderType,
  });
}

export async function getMarketListings(filters?: { item_type?: string; rarity?: string }) {
  return supabase.rpc('get_market_listings', filters ?? {});
}

export async function cancelMarketOrder(orderId: string) {
  return supabase.rpc('cancel_market_order', { p_order_id: orderId });
}

// ==================== QUEST ====================
// Kaynak: core/managers/QuestManager.gd

export async function getActiveQuests() {
  return supabase.rpc('get_active_quests');
}

export async function acceptQuest(questId: string) {
  return supabase.rpc('accept_quest', { p_quest_id: questId });
}

export async function completeQuest(questId: string) {
  return supabase.rpc('complete_quest', { p_quest_id: questId });
}
```

### Dosya 7: `src/lib/realtime.ts`

**Kaynak:** `core/network/WebSocketClient.gd` (tamamı)
**Kaynak:** `NetworkManager.gd` satır 255-289 (`ws_subscribe`, `ws_unsubscribe`, `_poll_websocket`)

```typescript
import { supabase } from './supabase';
import type { RealtimeChannel } from '@supabase/supabase-js';

const channels: Map<string, RealtimeChannel> = new Map();

export function subscribeToChannel(
  channelName: string,
  table: string,
  filter: string,
  callback: (payload: any) => void
): RealtimeChannel {
  const channel = supabase
    .channel(channelName)
    .on('postgres_changes', { event: '*', schema: 'game', table, filter }, callback)
    .subscribe();

  channels.set(channelName, channel);
  return channel;
}

export function subscribeToBroadcast(
  channelName: string,
  event: string,
  callback: (payload: any) => void
): RealtimeChannel {
  const channel = supabase
    .channel(channelName)
    .on('broadcast', { event }, callback)
    .subscribe();

  channels.set(channelName, channel);
  return channel;
}

export function unsubscribeFromChannel(channelName: string): void {
  const channel = channels.get(channelName);
  if (channel) {
    supabase.removeChannel(channel);
    channels.delete(channelName);
  }
}

export function unsubscribeAll(): void {
  channels.forEach((channel) => supabase.removeChannel(channel));
  channels.clear();
}
```

### Dosya 8: `src/types/player.ts`

**Kaynak:** `core/data/PlayerData.gd` — Her property birebir taşınır

```typescript
export interface PlayerProfile {
  id: string;                      // PlayerData.gd: player_id
  auth_id: string;                 // PlayerData.gd: auth_id
  username: string;                // PlayerData.gd: username
  email: string;                   // PlayerData.gd: email
  display_name: string | null;     // PlayerData.gd: display_name
  avatar_url: string | null;       // PlayerData.gd: avatar_url
  level: number;                   // PlayerData.gd: level (default 1)
  xp: number;                      // PlayerData.gd: experience (default 0)
  gold: number;                    // PlayerData.gd: gold (default 1000)
  gems: number;                    // PlayerData.gd: gems (default 0)
  energy: number;                  // PlayerData.gd: energy (default 100)
  max_energy: number;              // PlayerData.gd: max_energy (default 100)
  attack: number;                  // PlayerData.gd: attack (default 10)
  defense: number;                 // PlayerData.gd: defense (default 5)
  health: number;                  // PlayerData.gd: health (default 100)
  max_health: number;              // PlayerData.gd: max_health (default 100)
  power: number;                   // PlayerData.gd: power (default 0)
  is_online: boolean;              // PlayerData.gd: is_online
  is_banned: boolean;              // PlayerData.gd: is_banned
  tutorial_completed: boolean;     // PlayerData.gd: tutorial_completed
  guild_id: string | null;         // PlayerData.gd: guild_id
  guild_role: string | null;       // PlayerData.gd: guild_role
  referral_code: string | null;    // PlayerData.gd: referral_code
  referred_by: string | null;      // PlayerData.gd: referred_by
  pvp_rating: number;              // PlayerData.gd: pvp_rating (default 1000)
  pvp_wins: number;                // PlayerData.gd: pvp_wins (default 0)
  pvp_losses: number;              // PlayerData.gd: pvp_losses (default 0)
  addiction_level: number;         // StateStore.gd: tolerance (PlayerData.gd: addiction_level)
  hospital_until: string | null;   // ISO datetime string
  prison_until: string | null;     // ISO datetime string
  prison_reason: string | null;
  global_suspicion_level: number;  // FacilityManager.gd: suspicion system
  last_bribe_at: string | null;    // Bribe Timestamp Filter system
  last_login_at: string | null;
  created_at: string;
  updated_at: string;
}
```

### Dosya 9: `src/types/item.ts`

**Kaynak:** `core/data/ItemData.gd` — Tüm property'ler ve yardımcı fonksiyonlar

```typescript
export type ItemType = 'weapon' | 'armor' | 'potion' | 'consumable' | 'material' | 'recipe' | 'scroll' | 'rune' | 'cosmetic';
export type Rarity = 'common' | 'uncommon' | 'rare' | 'epic' | 'legendary' | 'mythic';
export type EquipSlot = 'weapon' | 'chest' | 'head' | 'legs' | 'boots' | 'gloves' | 'ring' | 'necklace' | 'none';
export type WeaponType = 'sword' | 'axe' | 'staff' | 'bow' | 'dagger' | 'mace' | 'none';
export type ArmorType = 'plate' | 'leather' | 'cloth' | 'shield' | 'none';
export type PotionType = 'health' | 'mana' | 'energy' | 'buff' | 'none';

export interface ItemData {
  item_id: string;
  name: string;
  description: string;
  icon: string;                    // sprite path: "/assets/sprites/items/..."
  item_type: ItemType;
  rarity: Rarity;
  base_price: number;
  vendor_sell_price: number;
  // Combat stats
  attack: number;
  defense: number;
  health: number;
  power: number;
  mana: number;
  // Equipment
  equip_slot: EquipSlot;
  weapon_type: WeaponType;
  armor_type: ArmorType;
  required_level: number;
  // Enhancement
  can_enhance: boolean;
  max_enhancement: number;
  enhancement_level: number;
  // Stacking
  is_stackable: boolean;
  max_stack: number;
  quantity: number;
  // Trade
  is_tradeable: boolean;
  // Potion specifics
  potion_type: PotionType;
  energy_restore: number;
  health_restore: number;
  mana_restore: number;
  tolerance_increase: number;
  overdose_risk: number;
  buff_duration: number;
  // Material specifics
  material_type: string;
  production_building_type: string;
  production_rate_per_hour: number;
  // Rune specifics
  rune_enhancement_type: string;
  rune_success_bonus: number;
  rune_destruction_reduction: number;
  // Cosmetic specifics
  cosmetic_effect: string;
  cosmetic_bind_on_pickup: boolean;
}

// Kaynak: ItemData.gd yardımcı fonksiyonları

export function isWeapon(item: ItemData): boolean {
  return item.item_type === 'weapon';
}

export function isArmor(item: ItemData): boolean {
  return item.item_type === 'armor';
}

export function isPotion(item: ItemData): boolean {
  return item.item_type === 'potion';
}

export function isConsumable(item: ItemData): boolean {
  return item.item_type === 'consumable';
}

export function isMaterial(item: ItemData): boolean {
  return item.item_type === 'material';
}

export function isRecipe(item: ItemData): boolean {
  return item.item_type === 'recipe';
}

export function isRune(item: ItemData): boolean {
  return item.item_type === 'rune';
}

export function isCosmetic(item: ItemData): boolean {
  return item.item_type === 'cosmetic';
}

export function getDisplayName(item: ItemData): string {
  // ItemData.gd: get_display_name() — enhancement prefix
  if (item.enhancement_level > 0) {
    return `+${item.enhancement_level} ${item.name}`;
  }
  return item.name;
}
```

### Dosya 10: `src/types/inventory.ts`

**Kaynak:** `core/data/InventoryItemData.gd`

```typescript
export interface InventoryItem {
  row_id: string;
  item_id: string;
  quantity: number;
  slot_position: number;          // 0-19 (20 slot)
  is_equipped: boolean;
  equipped_slot: string;          // EquipSlot or ''
  enhancement_level: number;
  pending_sync: boolean;          // InventoryItemData.gd: offline sync flag
}
```

### Dosya 11: `src/types/dungeon.ts`

**Kaynak:** `core/data/DungeonData.gd` + `core/data/DungeonInstance.gd`

```typescript
export type DungeonDifficulty = 'easy' | 'medium' | 'hard' | 'dungeon_solo' | 'dungeon_group';

export interface DungeonData {
  id: string;
  name: string;
  description: string;
  difficulty: DungeonDifficulty;
  min_level: number;
  max_players: number;
  energy_cost: number;
  base_gold_reward: number;
  base_xp_reward: number;
  loot_table: string[];
  boss_name: string | null;
}

export interface DungeonInstance {
  id: string;
  dungeon_id: string;
  player_id: string;
  difficulty: DungeonDifficulty;
  started_at: string;
  completed_at: string | null;
  success: boolean | null;
  rewards: DungeonReward[];
}

export interface DungeonReward {
  type: 'gold' | 'xp' | 'item';
  amount?: number;
  item_id?: string;
  rarity?: string;
}
```

### Dosya 12: `src/types/guild.ts`

**Kaynak:** `core/data/GuildData.gd` + `core/data/GuildMemberData.gd`

```typescript
export type GuildRole = 'leader' | 'officer' | 'member';

export interface GuildData {
  id: string;
  name: string;
  description: string;
  level: number;
  leader_id: string;
  member_count: number;
  max_members: number;
  treasury_gold: number;
  treasury_gems: number;
  tax_rate: number;
  icon_url: string | null;
  created_at: string;
}

export interface GuildMemberData {
  id: string;
  guild_id: string;
  player_id: string;
  username: string;
  level: number;
  role: GuildRole;
  contribution: number;
  joined_at: string;
  last_active: string;
}
```

### Dosya 13: `src/types/pvp.ts`

**Kaynak:** `core/data/PvPData.gd`

```typescript
export interface PvPTarget {
  id: string;
  username: string;
  level: number;
  power: number;
  pvp_rating: number;
  attack: number;
  defense: number;
  health: number;
  guild_name: string | null;
}

export interface PvPResult {
  success: boolean;
  attacker_damage: number;
  defender_damage: number;
  gold_stolen: number;
  rating_change: number;
  is_critical: boolean;
  defender_hospitalized: boolean;
}
```

### Dosya 14: `src/types/quest.ts`

**Kaynak:** `core/data/QuestData.gd`

```typescript
export type QuestDifficulty = 'easy' | 'medium' | 'hard' | 'dungeon';
export type QuestStatus = 'available' | 'active' | 'completed' | 'failed';

export interface QuestData {
  id: string;
  name: string;
  description: string;
  difficulty: QuestDifficulty;
  required_level: number;
  energy_cost: number;
  gold_reward: number;
  xp_reward: number;
  gem_reward: number;
  item_rewards: string[];
  status: QuestStatus;
  progress: number;
  target: number;
  expires_at: string | null;
}
```

### Dosya 15: `src/types/facility.ts`

**Kaynak:** `FacilityManager.gd` satır 20-250

```typescript
export type FacilityType =
  // Temel Kaynaklar (1-5)
  | 'mining' | 'quarry' | 'lumber_mill' | 'clay_pit' | 'sand_quarry'
  // Organik Kaynaklar (6-10)
  | 'farming' | 'herb_garden' | 'ranch' | 'apiary' | 'mushroom_farm'
  // Mistik Kaynaklar (11-15)
  | 'rune_mine' | 'holy_spring' | 'shadow_pit' | 'elemental_forge' | 'time_well';

export interface FacilityConfig {
  name: string;
  icon: string;
  description: string;
  resources: string[];
  base_rate: number;
  unlock_level: number;
  unlock_cost: number;
  base_upgrade_cost: number;
  upgrade_multiplier: number;
}

export interface PlayerFacility {
  id: string;
  player_id: string;
  facility_type: FacilityType;
  level: number;
  suspicion: number;
  is_active: boolean;
  last_collection_at: string | null;
  production_started_at: string | null;
  facility_queue: ProductionQueueItem[];
}

export interface ProductionQueueItem {
  id: string;
  facility_id: string;
  recipe_id: string;
  recipe_name: string;
  quantity: number;
  rarity: string;
  started_at: string;
  completes_at: string;
  is_completed: boolean;
}

export type ResourceRarity = 'common' | 'uncommon' | 'rare' | 'epic' | 'legendary';

export interface ResourceRarityDistribution {
  common: number;
  uncommon: number;
  rare: number;
  epic: number;
  legendary: number;
}
```

### Dosya 16: `src/types/crafting.ts`

**Kaynak:** `CraftingManager.gd`

```typescript
export interface CraftRecipe {
  id: string;
  name: string;
  description: string;
  result_item_id: string;
  result_quantity: number;
  result_rarity: string;
  ingredients: CraftIngredient[];
  production_time_seconds: number;
  required_facility_type: string;
  required_facility_level: number;
  success_rate: number;
}

export interface CraftIngredient {
  item_id: string;
  quantity: number;
}

export interface CraftQueueItem {
  id: string;
  recipe_id: string;
  recipe_name: string;
  batch_count: number;
  started_at: string;
  completes_at: string;
  is_completed: boolean;
  claimed: boolean;
}
```

### Dosya 17: `src/types/market.ts`

**Kaynak:** `core/managers/PazarManager.gd` + UI bileşenleri

```typescript
export type OrderType = 'buy' | 'sell';
export type OrderStatus = 'active' | 'filled' | 'cancelled' | 'expired';

export interface MarketOrder {
  id: string;
  player_id: string;
  item_id: string;
  item_name: string;
  quantity: number;
  price_per_unit: number;
  total_price: number;
  order_type: OrderType;
  status: OrderStatus;
  filled_quantity: number;
  created_at: string;
  expires_at: string;
}

export interface MarketListing {
  item_id: string;
  item_name: string;
  item_type: string;
  rarity: string;
  lowest_sell_price: number;
  highest_buy_price: number;
  volume_24h: number;
  average_price: number;
}
```

### Dosya 18-22: Utils (`src/lib/utils/`)

#### Dosya 18: `src/lib/utils/math.ts`

**Kaynak:** `core/utils/MathUtils.gd` — Her fonksiyon birebir

```typescript
// MathUtils.gd satır 5: clamp
export function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

// MathUtils.gd satır 9: lerp
export function lerp(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

// MathUtils.gd satır 13: inverse_lerp
export function inverseLerp(a: number, b: number, value: number): number {
  if (a === b) return 0;
  return (value - a) / (b - a);
}

// MathUtils.gd satır 19: remap
export function remap(value: number, fromLow: number, fromHigh: number, toLow: number, toHigh: number): number {
  return lerp(toLow, toHigh, inverseLerp(fromLow, fromHigh, value));
}

// MathUtils.gd satır 23: random_range
export function randomRange(min: number, max: number): number {
  return Math.random() * (max - min) + min;
}

// MathUtils.gd satır 27: random_int
export function randomInt(min: number, max: number): number {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

// MathUtils.gd satır 31: chance (returns true with given probability)
export function chance(probability: number): boolean {
  return Math.random() < probability;
}

// MathUtils.gd satır 35: weighted_random
export function weightedRandom<T>(items: T[], weights: number[]): T {
  const totalWeight = weights.reduce((sum, w) => sum + w, 0);
  let random = Math.random() * totalWeight;
  for (let i = 0; i < items.length; i++) {
    random -= weights[i];
    if (random <= 0) return items[i];
  }
  return items[items.length - 1];
}

// MathUtils.gd satır 50: format_number (1234567 → "1,234,567")
export function formatNumber(value: number): string {
  return value.toLocaleString('tr-TR');
}

// MathUtils.gd satır 55: format_compact (1500 → "1.5K")
export function formatCompact(value: number): string {
  if (value >= 1_000_000) return `${(value / 1_000_000).toFixed(1)}M`;
  if (value >= 1_000) return `${(value / 1_000).toFixed(1)}K`;
  return value.toString();
}
```

#### Dosya 19: `src/lib/utils/datetime.ts`

**Kaynak:** `core/utils/DateTimeUtils.gd`

```typescript
// DateTimeUtils.gd: format_remaining_time  
export function formatRemainingTime(seconds: number): string {
  if (seconds <= 0) return 'Hazır';
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = Math.floor(seconds % 60);
  if (h > 0) return `${h}s ${m}dk`;
  if (m > 0) return `${m}dk ${s}sn`;
  return `${s}sn`;
}

// DateTimeUtils.gd: format_date
export function formatDate(isoString: string): string {
  return new Date(isoString).toLocaleDateString('tr-TR');
}

// DateTimeUtils.gd: format_time_ago
export function formatTimeAgo(isoString: string): string {
  const seconds = Math.floor((Date.now() - new Date(isoString).getTime()) / 1000);
  if (seconds < 60) return 'Az önce';
  if (seconds < 3600) return `${Math.floor(seconds / 60)} dakika önce`;
  if (seconds < 86400) return `${Math.floor(seconds / 3600)} saat önce`;
  return `${Math.floor(seconds / 86400)} gün önce`;
}

// DateTimeUtils.gd: is_expired
export function isExpired(isoString: string | null): boolean {
  if (!isoString) return true;
  return new Date(isoString).getTime() < Date.now();
}

// DateTimeUtils.gd: seconds_until
export function secondsUntil(isoString: string): number {
  return Math.max(0, Math.floor((new Date(isoString).getTime() - Date.now()) / 1000));
}

// DateTimeUtils.gd: minutes_to_hms
export function minutesToHms(minutes: number): string {
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  if (h > 0) return `${h} saat ${m} dakika`;
  return `${m} dakika`;
}
```

#### Dosya 20: `src/lib/utils/string.ts`

**Kaynak:** `core/utils/StringUtils.gd`

```typescript
export function truncate(str: string, maxLength: number): string {
  if (str.length <= maxLength) return str;
  return str.slice(0, maxLength - 3) + '...';
}

export function capitalizeFirst(str: string): string {
  if (!str) return '';
  return str.charAt(0).toUpperCase() + str.slice(1);
}

export function formatGold(amount: number): string {
  return `${amount.toLocaleString('tr-TR')} 🪙`;
}

export function formatGems(amount: number): string {
  return `${amount.toLocaleString('tr-TR')} 💎`;
}

export function pluralize(count: number, singular: string, plural: string): string {
  return count === 1 ? singular : plural;
}
```

#### Dosya 21: `src/lib/utils/validation.ts`

**Kaynak:** `core/utils/ValidationUtils.gd`

```typescript
export function isValidEmail(email: string): boolean {
  return /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/.test(email);
}

export function isValidUsername(username: string): { valid: boolean; error?: string } {
  if (username.length < 3) return { valid: false, error: 'Kullanıcı adı en az 3 karakter olmalı' };
  if (username.length > 20) return { valid: false, error: 'Kullanıcı adı en fazla 20 karakter olmalı' };
  if (!/^[a-zA-Z0-9_]+$/.test(username)) return { valid: false, error: 'Sadece harf, rakam ve alt çizgi kullanılabilir' };
  return { valid: true };
}

export function isValidPassword(password: string): { valid: boolean; error?: string } {
  if (password.length < 6) return { valid: false, error: 'Şifre en az 6 karakter olmalı' };
  return { valid: true };
}

export function validatePrice(price: number): { valid: boolean; error?: string } {
  if (price <= 0) return { valid: false, error: 'Fiyat 0\'dan büyük olmalı' };
  if (!Number.isFinite(price)) return { valid: false, error: 'Geçersiz fiyat' };
  return { valid: true };
}
```

#### Dosya 22: `src/lib/utils/crypto.ts`

**Kaynak:** `core/utils/CryptoUtils.gd`

```typescript
export async function sha256(message: string): Promise<string> {
  const msgBuffer = new TextEncoder().encode(message);
  const hashBuffer = await crypto.subtle.digest('SHA-256', msgBuffer);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}

export function generateDeviceId(): string {
  // SessionManager.gd: _generate_device_id()
  let deviceId = localStorage.getItem('gkk_device_id');
  if (!deviceId) {
    deviceId = crypto.randomUUID();
    localStorage.setItem('gkk_device_id', deviceId);
  }
  return deviceId;
}
```

---

## Faz 2: Data Layer — ItemDatabase + Config

### Dosya 23: `src/data/ItemDatabase.ts`

**Kaynak:** `core/data/ItemDatabase.gd` (752+ satır)
**İçerik:** 39+ item'ın TAMAMI statik obje olarak tanımlanacak. Her item'ın TÜM property'leri (item_id, name, description, icon, item_type, rarity, base_price, vendor_sell_price, attack, defense, health, power, mana, equip_slot, weapon_type, armor_type, required_level, can_enhance, max_enhancement, is_stackable, max_stack, is_tradeable, potion_type, energy_restore, health_restore, mana_restore, tolerance_increase, overdose_risk, buff_duration, material_type, production_building_type, production_rate_per_hour, rune_enhancement_type, rune_success_bonus, rune_destruction_reduction, cosmetic_effect, cosmetic_bind_on_pickup)

**Utility fonksiyonlar:** getItem, getItemsByType, getWeapons, getArmor, getPotions, getMaterials, getRecipes, getRunes, getCosmetics, getScrolls, createItem, getRandomItemByRarity, getItemValue, itemExists, getAllItems

### Dosya 24: `src/data/FacilityConfig.ts`

**Kaynak:** `FacilityManager.gd` satır 20-250

**İçerik:**
- `FACILITY_TYPES` — 15 tesis isim mapping'i (mining→"Maden Ocağı", quarry→"Taş Ocağı", vb.)
- `FACILITIES_CONFIG` — 15 tesis tam konfigürasyonu
- `FACILITY_RESOURCES_FULL` — Her tesisin kaynak detayları (isim, icon, rarity, description)
- `RARITY_DISTRIBUTION` — Level bazlı rarity dağılımı
- `RESOURCE_RARITY_TIERS` — Hangi kaynağın hangi rarity'de olduğu
- `RARITY_UNLOCK_LEVELS` — Her rarity'nin açılma seviyesi

### Dosya 25: `src/data/GameConstants.ts`

**Kaynak:** `resources/configs/game_config.json` (206 satır) + `ConfigManager.gd` (222 satır)

**İçerik — tam JSON yapısı:**
```typescript
export const GAME_CONFIG = {
  game: { version: "0.1.0", api_version: "v1", min_client_version: "0.1.0", environment: "development" },
  energy: { max_energy: 100, regen_rate: 1, regen_interval: 180, refill_cost_gems: 50, daily_refills_limit: 5 },
  potion: { max_tolerance: 100, tolerance_decay_rate: 1, tolerance_decay_interval: 21600, overdose_threshold: 0.8, overdose_base_risk: 0.05, hospital_duration_hours: { min: 2, max: 12 } },
  pvp: { energy_cost: 15, revenge_time_window: 86400, revenge_energy_cost: 0, critical_chance: 0.1, hospital_duration_critical: 28800, gold_steal_percentage: 0.05, reputation_loss_per_attack: -3, reputation_gain_defend: 5, bandit_reputation_threshold: -50, hero_reputation_threshold: 50, max_attacks_per_day: 50 },
  quest: { energy_costs: { easy: 5, medium: 10, hard: 15, dungeon: 20 }, success_rates: { easy: 1.0, medium: 0.95, hard: 0.85, dungeon: 0.75 }, critical_failure_rates: { easy: 0.0, medium: 0.01, hard: 0.05, dungeon: 0.1 }, daily_quest_reset_hour: 0, max_active_quests: 10 },
  dungeon: { /* ... full config ... */ },
  hospital: { base_duration_hours: 2, max_duration_hours: 12, gem_release_cost_per_minute: 3, healer_base_cost: 1000, healer_success_rate_min: 0.3, healer_success_rate_max: 0.7, guild_help_reduction_percent: 20, guild_help_cooldown: 3600 },
  market: { order_fee_percent: 0.02, max_orders_per_player: 50, order_expiry_days: 7, price_change_alert_percent: 10, regions: ["central", "north", "south", "east", "west"], arbitrage_enabled: true },
  guild: { creation_cost: 10000, max_members: { level_1: 30, level_2: 40, level_3: 50, level_4: 75, level_5: 100 }, default_tax_rate: 0.05, max_tax_rate: 0.2, war_duration_hours: 24, war_cooldown_hours: 72 },
  enhancement: { success_rates: [1.0, 1.0, 1.0, 1.0, 0.8, 0.8, 0.6, 0.6, 0.4, 0.2, 0.1], destruction_rates: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.05, 0.1, 0.15], stat_bonus_per_level: 0.1, scroll_cost_multiplier: [1, 1, 1, 1, 2, 2, 3, 3, 5, 8, 10] },
  monetization: { energy_refill_gem_cost: 50, hospital_release_gem_per_minute: 3, starter_pack_cost: 9.99, premium_currency_packs: [/*...*/] },
  season: { duration_days: 90, rewards_tiers: [/*...*/] },
  cache: { player_cache_ttl: 300, market_cache_ttl: 10, guild_cache_ttl: 60, quest_cache_ttl: 300, config_cache_ttl: 3600 },
  rate_limits: { api_requests_per_minute: 60, quest_completions_per_hour: 20, market_orders_per_hour: 30, pvp_attacks_per_hour: 10, chat_messages_per_minute: 10 }
} as const;
```

### Dosya 26: `src/data/QuestDatabase.ts`

**Kaynak:** `resources/quests/quests_database.json`

---

## Faz 3: Zustand Store'lar

### Dosya 27: `src/stores/useSessionStore.ts`

**Kaynak:** `autoload/SessionManager.gd` (438 satır)

**State:**
| GDScript Variable | TypeScript State | Satır |
|---|---|---|
| `access_token` | *(Supabase JS yönetir)* | 15 |
| `refresh_token` | *(Supabase JS yönetir)* | 16 |
| `device_id` | `deviceId: string` | 17 |
| `player_id` | `playerId: string` | 18 |
| `username` | `username: string` | 19 |
| `is_authenticated` | `isAuthenticated: boolean` | 20 |
| `_username_email_map` | `usernameEmailMap: Record<string, string>` | 24 |

**Actions:**
| GDScript Function | TypeScript Action | Kaynak Satır |
|---|---|---|
| `login(email, password)` | `login(emailOrUsername, password)` | 47-108 |
| `register(email, username, password, referral_code)` | `register(email, username, password, referralCode?)` | 110-169 |
| `logout()` | `logout()` | 171-190 |
| `refresh_access_token()` | *(Supabase JS otomatik)* | 192-230 |
| `_load_tokens()` | *(Supabase JS otomatik)* | 232-260 |
| `_save_tokens()` | *(Supabase JS otomatik)* | 262-280 |
| `_generate_device_id()` | `generateDeviceId()` → utils/crypto | 282-300 |
| `_load_username_email_map()` | `loadUsernameEmailMap()` → localStorage | 302-320 |
| `_save_username_email_map()` | `saveUsernameEmailMap()` → localStorage | 322-340 |

### Dosya 28: `src/stores/usePlayerStore.ts`

**Kaynak:** `autoload/StateStore.gd` (801 satır)

**State:**
| GDScript Variable | TypeScript State | Satır |
|---|---|---|
| `player: Dictionary` | `player: PlayerProfile \| null` | 13 |
| `current_energy: int = 100` | `currentEnergy: number` | 14 |
| `max_energy: int = 100` | `maxEnergy: number` | 15 |
| `tolerance: int = 0` | `tolerance: number` | 16 |
| `gold: int = 0` | `gold: number` | 17 |
| `gems: int = 0` | `gems: number` | 18 |
| `level: int = 1` | `level: number` | 19 |
| `xp: int = 0` | `xp: number` | 20 |
| `next_level_xp: int = 1000` | `nextLevelXp: number` | 21 |
| `pvp_rating: int = 1000` | `pvpRating: number` | 22 |
| `pvp_wins: int = 0` | `pvpWins: number` | 23 |
| `pvp_losses: int = 0` | `pvpLosses: number` | 24 |
| `inventory: Array = []` | *(ayrı store: useInventoryStore)* | — |
| `equipped_items: Dictionary = {}` | *(ayrı store: useInventoryStore)* | — |
| `active_quests: Array = []` | `activeQuests: QuestData[]` | — |
| `completed_quests: Array = []` | `completedQuests: string[]` | — |
| `market_ticker: Array = []` | *(ayrı store: useMarketStore)* | — |
| `guild_info: Dictionary = {}` | `guildInfo: GuildData \| null` | — |
| `guild_members: Array = []` | `guildMembers: GuildMemberData[]` | — |
| `reputation: int = 0` | `reputation: number` | — |
| `in_hospital: bool = false` | `inHospital: boolean` | — |
| `hospital_release_time: float = 0` | `hospitalReleaseTime: number` | — |
| `hospital_reason: String = ""` | `hospitalReason: string` | — |
| `in_prison: bool = false` | `inPrison: boolean` | — |
| `prison_release_time: float = 0` | `prisonReleaseTime: number` | — |
| `prison_reason: String = ""` | `prisonReason: string` | — |
| `settings: Dictionary = {}` | `settings: Record<string, any>` | — |

**Actions** (Tümü StateStore.gd'den satır satır taşınacak):
`loadPlayerData`, `updateEnergy`, `consumeEnergy`, `updateTolerance`, `updateGold`, `updateGems`, `updatePlayerData`, `calculateNextLevelXp`, `setActiveQuests`, `addQuest`, `completeQuest`, `setGuildInfo`, `setGuildMembers`, `setHospitalStatus`, `getHospitalRemainingMinutes`, `getHospitalRemainingSeconds`, `checkHospitalStatus`, `setPrisonStatus`, `getPrisonRemainingMinutes`, `getPrisonRemainingSeconds`, `checkPrisonStatus`, `setSetting`, `getSetting`, `clearState`, `fetchPlayerProfile`, `syncToSupabase`

**Persist middleware:** `localStorage` üzerinden `player`, `gold`, `gems`, `level`, `settings` saklanacak

### Dosya 29: `src/stores/useInventoryStore.ts`

**Kaynak:** `autoload/InventoryManager.gd` (547 satır)

**State:** `items: InventoryItem[]`, `isLoading`, `capacity = 20`

**Actions (tamamı):**
| GDScript Function | TypeScript Action | Kaynak Satır |
|---|---|---|
| `fetch_inventory()` | `fetchInventory()` | 41-80 |
| `add_item(item)` | `addItem(item)` | 83-125 |
| `add_item_by_id(id, qty)` | `addItemById(id, qty)` | 127-155 |
| `remove_item(id, qty)` | `removeItem(id, qty)` | 157-195 |
| `remove_item_by_row_id(row_id, qty)` | `removeItemByRowId(rowId, qty)` | 197-235 |
| `use_item(item)` | `useItem(item)` | 237-270 |
| `equip_item(id)` | `equipItem(id)` | 272-310 |
| `unequip_item(slot)` | `unequipItem(slot)` | 312-340 |
| `move_item_to_slot(item, pos)` | `moveItemToSlot(item, pos)` | 342-358 |
| `batch_update_positions(items)` | `batchUpdatePositions(items)` | 360-395 |
| `update_item_enhancement(item, level)` | `updateItemEnhancement(item, level)` | 397-420 |
| `get_capacity()` | `getCapacity()` → 20 | 422 |
| `get_current_size()` | `getCurrentSize()` | 424 |
| `is_inventory_full()` | `isInventoryFull()` | 428 |
| `get_items_by_type(type)` | `getItemsByType(type)` | 432 |
| `get_equipped_item(slot)` | `getEquippedItem(slot)` | 445 |
| `is_slot_equipped(slot)` | `isSlotEquipped(slot)` | 455 |
| `get_total_value()` | `getTotalValue()` | 465 |
| `get_item_quantity(id)` | `getItemQuantity(id)` | 475 |
| `_find_first_empty_slot()` | `findFirstEmptySlot()` | 485-500 |
| `_ensure_slot_positions()` | `ensureSlotPositions()` | 502-520 |

### Dosya 30: `src/stores/useFacilityStore.ts`

**Kaynak:** `autoload/FacilityManager.gd` (1231 satır)

**Bu en büyük store. İçerecekleri:**
- `cachedFacilities`, `cachedRecipes`, `lastCacheTime`, `cacheDuration=60`, `selectedFacilityType`, `selectedFacilityData`
- Tüm RPC wrapper'ları (15+ fonksiyon)
- `calculateIdleResources()` — Deterministic RNG ile offline kaynak hesaplama (FacilityManager.gd satır 750-900)
- `getRarityChancesAtLevel(level)` — Level bazlı rarity dağılım hesaplama
- `getGlobalSuspicionRisk()` — Global risk formülü: `(active_count × 5) + floor(level_sum × 0.5)`
- Bribe Timestamp Filter system — `last_bribe_at` kontrolü

### Dosya 31: `src/stores/useCraftingStore.ts`

**Kaynak:** `autoload/CraftingManager.gd` (169 satır)

**State:** `currentRecipes`, `productionQueue`, `isSyncing`
**Sabitler:** `BATCH_LIMIT=5`, `QUEUE_LIMIT=10`
**Actions:** `loadAllRecipes`, `craftItem`, `claimItem`, `getProductionQueue`, `getQueueCount`, `isQueueFull`, `findQueueItem`, `calculateMaterialsNeeded`, `getTotalProductionTime`

### Dosya 32: `src/stores/useMarketStore.ts`

**Kaynak:** `core/managers/PazarManager.gd`

**State:** `listings`, `myOrders`, `marketTicker`, `filters`
**Actions:** `fetchListings`, `createOrder`, `cancelOrder`, `getMyOrders`, `refreshTicker`

### Dosya 33: `src/stores/useAudioStore.ts`

**Kaynak:** `autoload/AudioManager.gd` (214 satır)

**Howler.js entegrasyonu:**
- Music tracks: `menu_theme.ogg`, `gameplay_ambient.ogg`, `combat_theme.ogg`, `town_ambient.ogg`
- SFX: `button_click.ogg`, `success.ogg`, `error.ogg`, `coin.ogg`, `item_pickup.ogg`, `potion_drink.ogg`, `notification.ogg`, `sword_swing.ogg`, `hit.ogg`
- Actions: `playMusic`, `stopMusic`, `playSfx`, `playButtonClick`, `playSuccess`, `playError`, `playCoin`, `playItemPickup`, `playPotionDrink`, `playNotification`, `playSwordSwing`, `playHit`, `setMusicVolume`, `setSfxVolume`
- Fade transition desteği (Howler fade API)
- Volume persistence → localStorage

### Dosya 34: `src/stores/useConfigStore.ts`

**Kaynak:** `autoload/ConfigManager.gd` (222 satır)

- Remote config fetch + local fallback
- Cache TTL: 3600 saniye (config_cache_ttl)
- Getters: `getEnergyConfig`, `getPotionConfig`, `getPvpConfig`, `getMarketConfig`, `getQuestConfig`, `getGuildConfig`, `getMonetizationConfig`, `isFeatureEnabled`, `isMaintenanceMode`

---

## Faz 4: Custom Hooks — Manager Karşılıkları

### Dosya 35: `src/hooks/useEnergy.ts`
**Kaynak:** `core/managers/EnergyManager.gd`
- `calculateRegeneration()` → `regen_interval: 180s`, `regen_rate: 1`
- `consumeEnergy(amount)` → validate + update player store
- `refillWithGems()` → 50 gem, günlük 5 limit
- `getTimeUntilNextRegen()` → countdown logic
- `useEffect` ile auto-regen timer

### Dosya 36: `src/hooks/usePotion.ts`
**Kaynak:** `core/managers/PotionManager.gd`
- `consumePotion(potion)` → tolerance += tolerance_increase
- `calculateOverdoseRisk()` → threshold: 0.8, base_risk: 0.05
- `calculateToleranceDecay()` → decay_rate: 1, decay_interval: 21600s
- `isOverdosed()` → kontrol + hastane yönlendirmesi
- Tolerance decay timer

### Dosya 37: `src/hooks/usePvP.ts`
**Kaynak:** `core/managers/PvPManager.gd`
- `findTargets()` → RPC call
- `attackPlayer(targetId)` → energy_cost: 15, gold_steal: 5%
- `calculateWinChance(attacker, defender)` → power diff formula
- `getPvPHistory()`

### Dosya 38: `src/hooks/useDungeon.ts`
**Kaynak:** `core/managers/DungeonManager.gd`
- `enterDungeon(id, difficulty)` → energy cost, success rate
- `getDungeonList()` → available dungeons
- `calculateSuccessChance()` → gear: 0.20, skill: 0.15, level: 0.10, difficulty: 0.15, danger: 0.10
- `getRewards()`

### Dosya 39: `src/hooks/useGuild.ts`
**Kaynak:** `core/managers/GuildManager.gd`
- `createGuild()` → 10000 gold cost
- `joinGuild()`, `leaveGuild()`, `kickMember()`, `promoteAsMember()`
- `getGuildInfo()`, `getGuildMembers()`

### Dosya 40: `src/hooks/useHospital.ts`
**Kaynak:** `core/managers/HospitalManager.gd`
- `getRemainingTime()` → countdown from `hospital_until`
- `instantRelease(gems)` → 3 gem/dakika
- `admitPatient()`, `releasePatient()`

### Dosya 41: `src/hooks/usePrison.ts`
**Kaynak:** `core/managers/PrisonManager.gd`
- `getPrisonStatus()` → `prison_until`, `prison_reason`
- `getRemainingTime()` → countdown
- `attemptBailout(gems)` → gem cost hesaplama

### Dosya 42: `src/hooks/useEnhancement.ts`
**Kaynak:** `core/managers/EnhancementManager.gd`
- `enhanceItem(itemId, scrollId?, runeId?)`
- `calculateSuccessRate(level)` → `[1.0, 1.0, 1.0, 1.0, 0.8, 0.8, 0.6, 0.6, 0.4, 0.2, 0.1]`
- `calculateDestructionRate(level)` → `[0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.05, 0.1, 0.15]`
- `getEnhancementCost(level)` → scroll_cost_multiplier

### Dosya 43: `src/hooks/useShop.ts`
**Kaynak:** `core/managers/ShopManager.gd`
- `buyItem()`, `sellItem()`, `getShopItems()`, `getDailyDeals()`

### Dosya 44: `src/hooks/useQuest.ts`
**Kaynak:** `core/managers/QuestManager.gd`
- `getActiveQuests()`, `acceptQuest()`, `completeQuest()`, `abandonQuest()`
- Max active quests: 10

### Dosya 45: `src/hooks/useChat.ts`
**Kaynak:** `core/managers/ChatManager.gd`
- Supabase Realtime ile real-time chat
- `subscribeToChannel()`, `sendMessage()`, `getHistory()`
- Rate limit: 10 msg/dakika

### Dosya 46: `src/hooks/useSeason.ts`
**Kaynak:** `core/managers/SeasonManager.gd`
- `getCurrentSeason()`, `getLeaderboard()`, `getBattlePassProgress()`
- Season duration: 90 gün

---

## Faz 5: Telemetri + Request Queue

### Dosya 47: `src/lib/telemetry.ts`
**Kaynak:** `autoload/TelemetryClient.gd` (209 satır)

20+ tracking fonksiyonu: `trackEvent`, `trackScreen`, `trackButtonClick`, `trackGoldEarned`, `trackGoldSpent`, `trackGemSpent`, `trackLevelUp`, `trackQuestCompleted`, `trackPvPInitiated`, `trackPvPCompleted`, `trackGuildJoined`, `trackChatMessageSent`, `trackPurchaseInitiated`, `trackPurchaseCompleted`, `trackError`, `trackPurchase`, `trackQuest`, `trackPvP`, `trackPotionUsage`, `trackMarket`, `trackAuth`, `trackEnhancement`

### Dosya 48: `src/lib/requestQueue.ts`
**Kaynak:** `autoload/RequestQueue.gd` (147 satır)

- IndexedDB / localStorage tabanlı offline queue
- Priority sorting
- `enqueue()`, `processQueue()`, `clearQueue()`
- Network online/offline listener ile otomatik retry

---

## Faz 6: Layout + Navigation

### Dosya 49: `src/app/layout.tsx`
**Kaynak:** Root level — Supabase auth listener, providers, meta tags

### Dosya 50: `src/app/(auth)/layout.tsx`
- Authenticated kullanıcıyı `/home` yönlendir

### Dosya 51: `src/app/(game)/layout.tsx`
**Kaynak:** `SceneManager.gd` + `Main.gd`
- TopBar + BottomNav wrapper
- Prison guard: `if inPrison && path !== '/prison' → redirect('/prison')`
- Framer Motion `AnimatePresence` ile page transitions (SceneManager.gd fade logic)
- Auth guard: redirect to `/login` if not authenticated

### Dosya 52: `src/components/layout/TopBar.tsx`
**Kaynak:** `scenes/ui/components/TopBar.gd`
- Oyuncu adı, seviye, altın, gem gösterimi
- EnergyBar + ToleranceBar bileşenleri

### Dosya 53: `src/components/layout/BottomNav.tsx`
**Kaynak:** `scenes/ui/components/BottomNav.gd`
- 16 route mapping (SceneManager.gd SCENES dict):
  - splash → (yok, sadece ilk yükleme)
  - login → `/login`
  - home → `/home`
  - inventory → `/inventory`
  - market → `/market`
  - quest → `/quests`
  - dungeon → `/dungeon`
  - pvp → `/pvp`
  - guild → `/guild`
  - profile → `/profile`
  - settings → `/settings`
  - hospital → `/hospital`
  - prison → `/prison`
  - facilities → `/facilities`
  - facility_detail → `/facilities` (modal olarak)

---

## Faz 7: Auth Sayfaları

### Dosya 54: `src/app/(auth)/login/page.tsx`
**Kaynak:** `SessionManager.gd` `login()` (satır 47-108) + Login UI
- Username→email çözümleme (`_username_email_map`)
- Error handling: invalid credentials, network error

### Dosya 55: `src/app/(auth)/register/page.tsx`
**Kaynak:** `SessionManager.gd` `register()` (satır 110-169)
- Email, username, password, referral code formu
- Validation: `isValidEmail`, `isValidUsername`, `isValidPassword`

### Dosya 56: `src/components/auth/AuthGuard.tsx`
- Supabase `onAuthStateChange` listener
- Token validation + profile fetch

---

## Faz 8: Home Sayfası

### Dosya 57: `src/app/(game)/home/page.tsx`
**Kaynak:** `scenes/main/Main.gd` home ekranı

### Dosya 58: `src/components/home/PlayerSummaryCard.tsx`
- Seviye, güç, PvP rating özet kartı

---

## Faz 9: Envanter + Ekipman

### Dosya 59: `src/app/(game)/inventory/page.tsx`
**Kaynak:** Envanter ekranı — 20 slot grid

### Dosya 60: `src/components/inventory/InventoryGrid.tsx`
**Kaynak:** `InventoryManager.gd` 20-slot grid mantığı

### Dosya 61: `src/components/inventory/ItemSlot.tsx`
**Kaynak:** `scenes/prefabs/ItemSlot.gd`
- Rarity border rengi, quantity badge, enhancement level badge

### Dosya 62: `src/components/inventory/ItemCard.tsx`
**Kaynak:** `scenes/prefabs/ItemCard.gd`

### Dosya 63: `src/components/inventory/ItemDetailPopup.tsx`
**Kaynak:** `scenes/ui/components/ItemDetailPopup.gd`
- Framer Motion slide-up animasyonu

### Dosya 64: `src/app/(game)/equipment/page.tsx`
**Kaynak:** `core/managers/EquipmentManager.gd`

### Dosya 65: `src/components/equipment/CharacterPaperdoll.tsx`
**Kaynak:** `scenes/ui/components/CharacterPaperdoll.gd`
- 19 katmanlı PNG stack → CSS `position: absolute` ile üst üste

### Dosya 66: `src/components/equipment/EquipmentSlot.tsx`
**Kaynak:** `scenes/ui/components/EquipmentSlot.gd`
- 8 slot: WEAPON, CHEST, HEAD, LEGS, BOOTS, GLOVES, RING, NECKLACE

---

## Faz 10: Tesisler (Facilities)

### Dosya 67: `src/app/(game)/facilities/page.tsx`
**Kaynak:** `scenes/FacilitiesScreen.gd`
- 15 tesis grid, global risk bar, prison redirect

### Dosya 68: `src/components/facilities/FacilityCard.tsx`
**Kaynak:** `scenes/components/FacilityCard.gd`

### Dosya 69: `src/components/facilities/DetailModal.tsx`
**Kaynak:** `scenes/components/DetailModal.gd`
- Framer Motion slide-up + backdrop blur

### Dosya 70: `src/components/facilities/ProductionQueueItem.tsx`
**Kaynak:** `scenes/prefabs/ProductionQueueItem.gd`

### Dosya 71: `src/components/facilities/SuspicionBar.tsx`
- Global risk formülü: `(active_count × 5) + floor(level_sum × 0.5)`

### Dosya 72: `src/components/facilities/BribeButton.tsx`
- Gem cost gösterimi, cooldown, confirm dialog

### Dosya 73: `src/components/facilities/UnlockFacilityCard.tsx`
- Kilitli tesis kartı: gerekli level + gold cost

---

## Faz 11: Crafting (Üretim Atölyesi)

### Dosya 74: `src/app/(game)/crafting/page.tsx`
**Kaynak:** `CraftingManager.gd`

### Dosya 75: `src/components/crafting/RecipeCard.tsx`

### Dosya 76: `src/components/crafting/BatchSelector.tsx`
- 1-5 batch, gem maliyeti: `(batch - 1)` gem

### Dosya 77: `src/components/crafting/CraftingQueue.tsx`
- Kalan süre countdown, "Topla" butonu

---

## Faz 12: Market (Pazar)

### Dosya 78: `src/app/(game)/market/page.tsx`
**Kaynak:** `core/managers/PazarManager.gd`

### Dosya 79: `src/components/market/PazarTradeView.tsx`
**Kaynak:** `scenes/ui/components/PazarTradeView.gd`

### Dosya 80: `src/components/market/PazarFilterPanel.tsx`
**Kaynak:** `scenes/ui/components/PazarFilterPanel.gd`

### Dosya 81: `src/components/market/ListingRow.tsx`
**Kaynak:** `scenes/ui/components/ListingRow.gd`

### Dosya 82: `src/components/market/MyOrderRow.tsx`
**Kaynak:** `scenes/ui/components/MyOrderRow.gd`

---

## Faz 13: PvP + Dungeon + Hospital + Prison + Guild

### Dosya 83: `src/app/(game)/pvp/page.tsx`
### Dosya 84: `src/components/pvp/PvPTargetCard.tsx`
**Kaynak:** `scenes/prefabs/PvPTargetCard.gd`

### Dosya 85: `src/app/(game)/dungeon/page.tsx`
### Dosya 86: `src/components/dungeon/RewardCard.tsx`
**Kaynak:** `scenes/prefabs/RewardCard.gd`

### Dosya 87: `src/app/(game)/hospital/page.tsx`
**Kaynak:** `HospitalManager.gd`

### Dosya 88: `src/app/(game)/prison/page.tsx`
**Kaynak:** `PrisonManager.gd` — geri sayım, neden gösterimi

### Dosya 89: `src/app/(game)/guild/page.tsx`
### Dosya 90: `src/components/guild/GuildMemberCard.tsx`
**Kaynak:** `scenes/prefabs/GuildMemberCard.gd`

---

## Faz 14: Görevler + Sohbet + Ayarlar + Profil + Mağaza

### Dosya 91: `src/app/(game)/quests/page.tsx`
### Dosya 92: `src/components/quests/QuestCard.tsx`
**Kaynak:** `scenes/prefabs/QuestCard.gd`

### Dosya 93: `src/app/(game)/chat/page.tsx`
- Supabase Realtime ile real-time mesajlaşma

### Dosya 94: `src/app/(game)/settings/page.tsx`
- Müzik/SFX volume sliders, bildirim ayarları, hesap bilgileri

### Dosya 95: `src/app/(game)/profile/page.tsx`
- İstatistikler, başarımlar, oyuncu bilgileri

### Dosya 96: `src/app/(game)/shop/page.tsx`
- Gem paket listesi (6 paket: 0.99$-99.99$)
- `GemPackageCard.gd` karşılığı

---

## Faz 15: VFX + Enhancement + Shared UI

### Dosya 97: `src/components/vfx/UpgradeResultEffect.tsx`
**Kaynak:** `scenes/vfx/UpgradeResultEffect.gd`
- Colors: SUCCESS = `#FFD84A`, FAIL = `#FF3A3A`, BLESSED = `#7FD6FF`
- Framer Motion: scale, glow, particle burst, pulse

### Dosya 98: `src/components/ui/EnergyBar.tsx`
**Kaynak:** `scenes/ui/components/EnergyBar.gd`
- Progressive bar, regen countdown, color: `rgb(51, 204, 255)` (energy_color)

### Dosya 99: `src/components/ui/ToleranceBar.tsx`
**Kaynak:** `scenes/ui/components/ToleranceBar.gd`
- 0-100 scale, color gradient (green→yellow→red)

### Dosya 100: `src/components/ui/RarityBadge.tsx`
- Rarity renk kodlaması (dark_theme.tres'den):
  - common: `#E6E6E6` → `rgb(230, 230, 230)`
  - uncommon: `#33CC33` → `rgb(51, 204, 51)`
  - rare: `#4D80FF` → `rgb(77, 128, 255)`
  - epic: `#9933CC` → `rgb(153, 51, 204)`
  - legendary: `#FF8000` → `rgb(255, 128, 0)`
  - mythic: `#FF3333` → `rgb(255, 51, 51)`

### Dosya 101: `src/components/dialogs/ConfirmDialog.tsx`
- Generic confirm modal: başlık, mesaj, onay/iptal butonları
- Framer Motion fade + scale

### Dosya 102: `src/components/dialogs/ResultDialog.tsx`
- İşlem sonucu: başarı/hata ikonu, mesaj, otomatik kapanma

---

## Faz 16: Leaderboard + Diğer Prefab'lar

### Dosya 103: `src/components/shared/LeaderboardRow.tsx`
**Kaynak:** `scenes/prefabs/LeaderboardRow.gd`

### Dosya 104: `src/components/shared/OfferCard.tsx`
**Kaynak:** `scenes/prefabs/OfferCard.gd`

---

## Faz 17: Capacitor Build Pipeline

### Dosya 105: `capacitor.config.ts` *(Faz 0'da oluşturuldu)*

### Dosya 106: `scripts/build-mobile.sh`

```bash
#!/bin/bash
set -e

echo "Building Next.js static export..."
npm run build

echo "Syncing with Capacitor..."
npx cap sync

echo "Opening native IDE..."
if [ "$1" == "ios" ]; then
  npx cap open ios
elif [ "$1" == "android" ]; then
  npx cap open android
else
  echo "Usage: ./build-mobile.sh [ios|android]"
fi
```

### Dosya 107: `src/lib/capacitor.ts`

```typescript
import { Capacitor } from '@capacitor/core';

export const isNative = Capacitor.isNativePlatform();
export const platform = Capacitor.getPlatform(); // 'web' | 'ios' | 'android'

// Haptic feedback (native only)
export async function hapticFeedback(style: 'light' | 'medium' | 'heavy' = 'light') {
  if (!isNative) return;
  const { Haptics } = await import('@capacitor/haptics');
  // ... impact style
}

// Status bar (native only)
export async function setStatusBarDark() {
  if (!isNative) return;
  const { StatusBar, Style } = await import('@capacitor/status-bar');
  await StatusBar.setStyle({ style: Style.Dark });
  await StatusBar.setBackgroundColor({ color: '#1a1a2e' });
}
```

---

## Faz 18: Tailwind Tema + Global Stiller

### Dosya 108: `tailwind.config.ts`

**Kaynak:** `resources/themes/dark_theme.tres` + `main_theme.tres`

```typescript
import type { Config } from 'tailwindcss';

const config: Config = {
  content: ['./src/**/*.{ts,tsx}'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        // dark_theme.tres renkleri (Godot Color → hex dönüşümü)
        gkk: {
          // Base
          'bg-dark': '#1a1a1f',       // bg_dark: Color(0.1, 0.1, 0.12)
          'bg-medium': '#26262e',     // bg_medium: Color(0.15, 0.15, 0.18)
          'bg-light': '#33333d',      // bg_light: Color(0.2, 0.2, 0.24)
          'border': '#4D4D59',        // border_color: Color(0.3, 0.3, 0.35)
          // Accent
          'accent': '#6633CC',        // accent_color: Color(0.4, 0.2, 0.8)
          'error': '#CC3333',         // error_color: Color(0.8, 0.2, 0.2)
          'success': '#33CC4D',       // success_color: Color(0.2, 0.8, 0.3)
          'warning': '#E6B333',       // warning_color: Color(0.9, 0.7, 0.2)
          // Text
          'text-primary': '#F2F2F2',  // text_primary: Color(0.95, 0.95, 0.95)
          'text-secondary': '#B3B3B3',// text_secondary: Color(0.7, 0.7, 0.7)
          'text-disabled': '#666666', // text_disabled: Color(0.4, 0.4, 0.4)
          // Game UI
          'energy': '#33CCFF',        // energy_color: Color(0.2, 0.8, 1.0)
          'health': '#CC3333',        // health_color: Color(0.8, 0.2, 0.2)
          'gold': '#FFD700',          // gold_color: Color(1.0, 0.84, 0.0)
          'gem': '#804DFF',           // gem_color: Color(0.5, 0.3, 1.0)
          // Rarity
          'rarity-common': '#E6E6E6',    // rarity_common: Color(0.9, 0.9, 0.9)
          'rarity-uncommon': '#33CC33',  // rarity_uncommon: Color(0.2, 0.8, 0.2)
          'rarity-rare': '#4D80FF',      // rarity_rare: Color(0.3, 0.5, 1.0)
          'rarity-epic': '#9933CC',      // rarity_epic: Color(0.6, 0.2, 0.8)
          'rarity-legendary': '#FF8000', // rarity_legendary: Color(1.0, 0.5, 0.0)
          'rarity-mythic': '#FF3333',    // rarity_mythic: Color(1.0, 0.2, 0.2)
        },
        // main_theme.tres Button renkleri
        btn: {
          'normal': '#334059',        // ButtonNormal bg: Color(0.2, 0.25, 0.35)
          'hover': '#4D5973',         // ButtonHover bg: Color(0.3, 0.35, 0.45)
          'pressed': '#26334D',       // ButtonPressed bg: Color(0.15, 0.2, 0.3)
          'disabled': '#262626',      // ButtonDisabled bg: Color(0.15, 0.15, 0.15)
          'border-normal': '#668099', // Button border: Color(0.4, 0.5, 0.6)
          'border-hover': '#99B3CC',  // Button hover border: Color(0.6, 0.7, 0.8)
        },
      },
      // VFX Colors
      // UpgradeResultEffect.gd renkleri
      // SUCCESS: #FFD84A, FAIL: #FF3A3A, BLESSED: #7FD6FF
      borderRadius: {
        'gkk': '10px',   // PanelStyle corner_radius: 10
        'btn': '8px',    // ButtonNormal corner_radius: 8
      },
      fontFamily: {
        'game': ['Inter', 'system-ui', 'sans-serif'],
      },
    },
  },
  plugins: [],
};

export default config;
```

### Dosya 109: `src/app/globals.css`

```css
@import 'tailwindcss';

:root {
  /* Safe area insets for Capacitor */
  --safe-area-top: env(safe-area-inset-top, 0px);
  --safe-area-bottom: env(safe-area-inset-bottom, 0px);
  --safe-area-left: env(safe-area-inset-left, 0px);
  --safe-area-right: env(safe-area-inset-right, 0px);

  /* Rarity glow shadows */
  --glow-common: 0 0 8px rgba(230, 230, 230, 0.3);
  --glow-uncommon: 0 0 8px rgba(51, 204, 51, 0.4);
  --glow-rare: 0 0 10px rgba(77, 128, 255, 0.5);
  --glow-epic: 0 0 12px rgba(153, 51, 204, 0.5);
  --glow-legendary: 0 0 14px rgba(255, 128, 0, 0.6);
  --glow-mythic: 0 0 16px rgba(255, 51, 51, 0.7);
}

body {
  background-color: #1a1a1f;
  color: #f2f2f2;
  font-family: 'Inter', system-ui, sans-serif;
  font-size: 16px; /* main_theme.tres default_font_size: 16 */
  
  /* Prevent pull-to-refresh in Capacitor */
  overscroll-behavior: none;
  
  /* Safe area padding */
  padding-top: var(--safe-area-top);
  padding-bottom: var(--safe-area-bottom);
}

/* Custom scrollbar (dark theme) */
::-webkit-scrollbar { width: 6px; }
::-webkit-scrollbar-track { background: #1a1a1f; }
::-webkit-scrollbar-thumb { background: #4D4D59; border-radius: 3px; }
::-webkit-scrollbar-thumb:hover { background: #668099; }

/* Selection color */
::selection { background: rgba(102, 51, 204, 0.3); }
```

---

## Dosya-Dosya Eşleme Tablosu

### Autoload Singletons → Zustand Stores + Lib

| GDScript Dosyası | Satır | → TypeScript Dosyası | Tür |
|---|---|---|---|
| `autoload/NetworkManager.gd` | 408 | `src/lib/supabase.ts` + `src/lib/api.ts` | lib |
| `autoload/SessionManager.gd` | 438 | `src/stores/useSessionStore.ts` | store |
| `autoload/StateStore.gd` | 801 | `src/stores/usePlayerStore.ts` | store |
| `autoload/RequestQueue.gd` | 147 | `src/lib/requestQueue.ts` | lib |
| `autoload/TelemetryClient.gd` | 209 | `src/lib/telemetry.ts` | lib |
| `autoload/AudioManager.gd` | 214 | `src/stores/useAudioStore.ts` | store |
| `autoload/SceneManager.gd` | 179 | Next.js App Router (built-in) | framework |
| `autoload/ConfigManager.gd` | 222 | `src/stores/useConfigStore.ts` | store |
| `autoload/InventoryManager.gd` | 547 | `src/stores/useInventoryStore.ts` | store |
| `autoload/FacilityManager.gd` | 1231 | `src/stores/useFacilityStore.ts` | store |
| `autoload/CraftingManager.gd` | 169 | `src/stores/useCraftingStore.ts` | store |

### Core Managers → Custom Hooks

| GDScript Dosyası | → TypeScript Dosyası |
|---|---|
| `core/managers/EnergyManager.gd` | `src/hooks/useEnergy.ts` |
| `core/managers/PotionManager.gd` | `src/hooks/usePotion.ts` |
| `core/managers/PvPManager.gd` | `src/hooks/usePvP.ts` |
| `core/managers/DungeonManager.gd` | `src/hooks/useDungeon.ts` |
| `core/managers/GuildManager.gd` | `src/hooks/useGuild.ts` |
| `core/managers/HospitalManager.gd` | `src/hooks/useHospital.ts` |
| `core/managers/PrisonManager.gd` | `src/hooks/usePrison.ts` |
| `core/managers/EnhancementManager.gd` | `src/hooks/useEnhancement.ts` |
| `core/managers/ShopManager.gd` | `src/hooks/useShop.ts` |
| `core/managers/QuestManager.gd` | `src/hooks/useQuest.ts` |
| `core/managers/ChatManager.gd` | `src/hooks/useChat.ts` |
| `core/managers/SeasonManager.gd` | `src/hooks/useSeason.ts` |
| `core/managers/PazarManager.gd` | `src/stores/useMarketStore.ts` |
| `core/managers/EquipmentManager.gd` | `src/hooks/useEquipment.ts` (inventory store içinde) |
| `core/managers/ProductionManager.gd` | `src/stores/useFacilityStore.ts` (facility store içinde) |

### Core Data → Types

| GDScript Dosyası | → TypeScript Dosyası |
|---|---|
| `core/data/PlayerData.gd` | `src/types/player.ts` |
| `core/data/ItemData.gd` | `src/types/item.ts` |
| `core/data/InventoryItemData.gd` | `src/types/inventory.ts` |
| `core/data/DungeonData.gd` | `src/types/dungeon.ts` |
| `core/data/DungeonInstance.gd` | `src/types/dungeon.ts` |
| `core/data/GuildData.gd` | `src/types/guild.ts` |
| `core/data/GuildMemberData.gd` | `src/types/guild.ts` |
| `core/data/PvPData.gd` | `src/types/pvp.ts` |
| `core/data/QuestData.gd` | `src/types/quest.ts` |
| `core/data/ItemDatabase.gd` | `src/data/ItemDatabase.ts` |

### Core Network → Supabase Client

| GDScript Dosyası | → TypeScript Dosyası |
|---|---|
| `core/network/APIEndpoints.gd` | `src/lib/api.ts` (sabitler) |
| `core/network/HTTPClient.gd` | `src/lib/supabase.ts` (Supabase JS) |
| `core/network/RequestBuilder.gd` | `src/lib/supabase.ts` (Supabase JS) |
| `core/network/WebSocketClient.gd` | `src/lib/realtime.ts` |

### Core Utils → Lib Utils

| GDScript Dosyası | → TypeScript Dosyası |
|---|---|
| `core/utils/MathUtils.gd` | `src/lib/utils/math.ts` |
| `core/utils/DateTimeUtils.gd` | `src/lib/utils/datetime.ts` |
| `core/utils/StringUtils.gd` | `src/lib/utils/string.ts` |
| `core/utils/ValidationUtils.gd` | `src/lib/utils/validation.ts` |
| `core/utils/CryptoUtils.gd` | `src/lib/utils/crypto.ts` |

### Scene Scripts → React Components / Pages

| GDScript Dosyası | → TypeScript Dosyası |
|---|---|
| `scenes/main/Main.gd` | `src/app/(game)/home/page.tsx` |
| `scenes/FacilitiesScreen.gd` | `src/app/(game)/facilities/page.tsx` |
| `scenes/components/FacilityCard.gd` | `src/components/facilities/FacilityCard.tsx` |
| `scenes/components/DetailModal.gd` | `src/components/facilities/DetailModal.tsx` |
| `scenes/prefabs/ItemCard.gd` | `src/components/inventory/ItemCard.tsx` |
| `scenes/prefabs/ItemSlot.gd` | `src/components/inventory/ItemSlot.tsx` |
| `scenes/prefabs/ChatMessage.gd` | `src/app/(game)/chat/page.tsx` (inline) |
| `scenes/prefabs/GemPackageCard.gd` | `src/app/(game)/shop/page.tsx` (inline) |
| `scenes/prefabs/GuildMemberCard.gd` | `src/components/guild/GuildMemberCard.tsx` |
| `scenes/prefabs/LeaderboardRow.gd` | `src/components/shared/LeaderboardRow.tsx` |
| `scenes/prefabs/OfferCard.gd` | `src/components/shared/OfferCard.tsx` |
| `scenes/prefabs/ProductionQueueItem.gd` | `src/components/facilities/ProductionQueueItem.tsx` |
| `scenes/prefabs/PvPTargetCard.gd` | `src/components/pvp/PvPTargetCard.tsx` |
| `scenes/prefabs/QuestCard.gd` | `src/components/quests/QuestCard.tsx` |
| `scenes/prefabs/RewardCard.gd` | `src/components/dungeon/RewardCard.tsx` |
| `scenes/ui/components/TopBar.gd` | `src/components/layout/TopBar.tsx` |
| `scenes/ui/components/BottomNav.gd` | `src/components/layout/BottomNav.tsx` |
| `scenes/ui/components/EnergyBar.gd` | `src/components/ui/EnergyBar.tsx` |
| `scenes/ui/components/ToleranceBar.gd` | `src/components/ui/ToleranceBar.tsx` |
| `scenes/ui/components/CharacterPaperdoll.gd` | `src/components/equipment/CharacterPaperdoll.tsx` |
| `scenes/ui/components/EquipmentSlot.gd` | `src/components/equipment/EquipmentSlot.tsx` |
| `scenes/ui/components/ItemDetailPopup.gd` | `src/components/inventory/ItemDetailPopup.tsx` |
| `scenes/ui/components/PazarTradeView.gd` | `src/components/market/PazarTradeView.tsx` |
| `scenes/ui/components/PazarFilterPanel.gd` | `src/components/market/PazarFilterPanel.tsx` |
| `scenes/ui/components/ListingRow.gd` | `src/components/market/ListingRow.tsx` |
| `scenes/ui/components/MyOrderRow.gd` | `src/components/market/MyOrderRow.tsx` |
| `scenes/ui/components/ChatPanel.gd` | `src/app/(game)/chat/page.tsx` |
| `scenes/ui/components/BlacksmithSlot.gd` | `src/components/equipment/EquipmentSlot.tsx` (birleşik) |
| `scenes/vfx/UpgradeResultEffect.gd` | `src/components/vfx/UpgradeResultEffect.tsx` |

### Tema / Konfigürasyon

| Godot Dosyası | → TypeScript Dosyası |
|---|---|
| `resources/themes/dark_theme.tres` | `tailwind.config.ts` (renkler) |
| `resources/themes/main_theme.tres` | `tailwind.config.ts` (buton stilleri) |
| `resources/configs/game_config.json` | `src/data/GameConstants.ts` |
| `resources/items/items_database.json` | `src/data/ItemDatabase.ts` |
| `resources/quests/quests_database.json` | `src/data/QuestDatabase.ts` |

---

## Backend Durumu (Değişmeyecek)

Aşağıdaki dosyalar **hiç değişmeyecek** — aynen kalacak:

### Supabase Edge Functions (19 dosya)
- `supabase/functions/auth-login/index.ts`
- `supabase/functions/auth-register/index.ts`
- `supabase/functions/get_player_facilities/index.ts`
- `supabase/functions/unlock_facility/index.ts`
- `supabase/functions/start_facility_production/index.ts`
- `supabase/functions/collect_facility_production/index.ts`
- `supabase/functions/upgrade_facility/index.ts`
- `supabase/functions/get_facility_recipes/index.ts`
- `supabase/functions/calculate_offline_production/index.ts`
- `supabase/functions/facilities/index.ts`
- `supabase/functions/increment_facility_suspicion/index.ts`
- `supabase/functions/reduce_facility_suspicion/index.ts`
- `supabase/functions/bribe_officials/index.ts`
- `supabase/functions/hospital-admit/index.ts`
- `supabase/functions/hospital-release/index.ts`
- `supabase/functions/energy/index.ts`
- `supabase/functions/player-profile/index.ts`
- (+ duplikat `auth_login`, `auth_register` dizinleri)

### SQL Migrations (~70 dosya)
- `supabase/migrations/*.sql`
- `database/migrations/*.sql`
- Tüm RPC fonksiyonları, trigger'lar, RLS policy'leri aynen kalır

### Supabase Config
- `supabase/config.toml` — aynen kalır
- `.github/workflows/deploy-supabase.yml` — aynen kalır

---

## Test Stratejisi

### Unit Tests (Vitest)
```
src/__tests__/
├── stores/
│   ├── useSessionStore.test.ts
│   ├── usePlayerStore.test.ts
│   ├── useInventoryStore.test.ts
│   ├── useFacilityStore.test.ts
│   └── useCraftingStore.test.ts
├── hooks/
│   ├── useEnergy.test.ts
│   ├── usePotion.test.ts
│   └── useEnhancement.test.ts
├── lib/
│   └── utils/
│       ├── math.test.ts
│       ├── datetime.test.ts
│       └── validation.test.ts
└── data/
    ├── ItemDatabase.test.ts
    └── FacilityConfig.test.ts
```

### Integration Tests
- Login → Profile fetch → Home render
- Inventory fetch → Equip item → Stats update
- Facility production → Collection → Suspicion update
- Craft queue → Claim → Inventory update

### Manuel Test Checklist
- [ ] Login/Register akışı
- [ ] 20-slot envanter grid (drag & drop dahil)
- [ ] 15 tesis grid, üretim, toplama, risk barı, rüşvet
- [ ] Crafting: tarif, batch, gem maliyet, kuyruk
- [ ] Market: listeleme, satın alma, sipariş
- [ ] PvP: hedef bul, saldır, sonuç animasyonu
- [ ] Hospital/Prison: geri sayım, anında çıkış
- [ ] Capacitor iOS build + test
- [ ] Capacitor Android build + test

---

## CI/CD Pipeline

### GitHub Actions — Web Deploy (Vercel)

```yaml
# .github/workflows/deploy-web.yml
name: Deploy Web
on:
  push:
    branches: [main]
    paths: ['gkk-web/**']

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: cd gkk-web && npm ci
      - run: cd gkk-web && npm run build
      - uses: amondnet/vercel-action@v25
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
          working-directory: gkk-web
```

### Mevcut Supabase Deploy (değişmeyecek)
- `.github/workflows/deploy-supabase.yml` — aynen kalır

---

## Uygulama Sırası

```
Faz 0  → Proje scaffolding (4 dosya)                        ▓░░░░░░░░░
Faz 1  → Supabase + Types (18 dosya)                        ▓▓░░░░░░░░
Faz 2  → Data layer (4 dosya)                               ▓▓▓░░░░░░░
Faz 3  → Zustand stores (8 dosya)                           ▓▓▓▓░░░░░░
Faz 4  → Custom hooks (12 dosya)                            ▓▓▓▓▓░░░░░
Faz 5  → Telemetri + Queue (2 dosya)                        ▓▓▓▓▓░░░░░
Faz 6  → Layout + Nav (5 dosya)                             ▓▓▓▓▓▓░░░░
Faz 7  → Auth (3 dosya)                                     ▓▓▓▓▓▓░░░░
Faz 8  → Home (2 dosya)                                     ▓▓▓▓▓▓▓░░░
Faz 9  → Envanter + Ekipman (8 dosya)                       ▓▓▓▓▓▓▓░░░
Faz 10 → Tesisler (7 dosya)                                 ▓▓▓▓▓▓▓▓░░
Faz 11 → Crafting (4 dosya)                                 ▓▓▓▓▓▓▓▓░░
Faz 12 → Market (5 dosya)                                   ▓▓▓▓▓▓▓▓░░
Faz 13 → PvP/Dungeon/Hospital/Prison/Guild (8 dosya)        ▓▓▓▓▓▓▓▓▓░
Faz 14 → Quest/Chat/Settings/Profile/Shop (6 dosya)         ▓▓▓▓▓▓▓▓▓░
Faz 15 → VFX + Shared UI (6 dosya)                          ▓▓▓▓▓▓▓▓▓▓
Faz 16 → Leaderboard + Diğer (2 dosya)                      ▓▓▓▓▓▓▓▓▓▓
Faz 17 → Capacitor pipeline (3 dosya)                       ▓▓▓▓▓▓▓▓▓▓
Faz 18 → Tema + Global CSS (2 dosya)                        ▓▓▓▓▓▓▓▓▓▓
```

---

## Önemli Notlar

1. **Backend HİÇ değişmeyecek** — Tüm SQL, Edge Function, migration dosyaları aynen kalır
2. **Asset'ler kopyalanacak** — `assets/sprites/` → `public/assets/sprites/`, `assets/audio/` → `public/assets/audio/`
3. **Supabase project ID:** `znvsyzstmxhqvdkkmgdt`
4. **Supabase schema:** `game` (config.toml'de `schemas = ["public", "graphql_public", "game"]`)
5. **19-layer character sprite** CSS `position: absolute` ile stack edilecek, canvas'a gerek yok
6. **Service role key** ASLA frontend'e konmayacak — sadece `anon` key
7. **Static export** → `next build` → `out/` dizini → Capacitor `webDir: 'out'`
8. **Her faz bağımsız test edilebilir** — Faz 0-3 tamamlandığında store'lar çalışır, Faz 6-7'de login akışı test edilir
