"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Spinner } from "@/components/ui/Spinner";
import { isInHospital, isInPrison } from "@/lib/utils/validation";
import { timeAgo } from "@/lib/utils/datetime";
import { supabase } from "@/lib/supabase";
import type { PvpMatch } from "@/types/pvp";

interface PvpArena {
  id: string;
  name: string;
  mekan_type: string;
}

export default function PvPPage() {
  const router = useRouter();
  const profile = usePlayerStore((s) => s.profile);
  const energy = usePlayerStore((s) => s.energy);
  const hospitalUntil = usePlayerStore((s) => s.hospitalUntil);
  const prisonUntil = usePlayerStore((s) => s.prisonUntil);
  const pvpWins = usePlayerStore((s) => s.pvpWins);
  const pvpLosses = usePlayerStore((s) => s.pvpLosses);
  const pvpRating = usePlayerStore((s) => s.pvpRating);
  const addToast = useUiStore((s) => s.addToast);

  const [arenas, setArenas] = useState<PvpArena[]>([]);
  const [matches, setMatches] = useState<PvpMatch[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  const restricted = isInHospital(hospitalUntil) || isInPrison(prisonUntil);
  const currentAuthId = profile?.auth_id ?? null;

  useEffect(() => {
    if (!currentAuthId) {
      setIsLoading(false);
      return;
    }

    const loadPvpData = async () => {
      setIsLoading(true);
      try {
        const [{ data: arenaData, error: arenaError }, { data: matchData, error: matchError }] = await Promise.all([
          supabase
            .from("mekans")
            .select("id, name, mekan_type")
            .in("mekan_type", ["dovus_kulubu", "luks_lounge", "yeralti"])
            .eq("is_open", true)
            .order("name", { ascending: true }),
          supabase
            .from("pvp_matches")
            .select("*")
            .or(`attacker_id.eq.${currentAuthId},defender_id.eq.${currentAuthId}`)
            .order("created_at", { ascending: false })
            .limit(8),
        ]);

        if (arenaError) throw arenaError;
        if (matchError) throw matchError;

        setArenas((arenaData as PvpArena[] | null) ?? []);
        setMatches((matchData as PvpMatch[] | null) ?? []);
      } catch (error) {
        console.error(error);
        addToast("PvP verileri yüklenemedi", "error");
      } finally {
        setIsLoading(false);
      }
    };

    void loadPvpData();
  }, [addToast, currentAuthId]);

  const winRate = useMemo(() => {
    const totalMatches = pvpWins + pvpLosses;
    return totalMatches > 0 ? Math.round((pvpWins / totalMatches) * 100) : 0;
  }, [pvpLosses, pvpWins]);

  const recentMatches = useMemo(() => {
    return matches.map((match) => {
      const isAttacker = match.attacker_id === currentAuthId;
      const didWin = match.winner_id === currentAuthId;

      return {
        id: match.id,
        title: isAttacker ? "Saldırı" : "Savunma",
        didWin,
        hpRemaining: isAttacker ? match.attacker_hp_remaining : match.defender_hp_remaining,
        goldDelta: didWin ? match.gold_stolen : -match.gold_stolen,
        repDelta: didWin ? match.rep_change_winner : -match.rep_change_loser,
        createdAt: match.created_at,
        isCritical: match.is_critical_success,
      };
    });
  }, [currentAuthId, matches]);

  if (isLoading) {
    return <Spinner />;
  }

  const handleArenaNavigation = (arenaId: string) => {
    if (restricted) {
      addToast("Hastane veya hapishane durumunda PvP arenasına girilemez", "warning");
      return;
    }

    router.push(`/mekans/${arenaId}/arena`);
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

      <Card>
        <div className="p-4 space-y-3">
          <p className="text-sm text-[var(--text-secondary)]">
            Doğrudan rakip arama akışı kaldırıldı. PvP artık açık mekan arenaları üzerinden başlatılıyor.
          </p>
          <div className="grid grid-cols-3 gap-3 text-center text-xs">
            <div className="rounded-lg bg-[var(--bg-card)] p-3">
              <div className="text-[var(--text-muted)]">Rating</div>
              <div className="mt-1 text-lg font-bold text-[var(--text-primary)]">{pvpRating}</div>
            </div>
            <div className="rounded-lg bg-[var(--bg-card)] p-3">
              <div className="text-[var(--text-muted)]">Kazanma Oranı</div>
              <div className="mt-1 text-lg font-bold text-[var(--text-primary)]">%{winRate}</div>
            </div>
            <div className="rounded-lg bg-[var(--bg-card)] p-3">
              <div className="text-[var(--text-muted)]">Enerji</div>
              <div className="mt-1 text-lg font-bold text-[var(--text-primary)]">{energy}</div>
            </div>
          </div>
          <div className="flex gap-2">
            <Button variant="secondary" size="sm" onClick={() => router.push("/pvp/history")}>Geçmişi Aç</Button>
            <Button variant="secondary" size="sm" onClick={() => router.push("/pvp/tournament")}>Turnuva</Button>
          </div>
        </div>
      </Card>

      <div className="space-y-3">
        <h3 className="text-sm font-semibold text-[var(--text-primary)]">Açık Arenalar</h3>
        {arenas.length === 0 ? (
          <Card>
            <div className="p-4 text-sm text-[var(--text-muted)]">Şu anda açık PvP mekanı bulunmuyor.</div>
          </Card>
        ) : (
          arenas.map((arena) => (
            <Card key={arena.id}>
              <div className="flex items-center justify-between p-4">
                <div>
                  <p className="text-sm font-semibold text-[var(--text-primary)]">{arena.name}</p>
                  <p className="text-xs text-[var(--text-muted)]">{arena.mekan_type.replaceAll("_", " ")}</p>
                </div>
                <Button size="sm" disabled={restricted} onClick={() => handleArenaNavigation(arena.id)}>
                  Arenaya Git
                </Button>
              </div>
            </Card>
          ))
        )}
      </div>

      <div className="space-y-3">
        <h3 className="text-sm font-semibold text-[var(--text-primary)]">Son Maçlar</h3>
        {recentMatches.length === 0 ? (
          <Card>
            <div className="p-4 text-sm text-[var(--text-muted)]">Henüz kayıtlı PvP maçın bulunmuyor.</div>
          </Card>
        ) : (
          recentMatches.map((match) => (
            <Card key={match.id}>
              <div className="p-4">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm font-semibold text-[var(--text-primary)]">{match.title}</p>
                    <p className="text-xs text-[var(--text-muted)]">{timeAgo(match.createdAt)}</p>
                  </div>
                  <span className={`text-xs font-bold ${match.didWin ? "text-[var(--color-success)]" : "text-[var(--color-error)]"}`}>
                    {match.didWin ? "Kazandın" : "Kaybettin"}
                  </span>
                </div>
                <div className="mt-2 flex items-center justify-between text-xs text-[var(--text-muted)]">
                  <span>Can: {match.hpRemaining}</span>
                  <span>{match.goldDelta >= 0 ? "+" : ""}{match.goldDelta.toLocaleString()} gold</span>
                  <span>{match.repDelta >= 0 ? "+" : ""}{match.repDelta} rep</span>
                </div>
                {match.isCritical && <p className="mt-2 text-xs text-amber-400">Kritik zafer kaydı</p>}
              </div>
            </Card>
          ))
        )}
      </div>
    </div>
  );
}
