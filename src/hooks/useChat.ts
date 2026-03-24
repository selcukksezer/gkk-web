// ============================================================
// useChat — Sohbet sistemi hook'u
// Kaynak: ChatManager.gd (264 satır)
// ============================================================

"use client";

import { useState, useCallback, useRef, useEffect } from "react";
import { useUiStore } from "@/stores/uiStore";
import { usePlayerStore } from "@/stores/playerStore";
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
  recipient_user_id?: string | null;
  guild_id?: string | null;
}

export interface ChatFilterEntry {
  id: string;
  term: string;
  replacement: string;
  channel: string | null;
  scope: "global" | "channel" | "guild";
  guild_id: string | null;
  created_at: string;
}

export interface ChatActiveBan {
  id: string;
  channel: string | null;
  scope: "global" | "channel" | "guild";
  reason: string;
  expires_at: string;
}

export interface ChatPermissions {
  can_delete: boolean;
  can_ban: boolean;
  can_manage_filters: boolean;
  can_manage_moderators: boolean;
}

export interface ChatModerationState {
  success: boolean;
  channel: ChatChannel;
  filters: ChatFilterEntry[];
  active_bans: ChatActiveBan[];
  permissions: ChatPermissions;
}

export interface ChatUserSummary {
  id: string;
  username: string;
  display_name: string | null;
}

export interface ChatDmConversation {
  peer_user_id: string;
  peer_username: string;
  peer_display_name: string | null;
  last_message_id: string;
  last_message_content: string;
  last_message_at: string;
  unread_count: number;
  last_sender_id: string;
}

type ChatActionResult = {
  success: boolean;
  error?: string;
};

const MAX_MESSAGE_LENGTH = 200;
const RATE_LIMIT_MS = 2000;
const MAX_HISTORY = 100;

const EMPTY_PERMISSIONS: ChatPermissions = {
  can_delete: false,
  can_ban: false,
  can_manage_filters: false,
  can_manage_moderators: false,
};

const EMPTY_MOD_STATE: ChatModerationState = {
  success: true,
  channel: "global",
  filters: [],
  active_bans: [],
  permissions: EMPTY_PERMISSIONS,
};

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
  const [moderationState, setModerationState] = useState<ChatModerationState>(EMPTY_MOD_STATE);
  const [isModerationLoading, setIsModerationLoading] = useState(false);
  const [dmConversations, setDmConversations] = useState<ChatDmConversation[]>([]);
  const [activeDmPeer, setActiveDmPeer] = useState<ChatUserSummary | null>(null);
  const [dmSearchResults, setDmSearchResults] = useState<ChatUserSummary[]>([]);
  const [isDmLoading, setIsDmLoading] = useState(false);
  const [isDmSearchLoading, setIsDmSearchLoading] = useState(false);
  const [guildUnreadCount, setGuildUnreadCount] = useState(0);
  const lastMessageTime = useRef(0);
  const addToast = useUiStore((s) => s.addToast);
  const player = usePlayerStore((state) => state.player);
  const currentUserId = player?.id ?? null;

  const sortDmConversations = useCallback(
    (items: ChatDmConversation[]) =>
      [...items].sort(
        (left, right) => new Date(right.last_message_at).getTime() - new Date(left.last_message_at).getTime()
      ),
    []
  );

  const loadDmConversations = useCallback(async () => {
    setIsDmLoading(true);
    try {
      const res = await api.get<ChatDmConversation[]>(APIEndpoints.CHAT_DM_CONVERSATIONS);
      if (res.success && res.data) {
        setDmConversations(
          sortDmConversations(
            res.data.map((conversation) => ({
              ...conversation,
              unread_count: Math.min(99, Number(conversation.unread_count ?? 0)),
            }))
          )
        );
        return true;
      }
      return false;
    } finally {
      setIsDmLoading(false);
    }
  }, [sortDmConversations]);

  const loadDmMessages = useCallback(async (peerUserId: string, limit = 50) => {
    const res = await api.get<ChatMessage[]>(
      `${APIEndpoints.CHAT_HISTORY}?channel=dm&peer_id=${encodeURIComponent(peerUserId)}&limit=${limit}`
    );

    if (res.success && res.data) {
      const dmMessages = (res.data ?? []).filter(
        (message) => !blockedPlayers.has(message.sender_id) && !mutedPlayers.has(message.sender_id)
      );
      setMessages((prev) => ({
        ...prev,
        dm: dmMessages,
      }));
      return true;
    }

    return false;
  }, [blockedPlayers, mutedPlayers]);

  const markDmConversationRead = useCallback(async (peerUserId: string) => {
    const res = await api.post<ChatActionResult>(APIEndpoints.CHAT_DM_READ, {
      peer_user_id: peerUserId,
    });

    if (res.success) {
      setDmConversations((prev) =>
        prev.map((conversation) =>
          conversation.peer_user_id === peerUserId
            ? { ...conversation, unread_count: 0 }
            : conversation
        )
      );
      return true;
    }

    return false;
  }, []);

  const searchDmUsers = useCallback(async (query: string, limit = 8) => {
    const trimmedQuery = query.trim();
    if (trimmedQuery.length < 2) {
      setDmSearchResults([]);
      return [] as ChatUserSummary[];
    }

    setIsDmSearchLoading(true);
    try {
      const res = await api.get<ChatUserSummary[]>(
        `${APIEndpoints.CHAT_DM_SEARCH}?query=${encodeURIComponent(trimmedQuery)}&limit=${limit}`
      );

      if (res.success && res.data) {
        setDmSearchResults(res.data);
        return res.data;
      }

      setDmSearchResults([]);
      return [];
    } finally {
      setIsDmSearchLoading(false);
    }
  }, []);

  const resolveDmRecipientByUsername = useCallback(
    async (username: string) => {
      const normalizedUsername = username.replace(/^@/, "").trim().toLowerCase();
      if (!normalizedUsername) return null;

      const results = await searchDmUsers(normalizedUsername, 10);
      return (
        results.find((candidate) => candidate.username.toLowerCase() === normalizedUsername) ?? null
      );
    },
    [searchDmUsers]
  );

  const openDmConversation = useCallback(
    async (peer: ChatUserSummary) => {
      setActiveChannel("dm");
      setActiveDmPeer(peer);
      await loadDmMessages(peer.id);
      await markDmConversationRead(peer.id);
      await loadDmConversations();
    },
    [loadDmConversations, loadDmMessages, markDmConversationRead]
  );

  const leaveDmConversation = useCallback(() => {
    setActiveDmPeer(null);
    setMessages((prev) => ({
      ...prev,
      dm: [],
    }));
  }, []);

  const upsertDmConversation = useCallback(
    (message: ChatMessage) => {
      if (!currentUserId) return;

      const isOwnMessage = message.sender_id === currentUserId;
      const peerUserId = isOwnMessage ? message.recipient_user_id : message.sender_id;
      if (!peerUserId) return;

      const isActiveThread = activeChannel === "dm" && activeDmPeer?.id === peerUserId;

      setDmConversations((prev) => {
        const existing = prev.find((conversation) => conversation.peer_user_id === peerUserId);
        const nextConversation: ChatDmConversation = existing
          ? {
              ...existing,
              last_message_id: message.id,
              last_message_content: message.content,
              last_message_at: message.timestamp,
              last_sender_id: message.sender_id,
              unread_count: isOwnMessage || isActiveThread ? 0 : Math.min(99, existing.unread_count + 1),
            }
          : {
              peer_user_id: peerUserId,
              peer_username: isOwnMessage
                ? activeDmPeer?.id === peerUserId
                  ? activeDmPeer.username
                  : "Oyuncu"
                : message.sender_name,
              peer_display_name: null,
              last_message_id: message.id,
              last_message_content: message.content,
              last_message_at: message.timestamp,
              unread_count: isOwnMessage || isActiveThread ? 0 : 1,
              last_sender_id: message.sender_id,
            };

        return sortDmConversations([
          nextConversation,
          ...prev.filter((conversation) => conversation.peer_user_id !== peerUserId),
        ]);
      });
    },
    [activeChannel, activeDmPeer, currentUserId, sortDmConversations]
  );

  /** Realtime subscription for chat messages */
  useRealtime({
    table: "chat_messages",
    schema: "public",
    event: "*",
    enabled: true,
    onData: (payload) => {
      const eventPayload = payload as {
        eventType?: "INSERT" | "UPDATE" | "DELETE";
        new?: Record<string, unknown>;
        old?: Record<string, unknown>;
      };
      const record = eventPayload.new;

      if (eventPayload.eventType === "UPDATE") {
        const oldRow = eventPayload.old;
        const newRow = eventPayload.new;
        const rowId = String(newRow?.id ?? oldRow?.id ?? "");
        const rowChannel = (newRow?.channel ?? oldRow?.channel ?? "global") as ChatChannel;

        if ((newRow?.deleted_at as string | null) || (oldRow?.deleted_at as string | null)) {
          setMessages((prev) => ({
            ...prev,
            [rowChannel]: (prev[rowChannel] ?? []).filter((message) => message.id !== rowId),
          }));
          if (rowChannel === "dm") {
            void loadDmConversations();
          }
        }
        return;
      }

      if (eventPayload.eventType !== "INSERT" || !record) return;

      const msg: ChatMessage = {
        id: String(record.id),
        channel: (record.channel as ChatChannel) ?? "global",
        sender_id: String(record.sender_user_id ?? record.sender_id),
        sender_name: String(record.sender_name ?? "Oyuncu"),
        content: String(record.content ?? ""),
        timestamp: String(record.created_at ?? new Date().toISOString()),
        is_system: Boolean(record.is_system),
        recipient_user_id: (record.recipient_user_id as string | null) ?? null,
        guild_id: (record.guild_id as string | null) ?? null,
      };

      if (blockedPlayers.has(msg.sender_id) || mutedPlayers.has(msg.sender_id)) return;

      if (msg.channel === "dm") {
        upsertDmConversation(msg);
        void loadDmConversations();

        const isOwnMessage = msg.sender_id === currentUserId;
        const peerUserId = isOwnMessage ? msg.recipient_user_id : msg.sender_id;

        if (activeDmPeer?.id === peerUserId) {
          setMessages((prev) => {
            const channelMessages = prev.dm ?? [];
            if (channelMessages.some((message) => message.id === msg.id)) {
              return prev;
            }

            return {
              ...prev,
              dm: [...channelMessages, msg].slice(-MAX_HISTORY),
            };
          });

          if (!isOwnMessage && peerUserId) {
            void markDmConversationRead(peerUserId);
          }
        }
        return;
      }

      if (msg.channel === "guild" && msg.sender_id !== currentUserId && activeChannel !== "guild") {
        setGuildUnreadCount((count) => Math.min(99, count + 1));
      }

      setMessages((prev) => {
        const channelMessages = prev[msg.channel] ?? [];
        if (channelMessages.some((message) => message.id === msg.id)) {
          return prev;
        }

        return {
          ...prev,
          [msg.channel]: [...channelMessages, msg].slice(-MAX_HISTORY),
        };
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
        const filteredMessages = res.data.filter(
          (message) => !blockedPlayers.has(message.sender_id) && !mutedPlayers.has(message.sender_id)
        );
        setMessages((prev) => ({
          ...prev,
          [channel]: filteredMessages,
        }));
        return true;
      }
      return false;
    },
    [blockedPlayers, mutedPlayers]
  );

  const loadModerationState = useCallback(
    async (channel: ChatChannel) => {
      setIsModerationLoading(true);
      try {
        const res = await api.get<ChatModerationState>(`${APIEndpoints.CHAT_MOD_STATE}?channel=${channel}`);
        if (res.success && res.data) {
          setModerationState(res.data);
          return true;
        }
        setModerationState({ ...EMPTY_MOD_STATE, channel });
        return false;
      } finally {
        setIsModerationLoading(false);
      }
    },
    []
  );

  // Load initial history
  useEffect(() => {
    if (activeChannel === "dm") {
      void Promise.all([loadModerationState(activeChannel), loadDmConversations()]);
      return;
    }

    void Promise.all([loadHistory(activeChannel), loadModerationState(activeChannel)]);
  }, [activeChannel, loadDmConversations, loadHistory, loadModerationState]);

  useEffect(() => {
    if (activeChannel !== "dm" || !activeDmPeer?.id) return;
    void (async () => {
      await loadDmMessages(activeDmPeer.id);
      await markDmConversationRead(activeDmPeer.id);
      await loadDmConversations();
    })();
  }, [activeChannel, activeDmPeer?.id, loadDmConversations, loadDmMessages, markDmConversationRead]);

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

      const trimmedContent = content.trim();
      if (!trimmedContent) return false;

      let targetChannel: ChatChannel = activeChannel;
      let targetContent = trimmedContent;
      let targetRecipientId = recipientId ?? null;

      if (activeChannel !== "dm") {
        const mentionMatch = trimmedContent.match(/^@([a-zA-Z0-9_.-]+)\s+([\s\S]+)$/);
        if (mentionMatch) {
          const recipient = await resolveDmRecipientByUsername(mentionMatch[1]);
          if (!recipient) {
            addToast("Bu kullanıcı adına ait oyuncu bulunamadı", "warning");
            return false;
          }

          targetChannel = "dm";
          targetRecipientId = recipient.id;
          targetContent = mentionMatch[2].trim();
        }
      }

      if (targetChannel === "dm") {
        targetRecipientId = targetRecipientId ?? activeDmPeer?.id ?? null;
        if (!targetRecipientId) {
          addToast("Özel mesaj için önce bir oyuncu seçin", "warning");
          return false;
        }

        if (blockedPlayers.has(targetRecipientId) || mutedPlayers.has(targetRecipientId)) {
          addToast("Bu oyuncu susturuldu/engellendiği için özel mesaj gönderemezsiniz", "warning");
          return false;
        }
      }

      const res = await api.post(APIEndpoints.CHAT_SEND, {
        channel: targetChannel,
        content: targetContent,
        recipient_id: targetRecipientId,
      });

      if (res.success) {
        lastMessageTime.current = now;
        if (targetChannel === "dm") {
          void loadDmConversations();
        }
        return true;
      }
      addToast(res.error ?? "Mesaj gönderilemedi", "error");
      return false;
    },
    [
      activeChannel,
      activeDmPeer?.id,
      addToast,
      blockedPlayers,
      loadDmConversations,
      mutedPlayers,
      resolveDmRecipientByUsername,
    ]
  );

  /** Mute a player (local, time-based) */
  const mutePlayer = useCallback(
    async (playerId: string): Promise<boolean> => {
      setMutedPlayers((prev) => new Set([...prev, playerId]));
      setBlockedPlayers((prev) => new Set([...prev, playerId]));

      const res = await api.post(APIEndpoints.CHAT_BLOCK, {
        player_id: playerId,
      });

      if (!res.success) {
        addToast("Oyuncu yerel olarak susturuldu, sunucu engeli uygulanamadı", "warning");
        return false;
      }

      addToast("Oyuncu susturuldu ve engellendi", "info");
      return true;
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

  const deleteMessage = useCallback(
    async (messageId: string, reason?: string): Promise<boolean> => {
      const res = await api.post(APIEndpoints.CHAT_MOD_DELETE, {
        message_id: messageId,
        reason,
      });

      if (!res.success) {
        addToast(res.error ?? "Mesaj silinemedi", "error");
        return false;
      }

      setMessages((prev) => ({
        ...prev,
        [activeChannel]: (prev[activeChannel] ?? []).filter((message) => message.id !== messageId),
      }));
      addToast("Mesaj silindi", "success");
      return true;
    },
    [activeChannel, addToast]
  );

  const banPlayer = useCallback(
    async (playerId: string, durationMinutes: number, reason: string): Promise<boolean> => {
      const res = await api.post(APIEndpoints.CHAT_MOD_BAN, {
        target_user_id: playerId,
        channel: activeChannel,
        duration_minutes: durationMinutes,
        reason,
      });

      if (!res.success) {
        addToast(res.error ?? "Oyuncu banlanamadı", "error");
        return false;
      }

      addToast("Oyuncu geçici olarak sohbetten uzaklaştırıldı", "success");
      return true;
    },
    [activeChannel, addToast]
  );

  const createFilter = useCallback(
    async (term: string, replacement: string): Promise<boolean> => {
      const res = await api.post(APIEndpoints.CHAT_MOD_FILTERS, {
        channel: activeChannel,
        term,
        replacement,
      });

      if (!res.success) {
        addToast(res.error ?? "Filtre eklenemedi", "error");
        return false;
      }

      addToast("Filtre eklendi", "success");
      await loadModerationState(activeChannel);
      return true;
    },
    [activeChannel, addToast, loadModerationState]
  );

  const deleteFilter = useCallback(
    async (filterId: string): Promise<boolean> => {
      const res = await api.del(`${APIEndpoints.CHAT_MOD_FILTERS}?filter_id=${encodeURIComponent(filterId)}`);

      if (!res.success) {
        addToast(res.error ?? "Filtre silinemedi", "error");
        return false;
      }

      addToast("Filtre silindi", "success");
      await loadModerationState(activeChannel);
      return true;
    },
    [activeChannel, addToast, loadModerationState]
  );

  const assignModerator = useCallback(
    async (targetUserId: string): Promise<boolean> => {
      const res = await api.post(APIEndpoints.CHAT_MOD_ASSIGN, {
        target_user_id: targetUserId,
        channel: activeChannel,
      });

      if (!res.success) {
        addToast(res.error ?? "Moderator atanamadı", "error");
        return false;
      }

      addToast("Moderator atandı", "success");
      await loadModerationState(activeChannel);
      return true;
    },
    [activeChannel, addToast, loadModerationState]
  );

  const currentMessages = messages[activeChannel] ?? [];
  const currentDmMessages = messages.dm ?? [];
  const canModerate = moderationState.permissions.can_delete || moderationState.permissions.can_ban;
  const activeBan = moderationState.active_bans.find((ban) =>
    ban.scope === "global" || ban.channel === activeChannel || (activeChannel === "guild" && ban.scope === "guild")
  ) ?? null;
  const dmUnreadCount = dmConversations.reduce((total, conversation) => total + conversation.unread_count, 0);

  const clearGuildUnreadCount = useCallback(() => {
    setGuildUnreadCount(0);
  }, []);

  return {
    messages,
    currentMessages: activeChannel === "dm" ? currentDmMessages : currentMessages,
    activeChannel,
    setActiveChannel,
    sendMessage,
    loadHistory,
    loadDmConversations,
    dmConversations,
    activeDmPeer,
    setActiveDmPeer,
    openDmConversation,
    leaveDmConversation,
    dmSearchResults,
    isDmLoading,
    isDmSearchLoading,
    searchDmUsers,
    loadDmMessages,
    dmUnreadCount,
    guildUnreadCount,
    clearGuildUnreadCount,
    moderationState,
    isModerationLoading,
    loadModerationState,
    mutePlayer,
    unmutePlayer,
    blockPlayer,
    reportMessage,
    deleteMessage,
    banPlayer,
    createFilter,
    deleteFilter,
    assignModerator,
    canModerate,
    activeBan,
    MAX_MESSAGE_LENGTH,
  };
}
