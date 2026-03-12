"use client";

import { use } from "react";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { Spinner } from "@/components/ui/Spinner";
import { supabase } from "@/lib/supabase";
import { timeAgo } from "@/lib/utils/datetime";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { GAME_CONFIG } from "@/data/GameConstants";

interface ArenaMatch {
  id: string;
  winner_id: string | null;
  gold_stolen: number;
  is_critical_success: boolean;
  created_at: string;
}

interface ArenaOpponent {
  auth_id: string;
  username: string;
  level: number;
  pvp_rating: number;
}

export default function ArenaPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const router = useRouter();
  const profile = usePlayerStore((s) => s.profile);
  const energy = usePlayerStore((s) => s.energy);
  const consumeEnergy = usePlayerStore((s) => s.consumeEnergy);
  const fetchProfile = usePlayerStore((s) => s.fetchProfile);
  const addToast = useUiStore((s) => s.addToast);

  const [matches, setMatches] = useState<ArenaMatch[]>([]);
  const [opponents, setOpponents] = useState<ArenaOpponent[]>([]);
  const [loading, setLoading] = useState(true);
  const [attackingId, setAttackingId] = useState<string | null>(null);
  const [battleResult, setBattleResult] = useState<{
    won: boolean;
    goldStolen: number;
    ratingChange: number;
    isCritical?: boolean;
  } | null>(null);

  const energyCost = GAME_CONFIG.pvp.energyCost;

  useEffect(() => {
    const loadArenaData = async () => {
      setLoading(true);
      try {
        const [{ data: matchData }, { data: opponentData }] = await Promise.all([
          supabase
            .from("pvp_matches")
            .select("id, winner_id, gold_stolen, is_critical_success, created_at")
            .eq("mekan_id", id)
            .order("created_at", { ascending: false })
            .limit(8),
          supabase
            .from("users")
            .select("auth_id, username, level, pvp_rating")
            .neq("auth_id", profile?.auth_id ?? "")
            .gte("level", 1)
            .is("hospital_until", null)
            .is("prison_until", null)
            .order("pvp_rating", { ascending: false })
            .limit(10),
        ]);

        setMatches((matchData as ArenaMatch[] | null) ?? []);
        setOpponents((opponentData as ArenaOpponent[] | null) ?? []);
      } catch (error) {
        console.error(error);
      } finally {
        setLoading(false);
      }
    };

    void loadArenaData();
  }, [id, profile?.auth_id]);

  const handleAttack = async (opponentId: string) => {
    if (!profile?.auth_id) {
      addToast("Oturum bulunamadı!", "error");
      return;
    }
    if (energy < energyCost) {
      addToast(`Yetersiz enerji! (${energyCost} gerekli)`, "error");
      return;
    }

    setAttackingId(opponentId);
    try {
      const { data, error } = await supabase.rpc("pvp_attack", {
        p_attacker_id: profile.auth_id,
        p_defender_id: opponentId,
        p_mekan_id: id,
      });

      if (error) throw error;

      const result = data as {
        success: boolean;
        winner_id: string;
        gold_stolen: number;
        rep_change_winner: number;
        rep_change_loser: number;
        rating_change_attacker: number;
        hospital_triggered: boolean;
        is_critical_success?: boolean;
      };

      const won = result.winner_id === profile.auth_id;
      consumeEnergy(energyCost);
      setBattleResult({
        won,
        goldStolen: result.gold_stolen,
        ratingChange: result.rating_change_attacker,
        isCritical: result.is_critical_success,
      });

      if (won) {
        if (result.is_critical_success) {
          addToast(`💥 KRİTİK ZAFER! +${result.gold_stolen} altın`, "success");
        } else {
          addToast(`Zafer! +${result.gold_stolen} altın, +${result.rating_change_attacker} rating`, "success");
        }
      } else {
        addToast(`Yenilgi! ${result.rating_change_attacker} rating`, "error");
      }

      fetchProfile();

      // Reload arena matches after attack
      const { data: newMatches } = await supabase
        .from("pvp_matches")
        .select("id, winner_id, gold_stolen, is_critical_success, created_at")
        .eq("mekan_id", id)
        .order("created_at", { ascending: false })
        .limit(8);
      setMatches((newMatches as ArenaMatch[] | null) ?? []);
    } catch (err) {
      console.error(err);
      addToast("Saldırı başarısız — sunucu hatası", "error");
    } finally {
      setAttackingId(null);
    }
  };

  if (loading) {
    return <Spinner />;
  }

  return (
    <div className="p-4 max-w-4xl mx-auto flex flex-col gap-6">
      <div className="text-center">
        <h1 className="text-3xl font-bold text-red-500">⚔️ PvP Arena</h1>
        <p className="text-gray-400 text-sm mt-1">Rakip seç ve saldır. Enerji: {energy} / {energyCost} gerekli.</p>
      </div>

      {/* Battle Result Banner */}
      {battleResult && (
        <Card className={`p-4 text-center border-2 ${battleResult.won ? (battleResult.isCritical ? "border-amber-400 bg-amber-900/40 animate-pulse scale-105" : "border-green-400 bg-green-900/20") : "border-red-400 bg-red-900/20"}`}>
          {battleResult.won && battleResult.isCritical && (
            <div className="text-5xl mb-2 animate-bounce">💥</div>
          )}
          <p className={`text-lg font-bold ${battleResult.won ? (battleResult.isCritical ? "text-amber-400 text-2xl" : "text-green-300") : "text-red-300"}`}>
            {battleResult.won ? (battleResult.isCritical ? "💥 ŞAHLANMA! EZİCİ ZAFER!" : "🏆 ZAFER!") : "💀 YENİLGİ!"}
          </p>
          <p className="text-sm text-gray-300 mt-1">
            {battleResult.won
              ? `+${battleResult.goldStolen.toLocaleString()} altın kazandın`
              : `${battleResult.goldStolen.toLocaleString()} altın kaybettin`}
            {" · "}Rating: {battleResult.ratingChange >= 0 ? "+" : ""}{battleResult.ratingChange}
          </p>
          <button className="mt-2 text-xs text-gray-500 hover:text-gray-300" onClick={() => setBattleResult(null)}>
            Kapat
          </button>
        </Card>
      )}

      <div className="grid gap-4 md:grid-cols-3">
        <Button onClick={() => router.push("/pvp/history")} fullWidth>Maç Geçmişi</Button>
        <Button variant="secondary" onClick={() => router.push("/pvp/tournament")} fullWidth>Turnuva</Button>
        <Button variant="ghost" onClick={() => router.push(`/mekans/${id}`)} fullWidth>Mekana Dön</Button>
      </div>

      {/* Opponent List */}
      <Card className="p-5 bg-slate-900 border-slate-800">
        <h2 className="text-lg font-bold text-amber-400 mb-4">Rakipler</h2>
        {opponents.length === 0 ? (
          <p className="text-sm text-slate-400">Şu an saldırılabilecek rakip yok.</p>
        ) : (
          <div className="space-y-3">
            {opponents.map((opponent) => (
              <div key={opponent.auth_id} className="flex items-center justify-between rounded-lg bg-slate-800/70 p-3">
                <div>
                  <p className="text-sm font-semibold text-white">{opponent.username}</p>
                  <p className="text-xs text-slate-400">Sev. {opponent.level} · Rating {opponent.pvp_rating}</p>
                </div>
                <Button
                  size="sm"
                  variant="primary"
                  disabled={energy < energyCost || attackingId !== null || opponent.auth_id === profile?.auth_id}
                  isLoading={attackingId === opponent.auth_id}
                  onClick={() => handleAttack(opponent.auth_id)}
                >
                  Saldır
                </Button>
              </div>
            ))}
          </div>
        )}
      </Card>

      {/* Recent Arena Matches */}
      <Card className="p-5 bg-slate-900 border-slate-800">
        <h2 className="text-lg font-bold text-blue-400">Son Arena Maçları</h2>
        {matches.length === 0 ? (
          <p className="mt-3 text-sm text-slate-400">Bu mekanda henüz kayıtlı PvP maçı yok.</p>
        ) : (
          <div className="mt-4 space-y-3">
            {matches.map((match) => (
              <div key={match.id} className="rounded-lg bg-slate-800/70 p-3 text-sm text-slate-200">
                <div className="flex items-center justify-between">
                  <span>Maç #{match.id.slice(0, 8)}</span>
                  <span className="text-slate-400">{timeAgo(match.created_at)}</span>
                </div>
                <div className="mt-2 flex items-center justify-between text-xs text-slate-400">
                  <span>{match.gold_stolen.toLocaleString()} gold el değiştirdi</span>
                  <span>{match.is_critical_success ? "Kritik zafer" : "Standart sonuç"}</span>
                </div>
              </div>
            ))}
          </div>
        )}
      </Card>
    </div>
  );
}

