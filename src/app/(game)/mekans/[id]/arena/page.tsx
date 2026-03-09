"use client";

import { use } from "react";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { Spinner } from "@/components/ui/Spinner";
import { supabase } from "@/lib/supabase";
import { timeAgo } from "@/lib/utils/datetime";

interface ArenaMatch {
  id: string;
  winner_id: string | null;
  gold_stolen: number;
  is_critical_success: boolean;
  created_at: string;
}

export default function ArenaPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const router = useRouter();
  const [matches, setMatches] = useState<ArenaMatch[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const loadArenaActivity = async () => {
      setLoading(true);
      try {
        const { data, error } = await supabase
          .from("pvp_matches")
          .select("id, winner_id, gold_stolen, is_critical_success, created_at")
          .eq("mekan_id", id)
          .order("created_at", { ascending: false })
          .limit(8);

        if (error) throw error;
        setMatches((data as ArenaMatch[] | null) ?? []);
      } catch (error) {
        console.error(error);
      } finally {
        setLoading(false);
      }
    };

    void loadArenaActivity();
  }, [id]);

  if (loading) {
    return <Spinner />;
  }

  return (
    <div className="p-4 max-w-4xl mx-auto flex flex-col gap-6">
      <div className="text-center">
        <h1 className="text-3xl font-bold text-red-500">PvP Arena Merkezi</h1>
        <p className="text-gray-400">Bu mekan için son PvP aktivitesini görebilir, geçmişe gidebilir ve genel PvP yüzeylerine geçebilirsin.</p>
      </div>

      <div className="grid gap-4 md:grid-cols-3">
        <Card className="p-4 text-center">
          <h2 className="text-lg font-bold text-white">Maç Geçmişi</h2>
          <p className="mt-2 text-sm text-slate-400">Son savaşların sonucunu ve ganimeti görüntüle.</p>
          <Button className="mt-4" fullWidth onClick={() => router.push("/pvp/history")}>Geçmişe Git</Button>
        </Card>
        <Card className="p-4 text-center">
          <h2 className="text-lg font-bold text-white">Haftalık Turnuva</h2>
          <p className="mt-2 text-sm text-slate-400">Kural seti, ödül akışı ve sezon durumu burada.</p>
          <Button className="mt-4" variant="secondary" fullWidth onClick={() => router.push("/pvp/tournament")}>Turnuva Ekranı</Button>
        </Card>
        <Card className="p-4 text-center">
          <h2 className="text-lg font-bold text-white">Mekana Dön</h2>
          <p className="mt-2 text-sm text-slate-400">Stok ve diğer mekan aktivitelerine geri dön.</p>
          <Button className="mt-4" variant="ghost" fullWidth onClick={() => router.push(`/mekans/${id}`)}>Geri Dön</Button>
        </Card>
      </div>

      <Card className="p-5 bg-slate-900 border-slate-800">
        <h2 className="text-lg font-bold text-amber-400">Arena Durumu</h2>
        <div className="mt-3 grid gap-3 md:grid-cols-2 text-sm text-slate-300">
          <div className="rounded-lg bg-slate-800/70 p-3">Genel PvP geçmişi ve turnuva kuralları bu merkezden erişilebilir.</div>
          <div className="rounded-lg bg-slate-800/70 p-3">Mekana ait son maçlar aşağıda listelenir.</div>
          <div className="rounded-lg bg-slate-800/70 p-3">Bahis ve canlı eşleşme akışı ilerleyen entegrasyon için ayrı tutulur.</div>
          <div className="rounded-lg bg-slate-800/70 p-3">Bu ekran dead-end yerine aktif arena panosu olarak çalışır.</div>
        </div>
      </Card>

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