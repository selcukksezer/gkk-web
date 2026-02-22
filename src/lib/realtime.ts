// ============================================================
// Realtime Subscriptions — Kaynak: NetworkManager.gd WebSocket
// Supabase JS client handles WS internally
// ============================================================

import { supabase } from "./supabase";
import type { RealtimeChannel } from "@supabase/supabase-js";

const activeChannels = new Map<string, RealtimeChannel>();

export function subscribeToTable(
  table: string,
  schema: string = "public",
  event: "INSERT" | "UPDATE" | "DELETE" | "*" = "*",
  callback: (payload: unknown) => void,
  filter?: string
): RealtimeChannel {
  const channelName = `${schema}:${table}:${event}:${filter || "all"}`;

  // Avoid duplicate subscriptions
  if (activeChannels.has(channelName)) {
    return activeChannels.get(channelName)!;
  }

  let channel = supabase.channel(channelName);

  const config: {
    event: string;
    schema: string;
    table: string;
    filter?: string;
  } = {
    event,
    schema,
    table,
  };

  if (filter) {
    config.filter = filter;
  }

  channel = channel.on(
    "postgres_changes" as never, // Type workaround for supabase-js
    config as never,
    (payload: unknown) => callback(payload)
  );

  channel.subscribe();
  activeChannels.set(channelName, channel);

  return channel;
}

export function subscribeToPlayerChanges(
  playerId: string,
  callback: (payload: unknown) => void
): RealtimeChannel {
  return subscribeToTable(
    "users",
    "public",
    "UPDATE",
    callback,
    `id=eq.${playerId}`
  );
}

export function subscribeToInventoryChanges(
  playerId: string,
  callback: (payload: unknown) => void
): RealtimeChannel {
  return subscribeToTable(
    "inventory",
    "public",
    "*",
    callback,
    `player_id=eq.${playerId}`
  );
}

export function subscribeToMarketOrders(
  itemId: string,
  callback: (payload: unknown) => void
): RealtimeChannel {
  return subscribeToTable(
    "market_orders",
    "public",
    "*",
    callback,
    `item_id=eq.${itemId}`
  );
}

export function subscribeToGuildChat(
  guildId: string,
  callback: (payload: unknown) => void
): RealtimeChannel {
  return subscribeToTable(
    "guild_messages",
    "public",
    "INSERT",
    callback,
    `guild_id=eq.${guildId}`
  );
}

export function unsubscribe(channelName: string): void {
  const channel = activeChannels.get(channelName);
  if (channel) {
    supabase.removeChannel(channel);
    activeChannels.delete(channelName);
  }
}

export function unsubscribeAll(): void {
  activeChannels.forEach((channel) => {
    supabase.removeChannel(channel);
  });
  activeChannels.clear();
}
