// ============================================================
// Audio Store — Kaynak: AudioManager.gd (214 satır)
// Howler.js ile müzik crossfade, SFX pool, convenience wrappers
// ============================================================

import { create } from "zustand";
import { persist } from "zustand/middleware";
import { Howl, Howler } from "howler";

// ── Music tracks (paths under /audio/music/) ──
const MUSIC_TRACKS: Record<string, string> = {
  menu: "/audio/music/menu_theme.ogg",
  gameplay: "/audio/music/gameplay_ambient.ogg",
  combat: "/audio/music/combat_theme.ogg",
  town: "/audio/music/town_ambient.ogg",
};

// ── SFX registry (paths under /audio/sfx/) ──
const SFX_REGISTRY: Record<string, string> = {
  button_click: "/audio/sfx/button_click.ogg",
  success: "/audio/sfx/success.ogg",
  error: "/audio/sfx/error.ogg",
  coin: "/audio/sfx/coin.ogg",
  item_pickup: "/audio/sfx/item_pickup.ogg",
  potion_drink: "/audio/sfx/potion_drink.ogg",
  notification: "/audio/sfx/notification.ogg",
  sword_swing: "/audio/sfx/sword_swing.ogg",
  hit: "/audio/sfx/hit.ogg",
};

const SFX_POOL_SIZE = 10;

// Runtime Howl instances (not persisted)
let musicHowl: Howl | null = null;
const sfxCache: Map<string, Howl> = new Map();
let activeSfxCount = 0;

interface AudioState {
  // Persisted state
  musicVolume: number;
  sfxVolume: number;
  isMuted: boolean;
  currentTrack: string | null;

  // Actions
  setMusicVolume: (volume: number) => void;
  setSfxVolume: (volume: number) => void;
  toggleMute: () => void;
  setCurrentTrack: (track: string | null) => void;

  // Playback
  playMusic: (track: string, fadeDuration?: number) => void;
  stopMusic: (fadeDuration?: number) => void;
  playSfx: (name: string, volume?: number, rate?: number) => void;

  // Convenience wrappers (match Godot AudioManager)
  playButtonClick: () => void;
  playSuccess: () => void;
  playError: () => void;
  playCoin: () => void;
  playItemPickup: () => void;
  playPotionDrink: () => void;
  playNotification: () => void;
  playSwordSwing: () => void;
  playHit: () => void;
}

export const useAudioStore = create<AudioState>()(
  persist(
    (set, get) => ({
      musicVolume: 0.3,
      sfxVolume: 0.5,
      isMuted: false,
      currentTrack: null,

      setMusicVolume: (volume: number) => {
        set({ musicVolume: volume });
        if (musicHowl) musicHowl.volume(volume);
      },
      setSfxVolume: (volume: number) => {
        set({ sfxVolume: volume });
      },
      toggleMute: () => {
        const muted = !get().isMuted;
        set({ isMuted: muted });
        Howler.mute(muted);
      },
      setCurrentTrack: (track: string | null) => set({ currentTrack: track }),

      // ── Music with crossfade ──
      playMusic: (track: string, fadeDuration = 1000) => {
        const { currentTrack, musicVolume, isMuted } = get();
        if (track === currentTrack && musicHowl?.playing()) return;

        const src = MUSIC_TRACKS[track];
        if (!src) {
          console.warn("[Audio] Music not found:", track);
          return;
        }

        // Fade out current
        if (musicHowl) {
          const old = musicHowl;
          old.fade(old.volume(), 0, fadeDuration);
          setTimeout(() => { old.stop(); old.unload(); }, fadeDuration + 50);
        }

        // Create new Howl and fade in
        musicHowl = new Howl({
          src: [src],
          loop: true,
          volume: 0,
          html5: true,
        });
        if (isMuted) Howler.mute(true);
        musicHowl.play();
        musicHowl.fade(0, musicVolume, fadeDuration);
        set({ currentTrack: track });
      },

      stopMusic: (fadeDuration = 1000) => {
        if (!musicHowl) return;
        const h = musicHowl;
        h.fade(h.volume(), 0, fadeDuration);
        setTimeout(() => { h.stop(); h.unload(); }, fadeDuration + 50);
        musicHowl = null;
        set({ currentTrack: null });
      },

      // ── SFX with pool limit ──
      playSfx: (name: string, volume?: number, rate?: number) => {
        const { sfxVolume, isMuted } = get();
        if (isMuted) return;
        if (activeSfxCount >= SFX_POOL_SIZE) return; // pool full

        const src = SFX_REGISTRY[name];
        if (!src) {
          console.warn("[Audio] SFX not found:", name);
          return;
        }

        let howl = sfxCache.get(name);
        if (!howl) {
          howl = new Howl({ src: [src], volume: volume ?? sfxVolume });
          sfxCache.set(name, howl);
        }
        howl.volume(volume ?? sfxVolume);
        if (rate) howl.rate(rate);

        activeSfxCount++;
        const id = howl.play();
        howl.once("end", () => { activeSfxCount = Math.max(0, activeSfxCount - 1); }, id);
      },

      // ── Convenience wrappers ──
      playButtonClick: () => get().playSfx("button_click"),
      playSuccess: () => get().playSfx("success"),
      playError: () => get().playSfx("error", 0.3),
      playCoin: () => get().playSfx("coin"),
      playItemPickup: () => get().playSfx("item_pickup"),
      playPotionDrink: () => get().playSfx("potion_drink"),
      playNotification: () => get().playSfx("notification", 0.35),
      playSwordSwing: () => get().playSfx("sword_swing", undefined, 0.9 + Math.random() * 0.2),
      playHit: () => get().playSfx("hit", undefined, 0.95 + Math.random() * 0.1),
    }),
    {
      name: "gkk-audio",
      partialize: (state) => ({
        musicVolume: state.musicVolume,
        sfxVolume: state.sfxVolume,
        isMuted: state.isMuted,
      }),
    }
  )
);
