// ============================================================
// Chat Page — Kaynak: ChatManager.gd (264 satır)
// Kanal seçimi, mesaj listesi, gönderme
// ============================================================

"use client";

import { useState, useRef, useEffect, useCallback } from "react";
import { motion } from "framer-motion";
import { useChat, type ChatChannel } from "@/hooks/useChat";
import { usePlayerStore } from "@/stores/playerStore";

const CHANNELS: { key: ChatChannel; label: string; icon: string }[] = [
  { key: "global", label: "Genel", icon: "🌍" },
  { key: "guild", label: "Lonca", icon: "🏰" },
  { key: "trade", label: "Ticaret", icon: "💰" },
  { key: "dm", label: "Özel", icon: "✉️" },
];

export default function ChatPage() {
  const {
    currentMessages,
    activeChannel,
    setActiveChannel,
    sendMessage,
    mutePlayer,
    reportMessage,
    MAX_MESSAGE_LENGTH,
  } = useChat();

  const player = usePlayerStore((s) => s.player);
  const [input, setInput] = useState("");
  const messagesEndRef = useRef<HTMLDivElement>(null);

  // Auto-scroll on new messages
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [currentMessages.length]);

  const handleSend = useCallback(async () => {
    if (!input.trim()) return;
    const success = await sendMessage(input.trim());
    if (success) setInput("");
  }, [input, sendMessage]);

  const handleKeyDown = useCallback(
    (e: React.KeyboardEvent) => {
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault();
        handleSend();
      }
    },
    [handleSend]
  );

  return (
    <div className="flex flex-col h-[calc(100vh-8rem)]">
      {/* Channel tabs */}
      <div className="flex gap-1 p-2 bg-[var(--surface)] border-b border-[var(--border)]">
        {CHANNELS.map((ch) => (
          <button
            key={ch.key}
            className={`flex-1 py-1.5 rounded-lg text-xs font-medium transition-colors ${
              activeChannel === ch.key
                ? "bg-[var(--primary)] text-white"
                : "text-[var(--text-secondary)]"
            }`}
            onClick={() => setActiveChannel(ch.key)}
          >
            <span className="mr-1">{ch.icon}</span>
            {ch.label}
          </button>
        ))}
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto p-3 space-y-2">
        {currentMessages.length === 0 ? (
          <p className="text-center text-[var(--text-secondary)] py-8 text-sm">
            Henüz mesaj yok
          </p>
        ) : (
          currentMessages.map((msg) => {
            const isOwn = msg.sender_id === (player as unknown as Record<string, unknown>)?.id;
            return (
              <motion.div
                key={msg.id}
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                className={`flex ${isOwn ? "justify-end" : "justify-start"}`}
              >
                <div
                  className={`max-w-[80%] rounded-xl px-3 py-2 ${
                    msg.is_system
                      ? "bg-yellow-900/30 text-yellow-400 text-center w-full"
                      : isOwn
                        ? "bg-[var(--primary)] text-white"
                        : "bg-[var(--card-bg)] text-[var(--text)]"
                  }`}
                >
                  {!isOwn && !msg.is_system && (
                    <p className="text-xs font-medium text-[var(--gold)] mb-0.5">
                      {msg.sender_name}
                    </p>
                  )}
                  <p className="text-sm break-words">{msg.content}</p>
                  <div className="flex justify-between items-center mt-1">
                    <span className="text-[10px] opacity-50">
                      {new Date(msg.timestamp).toLocaleTimeString("tr-TR", {
                        hour: "2-digit",
                        minute: "2-digit",
                      })}
                    </span>
                    {!isOwn && !msg.is_system && (
                      <div className="flex gap-2">
                        <button
                          className="text-[10px] opacity-40 hover:opacity-100"
                          onClick={() => mutePlayer(msg.sender_id)}
                          title="Sustur"
                        >
                          🔇
                        </button>
                        <button
                          className="text-[10px] opacity-40 hover:opacity-100"
                          onClick={() => reportMessage(msg.id, "inappropriate")}
                          title="Raporla"
                        >
                          🚩
                        </button>
                      </div>
                    )}
                  </div>
                </div>
              </motion.div>
            );
          })
        )}
        <div ref={messagesEndRef} />
      </div>

      {/* Input */}
      <div className="p-3 border-t border-[var(--border)] bg-[var(--surface)]">
        <div className="flex gap-2">
          <input
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="Mesaj yaz..."
            maxLength={MAX_MESSAGE_LENGTH}
            className="flex-1 bg-[var(--card-bg)] border border-[var(--border)] rounded-xl px-3 py-2 text-sm text-[var(--text)] placeholder:text-[var(--text-secondary)] outline-none focus:border-[var(--primary)]"
          />
          <button
            onClick={handleSend}
            disabled={!input.trim()}
            className="px-4 py-2 rounded-xl bg-[var(--primary)] text-white text-sm font-medium disabled:opacity-50"
          >
            Gönder
          </button>
        </div>
        <p className="text-[10px] text-[var(--text-secondary)] mt-1 text-right">
          {input.length}/{MAX_MESSAGE_LENGTH}
        </p>
      </div>
    </div>
  );
}
