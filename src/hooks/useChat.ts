// ============================================================
// useChat — Sohbet sistemi hook'u
// Kaynak: ChatManager.gd (264 satır)
// ============================================================

"use client";

import { useState, useCallback, useRef, useEffect } from "react";
import { useUiStore } from "@/stores/uiStore";
import { api } from "@/lib/api";
import { APIEndpoints } from "@/lib/endpoints";
import { useRealtime } from "./useRealtime";

export type ChatChannel = "global" | "guild" | "dm" | "trade" | "system";

export interface ChatMessage {
  id: string;
  channel: ChatChannel;
  sender_id: string;
  sender_name: string;
  content: string;
  timestamp: string;
  is_system: boolean;
}

const MAX_MESSAGE_LENGTH = 200;
const RATE_LIMIT_MS = 2000;
const MAX_HISTORY = 100;

// Basic profanity filter (Turkish + English)
const PROFANITY_PATTERN = /\b(küfür|bok|sik|amk|orospu|fuck|shit|bitch|ass)\b/gi;

export function useChat() {
  const [messages, setMessages] = useState<Record<ChatChannel, ChatMessage[]>>({
    global: [],
    guild: [],
    dm: [],
    trade: [],
    system: [],
  });
  const [activeChannel, setActiveChannel] = useState<ChatChannel>("global");
  const [mutedPlayers, setMutedPlayers] = useState<Set<string>>(new Set());
  const [blockedPlayers, setBlockedPlayers] = useState<Set<string>>(new Set());
  const lastMessageTime = useRef(0);
  const addToast = useUiStore((s) => s.addToast);

  /** Profanity filter */
  const filterProfanity = useCallback(
    (text: string): string => text.replace(PROFANITY_PATTERN, "***"),
    []
  );

  /** Realtime subscription for chat messages */
  useRealtime({
    table: "chat_messages",
    schema: "game",
    event: "INSERT",
    enabled: true,
    onData: (payload) => {
      const record = (payload as { new: Record<string, unknown> }).new;
      if (!record) return;

      const msg: ChatMessage = {
        id: record.id as string,
        channel: (record.channel as ChatChannel) ?? "global",
        sender_id: record.sender_id as string,
        sender_name: record.sender_name as string,
        content: filterProfanity(record.content as string),
        timestamp: record.created_at as string,
        is_system: (record.is_system as boolean) ?? false,
      };

      // Skip blocked/muted players
      if (blockedPlayers.has(msg.sender_id) || mutedPlayers.has(msg.sender_id)) return;

      setMessages((prev) => {
        const channel = prev[msg.channel] ?? [];
        const updated = [...channel, msg].slice(-MAX_HISTORY);
        return { ...prev, [msg.channel]: updated };
      });
    },
  });

  /** Load channel history from server */
  const loadHistory = useCallback(
    async (channel: ChatChannel, limit = 50) => {
      const res = await api.get<ChatMessage[]>(
        `${APIEndpoints.CHAT_HISTORY}?channel=${channel}&limit=${limit}`
      );
      if (res.success && res.data) {
        setMessages((prev) => ({
          ...prev,
          [channel]: res.data!.map((m) => ({
            ...m,
            content: filterProfanity(m.content),
          })),
        }));
      }
    },
    [filterProfanity]
  );

  // Load initial history
  useEffect(() => {
    loadHistory(activeChannel);
  }, [activeChannel, loadHistory]);

  /** Send a message */
  const sendMessage = useCallback(
    async (content: string, recipientId?: string): Promise<boolean> => {
      // Rate limit
      const now = Date.now();
      if (now - lastMessageTime.current < RATE_LIMIT_MS) {
        addToast("Çok hızlı yazıyorsunuz!", "warning");
        return false;
      }

      // Length check
      if (content.length > MAX_MESSAGE_LENGTH) {
        addToast(`Mesaj çok uzun (max ${MAX_MESSAGE_LENGTH} karakter)`, "warning");
        return false;
      }

      const filtered = filterProfanity(content.trim());
      if (!filtered) return false;

      const res = await api.post(APIEndpoints.CHAT_SEND, {
        channel: activeChannel,
        content: filtered,
        recipient_id: recipientId,
      });

      if (res.success) {
        lastMessageTime.current = now;
        return true;
      }
      addToast(res.error ?? "Mesaj gönderilemedi", "error");
      return false;
    },
    [activeChannel, filterProfanity, addToast]
  );

  /** Mute a player (local, time-based) */
  const mutePlayer = useCallback(
    (playerId: string) => {
      setMutedPlayers((prev) => new Set([...prev, playerId]));
      addToast("Oyuncu susturuldu", "info");
    },
    [addToast]
  );

  /** Unmute a player */
  const unmutePlayer = useCallback(
    (playerId: string) => {
      setMutedPlayers((prev) => {
        const next = new Set(prev);
        next.delete(playerId);
        return next;
      });
    },
    []
  );

  /** Block a player */
  const blockPlayer = useCallback(
    async (playerId: string): Promise<boolean> => {
      const res = await api.post(APIEndpoints.CHAT_BLOCK, {
        player_id: playerId,
      });
      if (res.success) {
        setBlockedPlayers((prev) => new Set([...prev, playerId]));
        addToast("Oyuncu engellendi", "info");
        return true;
      }
      return false;
    },
    [addToast]
  );

  /** Report a message */
  const reportMessage = useCallback(
    async (messageId: string, reason: string): Promise<boolean> => {
      const res = await api.post(APIEndpoints.CHAT_REPORT, {
        message_id: messageId,
        reason,
      });
      if (res.success) {
        addToast("Rapor gönderildi", "success");
        return true;
      }
      return false;
    },
    [addToast]
  );

  const currentMessages = messages[activeChannel] ?? [];

  return {
    messages,
    currentMessages,
    activeChannel,
    setActiveChannel,
    sendMessage,
    loadHistory,
    mutePlayer,
    unmutePlayer,
    blockPlayer,
    reportMessage,
    filterProfanity,
    MAX_MESSAGE_LENGTH,
  };
}
