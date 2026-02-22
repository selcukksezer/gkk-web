// ============================================================
// useAudio — Howler.js ses yönetimi hook'u
// Kaynak: AudioManager.gd (214 satır)
// ============================================================

"use client";

import { useRef, useCallback, useEffect } from "react";
import { Howl } from "howler";
import { useAudioStore } from "@/stores/audioStore";
import { MUSIC_TRACKS, SFX_TRACKS } from "@/data/AudioConfig";

const musicCache = new Map<string, Howl>();
const sfxCache = new Map<string, Howl>();

function getOrCreateHowl(
  key: string,
  src: string,
  loop: boolean,
  volume: number
): Howl {
  const cache = loop ? musicCache : sfxCache;
  if (cache.has(key)) return cache.get(key)!;

  const howl = new Howl({
    src: [src],
    loop,
    volume,
    preload: true,
  });
  cache.set(key, howl);
  return howl;
}

export function useAudio() {
  const { musicVolume, sfxVolume, isMuted, setCurrentTrack } = useAudioStore();
  const currentMusicRef = useRef<Howl | null>(null);

  // Update volumes when settings change
  useEffect(() => {
    musicCache.forEach((howl) => {
      howl.volume(isMuted ? 0 : musicVolume);
    });
    sfxCache.forEach((howl) => {
      howl.volume(isMuted ? 0 : sfxVolume);
    });
  }, [musicVolume, sfxVolume, isMuted]);

  const playMusic = useCallback(
    (key: string) => {
      const track = MUSIC_TRACKS.find((t) => t.key === key);
      if (!track) return;

      // Stop current music
      if (currentMusicRef.current) {
        currentMusicRef.current.fade(
          currentMusicRef.current.volume(),
          0,
          500
        );
        setTimeout(() => currentMusicRef.current?.stop(), 500);
      }

      const howl = getOrCreateHowl(key, track.src, true, isMuted ? 0 : musicVolume);
      howl.play();
      currentMusicRef.current = howl;
      setCurrentTrack(key);
    },
    [musicVolume, isMuted, setCurrentTrack]
  );

  const stopMusic = useCallback(() => {
    if (currentMusicRef.current) {
      currentMusicRef.current.fade(
        currentMusicRef.current.volume(),
        0,
        500
      );
      setTimeout(() => {
        currentMusicRef.current?.stop();
        currentMusicRef.current = null;
      }, 500);
    }
    setCurrentTrack(null);
  }, [setCurrentTrack]);

  const playSfx = useCallback(
    (key: string) => {
      const track = SFX_TRACKS.find((t) => t.key === key);
      if (!track) return;

      const howl = getOrCreateHowl(key, track.src, false, isMuted ? 0 : sfxVolume);
      howl.play();
    },
    [sfxVolume, isMuted]
  );

  // Convenience methods matching AudioManager.gd signals
  const playButtonClick = useCallback(() => playSfx("button_click"), [playSfx]);
  const playItemPickup = useCallback(() => playSfx("item_pickup"), [playSfx]);
  const playItemEquip = useCallback(() => playSfx("item_equip"), [playSfx]);
  const playCraftSuccess = useCallback(() => playSfx("craft_success"), [playSfx]);
  const playCraftFail = useCallback(() => playSfx("craft_fail"), [playSfx]);
  const playLevelUp = useCallback(() => playSfx("level_up"), [playSfx]);
  const playReward = useCallback(() => playSfx("reward"), [playSfx]);
  const playError = useCallback(() => playSfx("error"), [playSfx]);
  const playNotification = useCallback(() => playSfx("notification"), [playSfx]);

  return {
    playMusic,
    stopMusic,
    playSfx,
    playButtonClick,
    playItemPickup,
    playItemEquip,
    playCraftSuccess,
    playCraftFail,
    playLevelUp,
    playReward,
    playError,
    playNotification,
  };
}
