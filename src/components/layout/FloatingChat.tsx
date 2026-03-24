"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { AnimatePresence, motion } from "framer-motion";
import { usePathname } from "next/navigation";
import {
  AlertTriangle,
  ChevronLeft,
  Crown,
  Flag,
  Gavel,
  MessageCircleMore,
  Radio,
  Search,
  ScrollText,
  SendHorizonal,
  ShieldBan,
  Swords,
  Trash2,
  Wallet,
  X,
} from "lucide-react";

import { useChat, type ChatChannel, type ChatMessage, type ChatPermissions, type ChatFilterEntry } from "@/hooks/useChat";
import { usePlayerStore } from "@/stores/playerStore";

const CHANNELS: Array<{
  key: ChatChannel;
  label: string;
  accent: string;
  description: string;
  icon: typeof Radio;
}> = [
  {
    key: "global",
    label: "Genel",
    accent: "rgba(56,189,248,0.92)",
    description: "Diyar akışı",
    icon: Radio,
  },
  {
    key: "guild",
    label: "Lonca",
    accent: "rgba(249,115,22,0.88)",
    description: "Takım koordinasyonu",
    icon: Swords,
  },
  {
    key: "trade",
    label: "Pazar",
    accent: "rgba(250,204,21,0.84)",
    description: "Alım satım",
    icon: Wallet,
  },
  {
    key: "dm",
    label: "Özel",
    accent: "rgba(168,85,247,0.82)",
    description: "Doğrudan mesaj",
    icon: ScrollText,
  },
];

const PANEL_EASE = [0.22, 1, 0.36, 1] as const;
const CHAT_PANEL = "rounded-3xl border border-white/10 bg-[linear-gradient(155deg,rgba(20,27,38,0.94),rgba(9,13,21,0.94))] shadow-[0_20px_40px_rgba(0,0,0,0.35)]";

export function FloatingChat() {
  const pathname = usePathname();
  const {
    currentMessages,
    activeChannel,
    setActiveChannel,
    sendMessage,
    mutePlayer,
    deleteMessage,
    banPlayer,
    assignModerator,
    createFilter,
    deleteFilter,
    reportMessage,
    moderationState,
    isModerationLoading,
    activeBan,
    dmConversations,
    activeDmPeer,
    openDmConversation,
    leaveDmConversation,
    dmSearchResults,
    isDmLoading,
    isDmSearchLoading,
    searchDmUsers,
    dmUnreadCount,
    guildUnreadCount,
    clearGuildUnreadCount,
    MAX_MESSAGE_LENGTH,
  } = useChat();
  const player = usePlayerStore((state) => state.player);

  const [isOpen, setIsOpen] = useState(false);
  const [input, setInput] = useState("");
  const [filterTerm, setFilterTerm] = useState("");
  const [filterReplacement, setFilterReplacement] = useState("***");
  const [dmSearch, setDmSearch] = useState("");
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const activeChannelMeta = useMemo(
    () => CHANNELS.find((channel) => channel.key === activeChannel) ?? CHANNELS[0],
    [activeChannel]
  );

  const canManageFilters = moderationState.permissions.can_manage_filters;
  const canManageModerators = moderationState.permissions.can_manage_moderators;
  const canDeleteMessages = moderationState.permissions.can_delete;
  const canBanPlayers = moderationState.permissions.can_ban;
  const showDmConversationList = activeChannel === "dm" && !activeDmPeer;
  const showDmThread = activeChannel === "dm" && Boolean(activeDmPeer);
  const totalUnreadBadge = guildUnreadCount + dmUnreadCount;

  useEffect(() => {
    setIsOpen(false);
  }, [pathname]);

  useEffect(() => {
    if (activeChannel !== "dm") {
      setDmSearch("");
      return;
    }

    if (dmSearch.trim().length < 2) return;
    const timeoutId = window.setTimeout(() => {
      void searchDmUsers(dmSearch);
    }, 180);

    return () => window.clearTimeout(timeoutId);
  }, [activeChannel, dmSearch, searchDmUsers]);

  useEffect(() => {
    if (isOpen) {
      clearGuildUnreadCount();
    }
  }, [clearGuildUnreadCount, isOpen]);

  useEffect(() => {
    if (!isOpen) return;
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth", block: "end" });
  }, [currentMessages.length, isOpen]);

  useEffect(() => {
    if (!isOpen) return;

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        setIsOpen(false);
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [isOpen]);

  const handleSend = useCallback(async () => {
    if (!input.trim()) return;
    const success = await sendMessage(input.trim());
    if (success) {
      setInput("");
    }
  }, [input, sendMessage]);

  const handleKeyDown = useCallback(
    async (event: React.KeyboardEvent<HTMLTextAreaElement>) => {
      if (event.key === "Enter" && !event.shiftKey) {
        event.preventDefault();
        await handleSend();
      }
    },
    [handleSend]
  );

  const handleQuickBan = useCallback(
    async (userId: string, userName: string) => {
      const durationInput = window.prompt(`${userName} için ban süresi kaç dakika olsun?`, "30");
      if (!durationInput) return;

      const durationMinutes = Number(durationInput);
      if (!Number.isFinite(durationMinutes) || durationMinutes <= 0) return;

      const reason = window.prompt("Ban sebebi", "kural ihlali") ?? "kural ihlali";
      await banPlayer(userId, durationMinutes, reason);
    },
    [banPlayer]
  );

  const handleQuickAssignModerator = useCallback(
    async (userId: string, userName: string) => {
      const confirmed = window.confirm(`${userName} kullanıcısı bu kanal için moderator yapılsın mı?`);
      if (!confirmed) return;
      await assignModerator(userId);
    },
    [assignModerator]
  );

  const handleCreateFilter = useCallback(async () => {
    if (!filterTerm.trim()) return;
    const success = await createFilter(filterTerm.trim(), filterReplacement.trim() || "***");
    if (success) {
      setFilterTerm("");
      setFilterReplacement("***");
    }
  }, [createFilter, filterReplacement, filterTerm]);

  const handleDmSearchChange = useCallback(
    (value: string) => {
      setDmSearch(value);
      if (value.trim().length < 2) {
        void searchDmUsers("");
      }
    },
    [searchDmUsers]
  );

  return (
    <div
      className="pointer-events-none fixed z-40 flex justify-start px-3 sm:px-4"
      style={{
        left: 0,
        bottom: "calc(env(safe-area-inset-bottom, 0px) + 104px)",
      }}
    >
      <div className="pointer-events-auto relative flex flex-col items-start gap-3">
        <AnimatePresence>
          {isOpen && (
            <>
              <motion.button
                key="chat-backdrop"
                type="button"
                aria-label="Sohbet panelini kapat"
                className="fixed inset-0 z-40 bg-[rgba(17,12,10,0.36)]"
                style={{ backdropFilter: "blur(2px)", WebkitBackdropFilter: "blur(2px)" }}
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                transition={{ duration: 0.18, ease: "easeOut" }}
                onClick={() => setIsOpen(false)}
              />

              <motion.section
                key="chat-panel"
                aria-label="Sohbet paneli"
                initial={{ opacity: 0, y: 28, scale: 0.96 }}
                animate={{ opacity: 1, y: 0, scale: 1 }}
                exit={{ opacity: 0, y: 24, scale: 0.98 }}
                transition={{ duration: 0.28, ease: PANEL_EASE }}
                className={`${CHAT_PANEL} relative z-50 w-[min(calc(100vw-1.5rem),24rem)] overflow-hidden`}
              >
                <div className="pointer-events-none absolute -left-12 top-6 h-24 w-24 rounded-full bg-sky-500/10 blur-3xl" />
                <div className="pointer-events-none absolute -right-10 top-0 h-28 w-28 rounded-full bg-orange-400/10 blur-3xl" />
                <div className="pointer-events-none absolute inset-px rounded-[calc(1.5rem-1px)] bg-[linear-gradient(180deg,rgba(255,255,255,0.04),transparent_24%,transparent)]" />

                <div className="relative border-b border-white/10 px-4 pb-3 pt-4">
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <div className="flex items-center gap-2">
                        <div
                          className="flex h-10 w-10 items-center justify-center rounded-2xl border border-sky-400/20 bg-[linear-gradient(160deg,rgba(18,26,38,0.96),rgba(9,13,21,0.96))] shadow-[0_12px_24px_rgba(0,0,0,0.28)]"
                        >
                          <MessageCircleMore size={18} className="text-sky-300" />
                        </div>
                        <div className="min-w-0">
                          <p className="truncate text-[10px] font-black uppercase tracking-[0.18em] text-slate-400">
                            Saha Sohbeti
                          </p>
                          <p className="truncate text-[13px] font-semibold text-white">
                            {activeChannelMeta.description}
                          </p>
                        </div>
                      </div>
                      <div className="mt-3 flex items-center gap-2 text-[10px] uppercase tracking-[0.18em] text-slate-500">
                        <span className="h-px flex-1 bg-white/10" />
                        <span>{player?.display_name || player?.username || "Adsız"}</span>
                      </div>
                    </div>

                    <button
                      type="button"
                      onClick={() => setIsOpen(false)}
                      aria-label="Sohbet panelini kapat"
                      className="flex h-9 w-9 items-center justify-center rounded-full border border-white/10 bg-black/20 text-slate-300 transition-colors hover:bg-white/10"
                    >
                      <X size={16} />
                    </button>
                  </div>

                  <div
                    className="mt-4 flex gap-2 overflow-x-auto pb-2 no-scrollbar"
                    style={{
                      touchAction: "pan-x",
                      WebkitOverflowScrolling: "touch",
                      overscrollBehaviorX: "contain",
                    }}
                  >
                    {CHANNELS.map((channel) => {
                      const Icon = channel.icon;
                      const isActive = activeChannel === channel.key;

                      return (
                        <button
                          key={channel.key}
                          type="button"
                          onClick={() => {
                            if (channel.key === "dm") {
                              leaveDmConversation();
                              setActiveChannel("dm");
                              return;
                            }

                            setActiveChannel(channel.key);
                          }}
                          className="group shrink-0 rounded-2xl px-3 py-2 text-left transition-transform hover:-translate-y-0.5"
                          style={{
                            touchAction: "manipulation",
                            background: isActive
                              ? `linear-gradient(160deg, color-mix(in srgb, ${channel.accent} 12%, rgba(20,27,38,0.96)), rgba(9,13,21,0.96))`
                              : "rgba(255,255,255,0.03)",
                            border: `1px solid ${isActive ? channel.accent : "rgba(255,255,255,0.08)"}`,
                            boxShadow: isActive ? `0 12px 24px color-mix(in srgb, ${channel.accent} 18%, transparent)` : undefined,
                          }}
                        >
                          <div className="flex items-center gap-2">
                            <span
                              className="flex h-7 w-7 items-center justify-center rounded-xl"
                              style={{
                                background: isActive ? "rgba(255,255,255,0.08)" : "rgba(255,255,255,0.04)",
                                color: channel.accent,
                              }}
                            >
                              <Icon size={14} />
                            </span>
                            <div>
                              <p className="text-[11px] font-bold text-white">{channel.label}</p>
                              <p className="text-[9px] uppercase tracking-[0.12em] text-slate-500">{channel.description}</p>
                            </div>
                          </div>
                        </button>
                      );
                    })}
                  </div>
                </div>

                <div className="relative px-3 pb-3 pt-3">
                  {showDmConversationList ? (
                    <DmConversationPanel
                      searchValue={dmSearch}
                      onSearchChange={handleDmSearchChange}
                      searchResults={dmSearchResults}
                      isSearching={isDmSearchLoading}
                      conversations={dmConversations}
                      isLoading={isDmLoading}
                      onOpenConversation={openDmConversation}
                    />
                  ) : (
                    <>
                      <div
                        className="relative h-[20.5rem] overflow-y-auto rounded-[26px] border border-white/10 px-3 py-3 no-scrollbar"
                        style={{
                          background: [
                            "radial-gradient(circle at 14% 10%, rgba(56,189,248,0.08), transparent 30%)",
                            "radial-gradient(circle at 88% 0%, rgba(249,115,22,0.07), transparent 25%)",
                            "linear-gradient(180deg, rgba(13,18,27,0.94) 0%, rgba(9,13,21,0.98) 100%)",
                          ].join(", "),
                        }}
                      >
                        {showDmThread && activeDmPeer ? (
                          <div className="mb-3 flex items-center justify-between gap-2 rounded-[18px] border border-white/10 bg-white/5 px-3 py-2">
                            <div className="min-w-0">
                              <p className="truncate text-[10px] font-black uppercase tracking-[0.14em] text-slate-500">
                                Özel Mesaj
                              </p>
                              <p className="truncate text-[13px] font-semibold text-white">
                                @{activeDmPeer.username}
                              </p>
                            </div>
                            <div className="flex items-center gap-2">
                              <button
                                type="button"
                                onClick={() => void mutePlayer(activeDmPeer.id)}
                                className="flex h-8 w-8 items-center justify-center rounded-full bg-white/5 text-slate-300 transition-colors hover:bg-white/10"
                                title="Göndereni sustur"
                              >
                                <ShieldBan size={13} />
                              </button>
                              <button
                                type="button"
                                onClick={leaveDmConversation}
                                className="flex h-8 w-8 items-center justify-center rounded-full bg-white/5 text-slate-300 transition-colors hover:bg-white/10"
                                title="Listeye dön"
                              >
                                <ChevronLeft size={14} />
                              </button>
                            </div>
                          </div>
                        ) : null}

                        {activeBan ? (
                          <div className="mb-3 rounded-[18px] border border-red-400/20 bg-red-500/10 px-3 py-2 text-[12px] text-red-100">
                            <div className="flex items-center gap-2 text-[10px] font-black uppercase tracking-[0.16em] text-red-200/80">
                              <ShieldBan size={12} />
                              Sohbet Kısıtı
                            </div>
                            <p className="mt-1 leading-5">
                              {activeBan.reason || "Sohbet erişimin geçici olarak kısıtlandı."}
                            </p>
                            <p className="mt-1 text-[10px] uppercase tracking-[0.12em] text-red-200/70">
                              Bitiş: {new Date(activeBan.expires_at).toLocaleString("tr-TR")}
                            </p>
                          </div>
                        ) : null}

                        {canManageFilters ? (
                          <FilterManager
                            filters={moderationState.filters}
                            isLoading={isModerationLoading}
                            term={filterTerm}
                            replacement={filterReplacement}
                            onTermChange={setFilterTerm}
                            onReplacementChange={setFilterReplacement}
                            onCreate={handleCreateFilter}
                            onDelete={deleteFilter}
                          />
                        ) : null}

                        {currentMessages.length === 0 ? (
                          <EmptyState channelLabel={activeChannelMeta.label} />
                        ) : (
                          <div className="space-y-2.5">
                            {currentMessages.map((message) => (
                              <MessageRow
                                key={message.id}
                                message={message}
                                isOwn={message.sender_id === (player as { id?: string } | null)?.id}
                                onMute={mutePlayer}
                                onReport={reportMessage}
                                onDelete={deleteMessage}
                                onBan={handleQuickBan}
                                onAssignModerator={handleQuickAssignModerator}
                                permissions={moderationState.permissions}
                                canManageModerators={canManageModerators}
                              />
                            ))}
                            <div ref={messagesEndRef} />
                          </div>
                        )}
                      </div>

                      {activeChannel !== "dm" || activeDmPeer ? (
                        <div
                          className="mt-3 rounded-[26px] border border-white/10 bg-[linear-gradient(160deg,rgba(20,27,38,0.94),rgba(10,14,22,0.94))] p-3 shadow-[0_20px_40px_rgba(0,0,0,0.25)]"
                        >
                          <div className="mb-2 flex items-center justify-between gap-3 text-[10px] uppercase tracking-[0.16em] text-slate-500">
                            <span>{activeChannel === "dm" ? `@${activeDmPeer?.username ?? "oyuncu"}` : "Mesaj"}</span>
                            <span>{input.length}/{MAX_MESSAGE_LENGTH}</span>
                          </div>

                          <div className="flex gap-2">
                            <textarea
                              value={input}
                              onChange={(event) => setInput(event.target.value)}
                              onKeyDown={handleKeyDown}
                              rows={2}
                              maxLength={MAX_MESSAGE_LENGTH}
                              disabled={Boolean(activeBan)}
                              placeholder={activeChannel === "dm" ? "Özel mesaj yaz..." : `${activeChannelMeta.label} hattına yaz...`}
                              className="min-h-[4.5rem] flex-1 resize-none rounded-[20px] border border-white/10 bg-black/20 px-3 py-2.5 text-[13px] leading-5 text-slate-100 outline-none placeholder:text-slate-500 focus:border-sky-400/40"
                            />

                            <motion.button
                              type="button"
                              onClick={() => void handleSend()}
                              whileTap={{ scale: 0.96 }}
                              disabled={!input.trim() || Boolean(activeBan)}
                              className="flex w-12 shrink-0 items-center justify-center rounded-[20px] border border-sky-400/25 bg-[linear-gradient(180deg,rgba(14,165,233,0.28),rgba(14,165,233,0.14))] text-sky-100 shadow-[0_10px_24px_rgba(2,132,199,0.18)] disabled:cursor-not-allowed disabled:opacity-40"
                            >
                              <SendHorizonal size={16} />
                            </motion.button>
                          </div>
                        </div>
                      ) : null}
                    </>
                  )}
                </div>
              </motion.section>
            </>
          )}
        </AnimatePresence>

        <motion.button
          type="button"
          aria-expanded={isOpen}
          aria-label={isOpen ? "Sohbet panelini kapat" : "Sohbet panelini aç"}
          onClick={() => setIsOpen((open) => !open)}
          whileHover={{ y: -3 }}
          whileTap={{ scale: 0.96 }}
          className={`${CHAT_PANEL} relative z-50 flex h-[68px] w-[68px] items-center justify-center overflow-hidden`}
        >
          <span className="pointer-events-none absolute -left-4 top-1 h-10 w-10 rounded-full bg-sky-400/15 blur-2xl" />
          <span className="pointer-events-none absolute -right-4 bottom-0 h-10 w-10 rounded-full bg-orange-400/15 blur-2xl" />
          <span
            className="pointer-events-none absolute inset-px rounded-[calc(1.5rem-1px)] bg-[linear-gradient(180deg,rgba(255,255,255,0.05),transparent_40%)]"
          />
          <div className="relative flex flex-col items-center gap-0.5">
            <MessageCircleMore size={18} className="text-sky-200" />
            <span className="text-[8px] font-black uppercase tracking-[0.18em] text-slate-300">
              Sohbet
            </span>
          </div>

          {totalUnreadBadge > 0 && !isOpen ? (
            <span
              className="absolute -right-1 -top-1 flex min-w-6 items-center justify-center rounded-full px-1.5 py-1 text-[10px] font-black text-[rgba(255,240,224,0.94)]"
              style={{
                background: "linear-gradient(180deg, rgba(249,115,22,0.98), rgba(194,65,12,0.98))",
                border: "1px solid rgba(251, 191, 36, 0.44)",
                boxShadow: "0 10px 18px rgba(154, 52, 18, 0.28)",
              }}
            >
              {totalUnreadBadge > 99 ? "99+" : totalUnreadBadge}
            </span>
          ) : null}
        </motion.button>
      </div>
    </div>
  );
}

function EmptyState({ channelLabel }: { channelLabel: string }) {
  return (
    <div className="flex h-full flex-col items-center justify-center px-5 text-center">
      <div
        className="flex h-14 w-14 items-center justify-center rounded-2xl border border-white/10 bg-[linear-gradient(160deg,rgba(20,27,38,0.94),rgba(10,14,22,0.94))]"
      >
        <AlertTriangle size={20} className="text-orange-300" />
      </div>
      <p className="mt-4 text-[13px] font-bold text-white">
        {channelLabel} kanalında henüz mesaj yok
      </p>
      <p className="mt-1 max-w-[16rem] text-[12px] leading-5 text-slate-400">
        İlk mesajı gönder. Yeni iletiler burada envanter ekranındaki koyu panel diliyle akacak.
      </p>
    </div>
  );
}

function MessageRow({
  message,
  isOwn,
  onMute,
  onReport,
  onDelete,
  onBan,
  onAssignModerator,
  permissions,
  canManageModerators,
}: {
  message: ChatMessage;
  isOwn: boolean;
  onMute: (playerId: string) => Promise<boolean>;
  onReport: (messageId: string, reason: string) => Promise<boolean>;
  onDelete: (messageId: string, reason?: string) => Promise<boolean>;
  onBan: (playerId: string, playerName: string) => Promise<void>;
  onAssignModerator: (playerId: string, playerName: string) => Promise<void>;
  permissions: ChatPermissions;
  canManageModerators: boolean;
}) {
  if (message.is_system) {
    return (
      <div
        className="rounded-[22px] border border-amber-400/15 bg-[linear-gradient(160deg,rgba(249,115,22,0.10),rgba(20,27,38,0.72))] px-3 py-3 text-center"
      >
        <div className="mb-1 flex items-center justify-center gap-2 text-[10px] uppercase tracking-[0.2em] text-amber-300/80">
          <Radio size={12} />
          Sistem
        </div>
        <p className="text-[12px] leading-5 text-slate-100">{message.content}</p>
      </div>
    );
  }

  return (
    <div className={`flex ${isOwn ? "justify-end" : "justify-start"}`}>
      <article
        className="max-w-[86%] rounded-[22px] px-3.5 py-3"
        style={{
          background: isOwn
            ? "linear-gradient(160deg, rgba(17, 108, 153, 0.28), rgba(20,27,38,0.98))"
            : "linear-gradient(160deg, rgba(20,27,38,0.96), rgba(9,13,21,0.98))",
          border: isOwn
            ? "1px solid rgba(56,189,248,0.24)"
            : "1px solid rgba(255,255,255,0.08)",
          boxShadow: isOwn
            ? "0 10px 18px rgba(2,132,199,0.10)"
            : "0 10px 18px rgba(0,0,0,0.18)",
          color: "rgba(226, 232, 240, 0.96)",
        }}
      >
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0 flex-1">
            {!isOwn ? (
              <p className="mb-1 truncate text-[10px] font-black uppercase tracking-[0.14em] text-sky-300/80">
                {message.sender_name}
              </p>
            ) : null}
            <p className="text-[13px] leading-5 break-words">{message.content}</p>
          </div>

          {!isOwn ? (
            <div className="flex items-center gap-1">
              <button
                type="button"
                className="flex h-7 w-7 items-center justify-center rounded-full bg-white/5 text-slate-400 transition-colors hover:bg-white/10"
                onClick={() => void onMute(message.sender_id)}
                title="Sustur"
              >
                <ShieldBan size={12} />
              </button>
              <button
                type="button"
                className="flex h-7 w-7 items-center justify-center rounded-full bg-white/5 text-slate-400 transition-colors hover:bg-white/10"
                onClick={() => void onReport(message.id, "inappropriate")}
                title="Raporla"
              >
                <Flag size={12} />
              </button>
              {permissions.can_delete ? (
                <button
                  type="button"
                  className="flex h-7 w-7 items-center justify-center rounded-full bg-white/5 text-slate-400 transition-colors hover:bg-white/10"
                  onClick={() => void onDelete(message.id, "moderator_delete")}
                  title="Mesajı sil"
                >
                  <Trash2 size={12} />
                </button>
              ) : null}
              {permissions.can_ban ? (
                <button
                  type="button"
                  className="flex h-7 w-7 items-center justify-center rounded-full bg-white/5 text-slate-400 transition-colors hover:bg-white/10"
                  onClick={() => void onBan(message.sender_id, message.sender_name)}
                  title="Geçici ban uygula"
                >
                  <Gavel size={12} />
                </button>
              ) : null}
              {canManageModerators ? (
                <button
                  type="button"
                  className="flex h-7 w-7 items-center justify-center rounded-full bg-white/5 text-slate-400 transition-colors hover:bg-white/10"
                  onClick={() => void onAssignModerator(message.sender_id, message.sender_name)}
                  title="Moderator ata"
                >
                  <Crown size={12} />
                </button>
              ) : null}
            </div>
          ) : null}
        </div>

        <div className="mt-2 flex items-center justify-between text-[10px] uppercase tracking-[0.12em] text-slate-500">
          <span>{isOwn ? "Sen" : "Oyuncu"}</span>
          <span>
            {new Date(message.timestamp).toLocaleTimeString("tr-TR", {
              hour: "2-digit",
              minute: "2-digit",
            })}
          </span>
        </div>
      </article>
    </div>
  );
}

function FilterManager({
  filters,
  isLoading,
  term,
  replacement,
  onTermChange,
  onReplacementChange,
  onCreate,
  onDelete,
}: {
  filters: ChatFilterEntry[];
  isLoading: boolean;
  term: string;
  replacement: string;
  onTermChange: (value: string) => void;
  onReplacementChange: (value: string) => void;
  onCreate: () => Promise<void>;
  onDelete: (filterId: string) => Promise<boolean>;
}) {
  return (
    <div className="mb-3 rounded-[20px] border border-amber-400/15 bg-amber-500/5 p-3">
      <div className="flex items-center justify-between gap-3">
        <div>
          <p className="text-[10px] font-black uppercase tracking-[0.16em] text-amber-200/80">
            Filtre Yönetimi
          </p>
          <p className="mt-1 text-[12px] text-slate-300">
            Kanal bazlı yasaklı kelimeleri burada yönet.
          </p>
        </div>
        {isLoading ? <span className="text-[10px] uppercase tracking-[0.12em] text-slate-500">Yükleniyor</span> : null}
      </div>

      <div className="mt-3 flex gap-2">
        <input
          value={term}
          onChange={(event) => onTermChange(event.target.value)}
          placeholder="Kelime"
          className="h-10 flex-1 rounded-2xl border border-white/10 bg-black/20 px-3 text-[12px] text-slate-100 outline-none placeholder:text-slate-500"
        />
        <input
          value={replacement}
          onChange={(event) => onReplacementChange(event.target.value)}
          placeholder="Sansür"
          className="h-10 w-24 rounded-2xl border border-white/10 bg-black/20 px-3 text-[12px] text-slate-100 outline-none placeholder:text-slate-500"
        />
        <button
          type="button"
          onClick={() => void onCreate()}
          className="rounded-2xl border border-amber-300/20 bg-amber-400/10 px-3 text-[11px] font-bold uppercase tracking-[0.12em] text-amber-100"
        >
          Ekle
        </button>
      </div>

      {filters.length > 0 ? (
        <div className="mt-3 space-y-2">
          {filters.map((filter) => (
            <div
              key={filter.id}
              className="flex items-center justify-between gap-3 rounded-2xl border border-white/8 bg-black/15 px-3 py-2"
            >
              <div className="min-w-0">
                <p className="truncate text-[12px] font-semibold text-white">{filter.term}</p>
                <p className="text-[10px] uppercase tracking-[0.12em] text-slate-500">
                  {filter.replacement} · {filter.scope}
                </p>
              </div>
              <button
                type="button"
                onClick={() => void onDelete(filter.id)}
                className="flex h-8 w-8 items-center justify-center rounded-full bg-white/5 text-slate-400 transition-colors hover:bg-white/10"
                title="Filtreyi sil"
              >
                <Trash2 size={12} />
              </button>
            </div>
          ))}
        </div>
      ) : null}
    </div>
  );
}

function DmConversationPanel({
  searchValue,
  onSearchChange,
  searchResults,
  isSearching,
  conversations,
  isLoading,
  onOpenConversation,
}: {
  searchValue: string;
  onSearchChange: (value: string) => void;
  searchResults: Array<{ id: string; username: string; display_name: string | null }>;
  isSearching: boolean;
  conversations: Array<{
    peer_user_id: string;
    peer_username: string;
    peer_display_name: string | null;
    last_message_content: string;
    last_message_at: string;
    unread_count: number;
  }>;
  isLoading: boolean;
  onOpenConversation: (peer: { id: string; username: string; display_name: string | null }) => Promise<void>;
}) {
  return (
    <div className="space-y-3">
      <div className="rounded-[26px] border border-white/10 bg-[linear-gradient(160deg,rgba(13,18,27,0.94),rgba(9,13,21,0.98))] p-3">
        <div className="flex items-center gap-2 rounded-[20px] border border-white/10 bg-black/20 px-3 py-2.5">
          <Search size={14} className="text-slate-500" />
          <input
            value={searchValue}
            onChange={(event) => onSearchChange(event.target.value)}
            placeholder="Kullanıcı adı ile ara"
            className="h-6 flex-1 bg-transparent text-[13px] text-slate-100 outline-none placeholder:text-slate-500"
          />
        </div>

        {searchValue.trim().length >= 2 ? (
          <div className="mt-3 space-y-2">
            <p className="text-[10px] font-black uppercase tracking-[0.14em] text-slate-500">
              Arama Sonuçları
            </p>

            {isSearching ? (
              <div className="rounded-[18px] border border-white/8 bg-white/5 px-3 py-3 text-[12px] text-slate-400">
                Oyuncular aranıyor...
              </div>
            ) : searchResults.length > 0 ? (
              searchResults.map((user) => (
                <button
                  key={user.id}
                  type="button"
                  onClick={() => void onOpenConversation(user)}
                  className="flex w-full items-center justify-between rounded-[18px] border border-white/8 bg-white/5 px-3 py-3 text-left transition-colors hover:bg-white/8"
                >
                  <div className="min-w-0">
                    <p className="truncate text-[12px] font-semibold text-white">@{user.username}</p>
                    <p className="truncate text-[11px] text-slate-400">{user.display_name || "Oyuncu"}</p>
                  </div>
                  <span className="text-[10px] uppercase tracking-[0.12em] text-sky-300">Yaz</span>
                </button>
              ))
            ) : (
              <div className="rounded-[18px] border border-white/8 bg-white/5 px-3 py-3 text-[12px] text-slate-400">
                Bu kullanıcı adına yakın bir oyuncu bulunamadı.
              </div>
            )}
          </div>
        ) : null}
      </div>

      <div className="rounded-[26px] border border-white/10 bg-[linear-gradient(160deg,rgba(13,18,27,0.94),rgba(9,13,21,0.98))] p-3">
        <div className="mb-3 flex items-center justify-between gap-3">
          <div>
            <p className="text-[10px] font-black uppercase tracking-[0.14em] text-slate-500">Özel Mesajlar</p>
            <p className="text-[12px] text-slate-300">En son mesaj en üstte görünür.</p>
          </div>
          {isLoading ? <span className="text-[10px] uppercase tracking-[0.12em] text-slate-500">Yükleniyor</span> : null}
        </div>

        {conversations.length > 0 ? (
          <div className="space-y-2">
            {conversations.map((conversation) => (
              <button
                key={conversation.peer_user_id}
                type="button"
                onClick={() =>
                  void onOpenConversation({
                    id: conversation.peer_user_id,
                    username: conversation.peer_username,
                    display_name: conversation.peer_display_name,
                  })
                }
                className="flex w-full items-start justify-between gap-3 rounded-[20px] border border-white/8 bg-white/5 px-3 py-3 text-left transition-colors hover:bg-white/8"
              >
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <p className="truncate text-[12px] font-semibold text-white">@{conversation.peer_username}</p>
                    {conversation.unread_count > 0 ? (
                      <span className="flex min-w-5 items-center justify-center rounded-full bg-orange-500/20 px-1.5 py-0.5 text-[10px] font-black text-orange-100">
                        {conversation.unread_count > 99 ? "99+" : conversation.unread_count}
                      </span>
                    ) : null}
                  </div>
                  <p className="mt-1 truncate text-[11px] text-slate-400">{conversation.last_message_content}</p>
                </div>
                <span className="shrink-0 text-[10px] uppercase tracking-[0.12em] text-slate-500">
                  {new Date(conversation.last_message_at).toLocaleTimeString("tr-TR", {
                    hour: "2-digit",
                    minute: "2-digit",
                  })}
                </span>
              </button>
            ))}
          </div>
        ) : (
          <div className="rounded-[20px] border border-white/8 bg-white/5 px-4 py-5 text-center text-[12px] text-slate-400">
            Henüz özel mesaj yok. Yukarıdan bir kullanıcı arayıp konuşma başlat.
          </div>
        )}
      </div>
    </div>
  );
}