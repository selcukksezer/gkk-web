// ============================================================
// PvP Page — Kaynak: scenes/ui/screens/PvPScreen.gd (230 satır)
// Saldırı geçmişi, savunma geçmişi, oyuncu arama, istatistikler paneli,
// savaş detay dialogu (tam log), puan değişimi, opponent/result/timestamp
// ============================================================

"use client";

import { useEffect, useState } from "react";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Modal } from "@/components/ui/Modal";
import { api } from "@/lib/api";
import { GAME_CONFIG } from "@/data/GameConstants";
import { isInHospital, isInPrison } from "@/lib/utils/validation";
import { formatGold } from "@/lib/utils/string";
import { timeAgo } from "@/lib/utils/datetime";
import type { PvPTarget, PvPResult, PvPHistoryEntry } from "@/types/pvp";

type PvPTab = "attack_history" | "defense_history" | "search" | "stats";

export default function PvPPage() {
  const energy = usePlayerStore((s) => s.energy);
  const level = usePlayerStore((s) => s.level);
  const hospitalUntil = usePlayerStore((s) => s.hospitalUntil);
  const prisonUntil = usePlayerStore((s) => s.prisonUntil);
  const pvpWins = usePlayerStore((s) => s.pvpWins);
  const pvpLosses = usePlayerStore((s) => s.pvpLosses);
  const pvpRating = usePlayerStore((s) => s.pvpRating);
  const consumeEnergy = usePlayerStore((s) => s.consumeEnergy);
  const addToast = useUiStore((s) => s.addToast);

  const [tab, setTab] = useState<PvPTab>("search");
  const [attackHistory, setAttackHistory] = useState<PvPHistoryEntry[]>([]);
  const [defenseHistory, setDefenseHistory] = useState<PvPHistoryEntry[]>([]);
  const [targets, setTargets] = useState<PvPTarget[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [isAttacking, setIsAttacking] = useState(false);
  const [battleResult, setBattleResult] = useState<PvPResult | null>(null);
  const [searchTerm, setSearchTerm] = useState("");
  const [selectedTarget, setSelectedTarget] = useState<PvPTarget | null>(null);
  const [battleDetailOpen, setBattleDetailOpen] = useState(false);
  const [battleDetailData, setBattleDetailData] = useState<PvPHistoryEntry | null>(null);

  const restricted = isInHospital(hospitalUntil) || isInPrison(prisonUntil);

  useEffect(() => {
    if (tab === "search") loadTargets();
    if (tab === "attack_history") loadAttackHistory();
    if (tab === "defense_history") loadDefenseHistory();
  }, [tab]);

  const loadTargets = async () => {
    setIsLoading(true);
    try {
      const res = await api.rpc<PvPTarget[]>("get_pvp_targets", {});
      setTargets(res.data || []);
    } catch {
      addToast("Hedefler yüklenemedi", "error");
    } finally {
      setIsLoading(false);
    }
  };

  const loadAttackHistory = async () => {
    setIsLoading(true);
    try {
      const res = await api.rpc<PvPHistoryEntry[]>("get_pvp_attack_history", {});
      setAttackHistory(res.data || []);
    } catch {
      addToast("Saldırı geçmişi yüklenemedi", "error");
    } finally {
      setIsLoading(false);
    }
  };

  const loadDefenseHistory = async () => {
    setIsLoading(true);
    try {
      const res = await api.rpc<PvPHistoryEntry[]>("get_pvp_defense_history", {});
      setDefenseHistory(res.data || []);
    } catch {
      addToast("Savunma geçmişi yüklenemedi", "error");
    } finally {
      setIsLoading(false);
    }
  };

  const handleAttack = async (target: PvPTarget) => {
    if (energy < GAME_CONFIG.pvp.energyCost) {
      addToast("Yeterli enerji yok", "warning");
      return;
    }
    setIsAttacking(true);
    try {
      const res = await api.rpc<PvPResult>("attack_player", { p_target_id: target.player_id });
      consumeEnergy(GAME_CONFIG.pvp.energyCost);
      setBattleResult(res.data ?? null);
    } catch {
      addToast("Saldırı başarısız", "error");
    } finally {
      setIsAttacking(false);
    }
  };

  // Godot: player_search
  const handleSearch = async () => {
    if (!searchTerm.trim()) return;
    setIsLoading(true);
    try {
      const res = await api.rpc<PvPTarget[]>("search_pvp_player", { p_search: searchTerm.trim() });
      if (res.data && res.data.length > 0) {
        setSelectedTarget(res.data[0]);
      } else {
        addToast("Oyuncu bulunamadı", "warning");
      }
    } catch {
      addToast("Arama başarısız", "error");
    } finally {
      setIsLoading(false);
    }
  };

  const winRate = pvpWins + pvpLosses > 0 ? Math.round((pvpWins / (pvpWins + pvpLosses)) * 100) : 0;

  // Render a battle history item — Godot: _create_battle_item
  const renderBattleItem = (h: PvPHistoryEntry, i: number, isAttack: boolean) => {
    const won = isAttack ? h.result === "win" : h.result === "loss"; // in defense, "loss" for attacker means defender won
    const displayWon = h.result === "win";
    return (
      <Card key={i}>
        <div className="p-3">
          <div className="flex items-center justify-between">
            <p className="text-sm text-[var(--text-primary)]">vs {h.opponent_name}</p>
            <span className={`text-xs font-bold ${displayWon ? "text-[var(--color-success)]" : "text-[var(--color-error)]"}`}>
              {displayWon ? "Kazanıldı ✓" : "Kaybedildi ✗"}
            </span>
          </div>
          <div className="flex items-center justify-between text-xs text-[var(--text-muted)] mt-1">
            <span>
              {h.gold_change > 0 ? "+" : ""}{formatGold(h.gold_change)} altın
              {" • "}
              <span className="text-[var(--color-warning)]">{h.rating_change > 0 ? "+" : ""}{h.rating_change} puan</span>
            </span>
            <span>{timeAgo(h.timestamp)}</span>
          </div>
          {/* Details button — Godot: "Detaylar" */}
          <Button
            variant="secondary"
            size="sm"
            className="mt-2"
            onClick={() => { setBattleDetailData(h); setBattleDetailOpen(true); }}
          >
            Detaylar
          </Button>
        </div>
      </Card>
    );
  };

  return (
    <div className="p-4 space-y-4 pb-24">
      <h2 className="text-lg font-bold text-[var(--text-primary)]">⚔️ PvP Arena</h2>

      {restricted && (
        <Card>
          <div className="p-3 text-center text-sm text-[var(--color-error)]">
            {isInHospital(hospitalUntil) ? "🏥 Hastanedeyken saldıramazsın!" : "👮 Cezaevindeyken saldıramazsın!"}
          </div>
        </Card>
      )}

      {/* Tabs — Godot has attack_history, defense_history, search, stats */}
      <div className="flex gap-1 overflow-x-auto no-scrollbar">
        {([
          { key: "search" as PvPTab, label: "⚔️ Saldır" },
          { key: "attack_history" as PvPTab, label: "🗡️ Saldırılar" },
          { key: "defense_history" as PvPTab, label: "🛡️ Savunmalar" },
          { key: "stats" as PvPTab, label: "📊 İstatistik" },
        ]).map((t) => (
          <button key={t.key} onClick={() => setTab(t.key)}
            className={`flex-shrink-0 px-3 py-2 text-xs font-medium rounded-lg transition-colors ${
              tab === t.key ? "bg-[var(--accent)] text-white" : "bg-[var(--bg-card)] text-[var(--text-secondary)]"
            }`}
          >{t.label}</button>
        ))}
      </div>

      {/* Search & Attack Tab */}
      {tab === "search" && (
        <div className="space-y-3">
          {/* Player Search — Godot: PlayerSearchInput + SearchButton */}
          <div className="flex gap-2">
            <input
              type="text"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              placeholder="Oyuncu ara..."
              className="flex-1 px-3 py-2 rounded-lg bg-[var(--bg-input)] border border-[var(--border-default)] text-sm text-[var(--text-primary)] placeholder-[var(--text-muted)]"
              onKeyDown={(e) => e.key === "Enter" && handleSearch()}
            />
            <Button variant="secondary" size="sm" onClick={handleSearch}>Ara</Button>
          </div>

          {/* Selected target from search */}
          {selectedTarget && (
            <Card variant="elevated">
              <div className="p-3 flex items-center justify-between">
                <div>
                  <p className="text-sm font-semibold text-[var(--text-primary)]">{selectedTarget.username}</p>
                  <p className="text-xs text-[var(--text-muted)]">Lv.{selectedTarget.level} • ⭐{selectedTarget.rating}</p>
                </div>
                <Button variant="danger" size="sm" disabled={restricted || energy < GAME_CONFIG.pvp.energyCost} isLoading={isAttacking}
                  onClick={() => handleAttack(selectedTarget)}>
                  {selectedTarget.username}&apos;e Saldır
                </Button>
              </div>
            </Card>
          )}

          <p className="text-xs text-[var(--text-muted)]">Saldırı maliyeti: ⚡{GAME_CONFIG.pvp.energyCost} enerji</p>

          {isLoading ? (
            <div className="text-center text-sm text-[var(--text-muted)] py-8">Hedefler aranıyor...</div>
          ) : targets.length === 0 ? (
            <div className="text-center text-sm text-[var(--text-muted)] py-8">Uygun hedef bulunamadı</div>
          ) : (
            targets.map((t) => (
              <Card key={t.player_id}>
                <div className="p-3 flex items-center justify-between">
                  <div>
                    <p className="text-sm font-semibold text-[var(--text-primary)]">{t.username}</p>
                    <p className="text-xs text-[var(--text-muted)]">Lv.{t.level} • 💰{formatGold(t.estimated_gold)} • ⭐{t.rating}</p>
                  </div>
                  <Button variant="danger" size="sm" disabled={restricted || energy < GAME_CONFIG.pvp.energyCost} isLoading={isAttacking}
                    onClick={() => handleAttack(t)}>Saldır</Button>
                </div>
              </Card>
            ))
          )}
          <Button variant="secondary" size="sm" fullWidth onClick={loadTargets}>🔄 Yenile</Button>
        </div>
      )}

      {/* Attack History Tab — Godot: attack_history_list */}
      {tab === "attack_history" && (
        <div className="space-y-2">
          {isLoading ? (
            <div className="text-center text-sm text-[var(--text-muted)] py-8">Yükleniyor...</div>
          ) : attackHistory.length === 0 ? (
            <div className="text-center text-sm text-[var(--text-muted)] py-8">Henüz saldırı geçmişi yok</div>
          ) : attackHistory.map((h, i) => renderBattleItem(h, i, true))}
        </div>
      )}

      {/* Defense History Tab — Godot: defense_history_list */}
      {tab === "defense_history" && (
        <div className="space-y-2">
          {isLoading ? (
            <div className="text-center text-sm text-[var(--text-muted)] py-8">Yükleniyor...</div>
          ) : defenseHistory.length === 0 ? (
            <div className="text-center text-sm text-[var(--text-muted)] py-8">Henüz savunma geçmişi yok</div>
          ) : defenseHistory.map((h, i) => renderBattleItem(h, i, false))}
        </div>
      )}

      {/* Stats Tab — Godot: StatsPanel with wins/losses/rating/rank */}
      {tab === "stats" && (
        <Card variant="elevated">
          <div className="p-4 space-y-3">
            <div className="grid grid-cols-2 gap-3 text-center">
              <div>
                <p className="text-2xl font-bold text-[var(--color-success)]">{pvpWins}</p>
                <p className="text-xs text-[var(--text-muted)]">Kazanılan</p>
              </div>
              <div>
                <p className="text-2xl font-bold text-[var(--color-error)]">{pvpLosses}</p>
                <p className="text-xs text-[var(--text-muted)]">Kaybedilen</p>
              </div>
              <div>
                <p className="text-2xl font-bold text-[var(--accent-light)]">{pvpRating}</p>
                <p className="text-xs text-[var(--text-muted)]">Puan</p>
              </div>
              <div>
                <p className="text-2xl font-bold text-[var(--text-primary)]">%{winRate}</p>
                <p className="text-xs text-[var(--text-muted)]">Kazanma Oranı</p>
              </div>
            </div>
          </div>
        </Card>
      )}

      {/* Battle Result Modal */}
      <Modal isOpen={battleResult !== null} onClose={() => setBattleResult(null)} title={battleResult?.won ? "🏆 Zafer!" : "💀 Yenilgi"} size="sm">
        {battleResult && (
          <div className="space-y-3 text-center">
            <p className="text-sm">
              {battleResult.won ? `${battleResult.opponent_name} adlı oyuncuyu yendin!` : `${battleResult.opponent_name} seni yendi.`}
            </p>
            <div className="text-sm space-y-1">
              <p>🪙 {battleResult.gold_change > 0 ? "+" : ""}{formatGold(battleResult.gold_change)} altın</p>
              <p>⭐ {battleResult.rating_change > 0 ? "+" : ""}{battleResult.rating_change} puan</p>
            </div>
            <Button variant="secondary" size="sm" fullWidth onClick={() => setBattleResult(null)}>Tamam</Button>
          </div>
        )}
      </Modal>

      {/* Battle Details Dialog — Godot: _on_view_battle_details with full battle_log */}
      <Modal isOpen={battleDetailOpen} onClose={() => setBattleDetailOpen(false)} title="Savaş Detayları" size="sm">
        {battleDetailData && (
          <div className="space-y-3 text-sm">
            <p>Saldırgan: {battleDetailData.opponent_name || "?"}</p>
            <p>Sonuç: {battleDetailData.result === "win" ? "Kazanıldı" : "Kaybedildi"}</p>
            <p>Puan Değişimi: {battleDetailData.rating_change > 0 ? "+" : ""}{battleDetailData.rating_change}</p>
            {battleDetailData.battle_log && battleDetailData.battle_log.length > 0 && (
              <div>
                <p className="font-semibold text-[var(--text-secondary)] mb-1">=== SAVAŞ KAYDI ===</p>
                <div className="text-xs text-[var(--text-muted)] space-y-0.5 max-h-40 overflow-y-auto">
                  {battleDetailData.battle_log.map((entry: string, i: number) => (
                    <p key={i}>• {entry}</p>
                  ))}
                </div>
              </div>
            )}
            <Button variant="secondary" size="sm" fullWidth onClick={() => setBattleDetailOpen(false)}>Kapat</Button>
          </div>
        )}
      </Modal>
    </div>
  );
}
