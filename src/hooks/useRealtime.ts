// ============================================================
// useRealtime — Supabase Realtime subscription hook
// Kaynak: NetworkManager.gd WebSocket system
// ============================================================

"use client";

import { useEffect, useRef } from "react";
import type { RealtimeChannel } from "@supabase/supabase-js";
import { subscribeToTable, unsubscribe } from "@/lib/realtime";

interface UseRealtimeOptions {
  table: string;
  schema?: string;
  event?: "INSERT" | "UPDATE" | "DELETE" | "*";
  filter?: string;
  enabled?: boolean;
  onData: (payload: unknown) => void;
}

export function useRealtime({
  table,
  schema = "public",
  event = "*",
  filter,
  enabled = true,
  onData,
}: UseRealtimeOptions) {
  const channelRef = useRef<RealtimeChannel | null>(null);
  const onDataRef = useRef(onData);
  onDataRef.current = onData;

  useEffect(() => {
    if (!enabled) return;

    const channelName = `${schema}:${table}:${event}:${filter || "all"}`;

    channelRef.current = subscribeToTable(
      table,
      schema,
      event,
      (payload) => onDataRef.current(payload),
      filter
    );

    return () => {
      unsubscribe(channelName);
      channelRef.current = null;
    };
  }, [table, schema, event, filter, enabled]);
}
