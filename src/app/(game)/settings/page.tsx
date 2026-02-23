// ============================================================
// Settings Page — Kaynak: scenes/ui/screens/SettingsScreen.gd
// Müzik, SFX, bildirimler, çıkış
// ============================================================

"use client";

import { useRouter } from "next/navigation";
import { motion } from "framer-motion";
import { useAuthStore } from "@/stores/authStore";
import { useAudioStore } from "@/stores/audioStore";
import { useUiStore } from "@/stores/uiStore";
import { usePlayerStore } from "@/stores/playerStore";
import { api } from "@/lib/api";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Modal } from "@/components/ui/Modal";
import { useState } from "react";

export default function SettingsPage() {
  const router = useRouter();
  const logout = useAuthStore((s) => s.logout);
  const musicVolume = useAudioStore((s) => s.musicVolume);
  const sfxVolume = useAudioStore((s) => s.sfxVolume);
  const isMuted = useAudioStore((s) => s.isMuted);
  const setMusicVolume = useAudioStore((s) => s.setMusicVolume);
  const setSfxVolume = useAudioStore((s) => s.setSfxVolume);
  const toggleMute = useAudioStore((s) => s.toggleMute);
  const settings = useUiStore((s) => s.settings);
  const updateSettings = useUiStore((s) => s.updateSettings);
  const addToast = useUiStore((s) => s.addToast);
  const player = usePlayerStore((s) => s.player);
  const fetchProfile = usePlayerStore((s) => s.fetchProfile);

  const [logoutConfirm, setLogoutConfirm] = useState(false);
  const [deleteAccountConfirm, setDeleteAccountConfirm] = useState(false);
  const [isDeletingAccount, setIsDeletingAccount] = useState(false);
  const [newDisplayName, setNewDisplayName] = useState("");
  const [isSavingName, setIsSavingName] = useState(false);

  const handleLogout = async () => {
    await logout();
    router.replace("/login");
  };

  // Godot: SettingsScreen._on_delete_account
  const handleDeleteAccount = async () => {
    setIsDeletingAccount(true);
    try {
      const res = await api.rpc("delete_account", {});
      if (res.success) {
        addToast("Hesabınız silindi", "info");
        await logout();
        router.replace("/login");
      } else {
        addToast(res.error || "Hesap silinemedi", "error");
      }
    } catch {
      addToast("Hesap silinemedi", "error");
    } finally {
      setIsDeletingAccount(false);
      setDeleteAccountConfirm(false);
    }
  };

  const handleSaveDisplayName = async () => {
    const trimmed = newDisplayName.trim();
    if (!trimmed) { addToast("İsim boş olamaz", "warning"); return; }
    if (trimmed.length < 3) { addToast("En az 3 karakter olmalı", "warning"); return; }
    setIsSavingName(true);
    try {
      const res = await api.rpc("update_user_profile", { p_display_name: trimmed });
      if (res.success) {
        addToast("Kullanıcı adı güncellendi!", "success");
        setNewDisplayName("");
        await fetchProfile();
      } else {
        addToast(res.error || "Güncelleme başarısız", "error");
      }
    } catch {
      addToast("İşlem başarısız", "error");
    } finally {
      setIsSavingName(false);
    }
  };

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      className="p-4 space-y-4"
    >
      <h2 className="text-lg font-bold text-[var(--text-primary)]">⚙️ Ayarlar</h2>

      {/* Audio */}
      <Card>
        <div className="p-4 space-y-4">
          <h3 className="text-sm font-semibold text-[var(--text-secondary)]">
            🔊 Ses Ayarları
          </h3>

          <div>
            <div className="flex items-center justify-between text-xs mb-1">
              <span className="text-[var(--text-muted)]">🎵 Müzik</span>
              <span className="text-[var(--text-primary)]">
                {Math.round(musicVolume * 100)}%
              </span>
            </div>
            <input
              type="range"
              min={0}
              max={1}
              step={0.01}
              value={musicVolume}
              onChange={(e) => setMusicVolume(parseFloat(e.target.value))}
              className="w-full accent-[var(--accent)]"
            />
          </div>

          <div>
            <div className="flex items-center justify-between text-xs mb-1">
              <span className="text-[var(--text-muted)]">🔔 Efektler</span>
              <span className="text-[var(--text-primary)]">
                {Math.round(sfxVolume * 100)}%
              </span>
            </div>
            <input
              type="range"
              min={0}
              max={1}
              step={0.01}
              value={sfxVolume}
              onChange={(e) => setSfxVolume(parseFloat(e.target.value))}
              className="w-full accent-[var(--accent)]"
            />
          </div>

          <div className="flex items-center justify-between">
            <span className="text-xs text-[var(--text-muted)]">
              🔇 Tüm Sesleri Kapat
            </span>
            <button
              onClick={toggleMute}
              className={`w-10 h-5 rounded-full transition-colors ${
                isMuted ? "bg-[var(--color-error)]" : "bg-[var(--color-success)]"
              } relative`}
            >
              <span
                className={`absolute top-0.5 w-4 h-4 rounded-full bg-white transition-transform ${
                  isMuted ? "left-0.5" : "left-5"
                }`}
              />
            </button>
          </div>
        </div>
      </Card>

      {/* Notifications */}
      <Card>
        <div className="p-4 space-y-3">
          <h3 className="text-sm font-semibold text-[var(--text-secondary)]">
            📱 Bildirimler & Oyun
          </h3>

          <div className="flex items-center justify-between">
            <span className="text-xs text-[var(--text-muted)]">
              Bildirimler
            </span>
            <button
              onClick={() =>
                updateSettings({ notificationsEnabled: !settings.notificationsEnabled })
              }
              className={`w-10 h-5 rounded-full transition-colors ${
                settings.notificationsEnabled
                  ? "bg-[var(--color-success)]"
                  : "bg-[var(--border-default)]"
              } relative`}
            >
              <span
                className={`absolute top-0.5 w-4 h-4 rounded-full bg-white transition-transform ${
                  settings.notificationsEnabled ? "left-5" : "left-0.5"
                }`}
              />
            </button>
          </div>

          {/* Auto Battle Toggle — Godot: SettingsScreen.auto_battle_toggle */}
          <div className="flex items-center justify-between">
            <div>
              <span className="text-xs text-[var(--text-muted)]">
                ⚔️ Otomatik Savaş
              </span>
              <p className="text-[10px] text-[var(--text-muted)] opacity-60">PvP ve zindan savaşlarını otomatik yönet</p>
            </div>
            <button
              onClick={() => updateSettings({ autoBattle: !settings.autoBattle })}
              className={`w-10 h-5 rounded-full transition-colors ${
                settings.autoBattle
                  ? "bg-[var(--color-success)]"
                  : "bg-[var(--border-default)]"
              } relative`}
            >
              <span
                className={`absolute top-0.5 w-4 h-4 rounded-full bg-white transition-transform ${
                  settings.autoBattle ? "left-5" : "left-0.5"
                }`}
              />
            </button>
          </div>
        </div>
      </Card>

      {/* Language — Godot: SettingsScreen.language_option_button (TR/EN) */}
      <Card>
        <div className="p-4 space-y-3">
          <h3 className="text-sm font-semibold text-[var(--text-secondary)]">
            🌐 Dil
          </h3>
          <div className="flex gap-2">
            <button
              onClick={() => updateSettings({ language: "tr" })}
              className={`flex-1 py-2 rounded-lg text-sm font-medium transition-colors ${
                settings.language === "tr"
                  ? "bg-[var(--accent)] text-white"
                  : "bg-[var(--bg-card)] text-[var(--text-secondary)]"
              }`}
            >
              🇹🇷 Türkçe
            </button>
            <button
              onClick={() => updateSettings({ language: "en" })}
              className={`flex-1 py-2 rounded-lg text-sm font-medium transition-colors ${
                settings.language === "en"
                  ? "bg-[var(--accent)] text-white"
                  : "bg-[var(--bg-card)] text-[var(--text-secondary)]"
              }`}
            >
              🇬🇧 English
            </button>
          </div>
        </div>
      </Card>

      {/* Profile Edit — update_user_profile RPC */}
      <Card>
        <div className="p-4 space-y-3">
          <h3 className="text-sm font-semibold text-[var(--text-secondary)]">
            ✏️ Profil Düzenle
          </h3>
          <p className="text-xs text-[var(--text-muted)]">
            Mevcut ad: <span className="text-[var(--text-primary)] font-medium">{player?.display_name || player?.username || "—"}</span>
          </p>
          <input
            type="text"
            placeholder="Yeni kullanıcı adı..."
            value={newDisplayName}
            onChange={(e) => setNewDisplayName(e.target.value)}
            className="w-full bg-[var(--input-bg)] border border-[var(--border-default)] rounded-lg px-3 py-2 text-sm text-[var(--text-primary)] placeholder-[var(--text-muted)] focus:outline-none focus:border-[var(--accent)]"
            maxLength={24}
          />
          <Button
            variant="primary"
            size="sm"
            fullWidth
            isLoading={isSavingName}
            disabled={!newDisplayName.trim()}
            onClick={handleSaveDisplayName}
          >
            Kaydet
          </Button>
        </div>
      </Card>

      {/* Account */}
      <Card>
        <div className="p-4 space-y-3">
          <h3 className="text-sm font-semibold text-[var(--text-secondary)]">
            👤 Hesap
          </h3>
          <Button
            variant="danger"
            size="sm"
            fullWidth
            onClick={() => setLogoutConfirm(true)}
          >
            Çıkış Yap
          </Button>
          {/* Account deletion — Godot: SettingsScreen.delete_account_button */}
          <Button
            variant="danger"
            size="sm"
            fullWidth
            onClick={() => setDeleteAccountConfirm(true)}
          >
            🗑️ Hesabı Sil
          </Button>
        </div>
      </Card>

      {/* Logout Confirm */}
      <Modal
        isOpen={logoutConfirm}
        onClose={() => setLogoutConfirm(false)}
        title="Çıkış Onayı"
        size="sm"
      >
        <div className="space-y-3">
          <p className="text-sm text-[var(--text-secondary)]">
            Hesabından çıkış yapmak istediğine emin misin?
          </p>
          <div className="flex gap-2">
            <Button
              variant="secondary"
              size="sm"
              fullWidth
              onClick={() => setLogoutConfirm(false)}
            >
              Vazgeç
            </Button>
            <Button variant="danger" size="sm" fullWidth onClick={handleLogout}>
              Çıkış Yap
            </Button>
          </div>
        </div>
      </Modal>

      {/* Delete Account Confirm — Godot: SettingsScreen._on_delete_account */}
      <Modal
        isOpen={deleteAccountConfirm}
        onClose={() => setDeleteAccountConfirm(false)}
        title="⚠️ Hesabı Sil"
        size="sm"
      >
        <div className="space-y-3">
          <p className="text-sm text-[var(--text-secondary)]">
            Bu işlem <strong>geri alınamaz!</strong> Tüm ilerleme, altın, gem ve eşyaların kalıcı olarak silinecek.
          </p>
          <p className="text-xs text-[var(--color-error)]">
            Emin misin? Bu işlem geri alınamaz.
          </p>
          <div className="flex gap-2">
            <Button
              variant="secondary"
              size="sm"
              fullWidth
              onClick={() => setDeleteAccountConfirm(false)}
            >
              Vazgeç
            </Button>
            <Button variant="danger" size="sm" fullWidth onClick={handleDeleteAccount} isLoading={isDeletingAccount}>
              Evet, Sil
            </Button>
          </div>
        </div>
      </Modal>
    </motion.div>
  );
}
