// ============================================================
// Telemetry Client — Kaynak: TelemetryClient.gd (198 satır)
// Batched event tracking, session management
// ============================================================

import { supabase } from "./supabase";

interface TelemetryEvent {
  event_name: string;
  properties: Record<string, unknown>;
  timestamp: string;
  session_id: string;
}

let sessionId = "";
let eventBuffer: TelemetryEvent[] = [];
let flushTimer: ReturnType<typeof setInterval> | null = null;
const FLUSH_INTERVAL = 30_000; // 30 seconds
const MAX_BUFFER_SIZE = 50;
const IS_DEV = process.env.NODE_ENV === "development";

function getSessionId(): string {
  if (!sessionId) {
    sessionId = `${Date.now()}-${Math.random().toString(36).slice(2, 9)}`;
  }
  return sessionId;
}

export function initTelemetry(): void {
  if (flushTimer) return;
  flushTimer = setInterval(flushEvents, FLUSH_INTERVAL);
}

export function stopTelemetry(): void {
  if (flushTimer) {
    clearInterval(flushTimer);
    flushTimer = null;
  }
  flushEvents();
}

export function trackEvent(
  eventName: string,
  properties: Record<string, unknown> = {}
): void {
  if (IS_DEV) {
    console.debug("[Telemetry]", eventName, properties);
    return;
  }

  eventBuffer.push({
    event_name: eventName,
    properties,
    timestamp: new Date().toISOString(),
    session_id: getSessionId(),
  });

  if (eventBuffer.length >= MAX_BUFFER_SIZE) {
    flushEvents();
  }
}

async function flushEvents(): Promise<void> {
  if (eventBuffer.length === 0 || IS_DEV) return;

  const events = [...eventBuffer];
  eventBuffer = [];

  try {
    await supabase.from("telemetry_events").insert(events);
  } catch (err) {
    console.error("[Telemetry] Flush failed:", err);
    // Re-add events to buffer on failure
    eventBuffer.unshift(...events);
  }
}

// Specialized trackers — TelemetryClient.gd karşılıkları
export function trackScreen(screenName: string): void {
  trackEvent("screen_view", { screen: screenName });
}

export function trackButtonClick(buttonName: string, context?: string): void {
  trackEvent("button_click", { button: buttonName, context });
}

export function trackGoldEarned(amount: number, source: string): void {
  trackEvent("economy_gold_earned", { amount, source });
}

export function trackGoldSpent(amount: number, target: string): void {
  trackEvent("economy_gold_spent", { amount, target });
}

export function trackGemSpent(amount: number, target: string): void {
  trackEvent("economy_gem_spent", { amount, target });
}

export function trackLevelUp(newLevel: number): void {
  trackEvent("progression_level_up", { level: newLevel });
}

export function trackQuestCompleted(questId: string, difficulty: string): void {
  trackEvent("quest_completed", { quest_id: questId, difficulty });
}

export function trackPvPInitiated(targetId: string): void {
  trackEvent("pvp_initiated", { target_id: targetId });
}

export function trackPvPCompleted(
  result: "win" | "loss",
  ratingChange: number
): void {
  trackEvent("pvp_completed", { result, rating_change: ratingChange });
}

export function trackGuildJoined(guildId: string): void {
  trackEvent("guild_joined", { guild_id: guildId });
}

export function trackChatMessageSent(channel: string): void {
  trackEvent("chat_message_sent", { channel });
}

export function trackPurchaseInitiated(packId: string, price: number): void {
  trackEvent("purchase_initiated", { pack_id: packId, price });
}

export function trackPurchaseCompleted(packId: string, price: number): void {
  trackEvent("purchase_completed", { pack_id: packId, price });
}

export function trackError(errorType: string, message: string): void {
  trackEvent("error", { type: errorType, message });
}

export function trackPotionUsage(
  potionId: string,
  result: "success" | "overdose",
  details?: Record<string, unknown>
): void {
  trackEvent("potion_usage", { potion_id: potionId, result, ...details });
}

export function trackMarket(
  action: "buy" | "sell" | "cancel",
  itemId: string,
  quantity: number,
  price: number
): void {
  trackEvent("market_action", { action, item_id: itemId, quantity, price });
}

export function trackAuth(action: "login" | "register" | "logout"): void {
  trackEvent("auth", { action });
}

export function trackEnhancement(
  itemId: string,
  level: number,
  result: "success" | "fail" | "destroy"
): void {
  trackEvent("enhancement", { item_id: itemId, level, result });
}
