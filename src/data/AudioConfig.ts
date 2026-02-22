// ============================================================
// Audio Configuration — Kaynak: AudioManager.gd
// Web'de Howler.js ile çalınacak
// ============================================================

export interface AudioTrack {
  key: string;
  src: string;
  loop: boolean;
  volume: number;
}

export const MUSIC_TRACKS: AudioTrack[] = [
  { key: "menu_theme", src: "/audio/music/menu_theme.mp3", loop: true, volume: 0.3 },
  { key: "game_theme", src: "/audio/music/game_theme.mp3", loop: true, volume: 0.3 },
  { key: "battle_theme", src: "/audio/music/battle_theme.mp3", loop: true, volume: 0.4 },
  { key: "dungeon_theme", src: "/audio/music/dungeon_theme.mp3", loop: true, volume: 0.3 },
];

export const SFX_TRACKS: AudioTrack[] = [
  { key: "button_click", src: "/audio/sfx/button_click.mp3", loop: false, volume: 0.5 },
  { key: "item_pickup", src: "/audio/sfx/item_pickup.mp3", loop: false, volume: 0.6 },
  { key: "item_equip", src: "/audio/sfx/item_equip.mp3", loop: false, volume: 0.5 },
  { key: "craft_success", src: "/audio/sfx/craft_success.mp3", loop: false, volume: 0.6 },
  { key: "craft_fail", src: "/audio/sfx/craft_fail.mp3", loop: false, volume: 0.5 },
  { key: "level_up", src: "/audio/sfx/level_up.mp3", loop: false, volume: 0.7 },
  { key: "reward", src: "/audio/sfx/reward.mp3", loop: false, volume: 0.6 },
  { key: "error", src: "/audio/sfx/error.mp3", loop: false, volume: 0.4 },
  { key: "notification", src: "/audio/sfx/notification.mp3", loop: false, volume: 0.5 },
];
