"use client";

import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { Card } from "@/components/ui/Card";
import { Spinner } from "@/components/ui/Spinner";
import { usePlayerStore } from "@/stores/playerStore";
import type { PvpMatch } from "@/types/pvp";

export default function PvpHistoryPage() {
  const profile = usePlayerStore((s) => s.profile);
  const [matches, setMatches] = useState<any[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const authId = profile?.auth_id ?? null;

  useEffect(() => {
    if (!authId) return;
    
    const fetchHistory = async () => {
      try {
        const { data, error } = await supabase
          .from("pvp_matches")
          .select("*, attacker:attacker_id(username), defender:defender_id(username)")
          .or(`attacker_id.eq.${authId},defender_id.eq.${authId}`)
          .order("created_at", { ascending: false })
          .limit(50);
          
        if (error) throw error;
        setMatches(data || []);
      } catch (err) {
        console.error("Error fetching pvp history", err);
      } finally {
        setIsLoading(false);
      }
    };
    
    fetchHistory();
  }, [authId]);

  if (isLoading) return <Spinner />;

  return (
    <div className="p-4 max-w-4xl mx-auto flex flex-col gap-6">
      <h1 className="text-2xl font-bold text-amber-500 mb-4">PvP Maç Geçmişi</h1>
      
      {matches.length === 0 ? (
        <Card className="p-8 text-center text-gray-500">
          Henüz hiç PvP maçınız bulunmuyor.
        </Card>
      ) : (
        <div className="flex flex-col gap-3">
          {matches.map((match) => {
            const isAttacker = match.attacker_id === authId;
            const isWinner = match.winner_id === authId;
            
            return (
              <Card key={match.id} className={`p-4 border-l-4 ${isWinner ? 'border-l-green-500 bg-green-900/10' : 'border-l-red-500 bg-red-900/10'}`}>
                <div className="flex justify-between items-center">
                  <div>
                    <div className="font-bold text-lg">
                      {isAttacker ? (
                        <span>Saldırdınız: <span className="text-red-400">{match.defender?.username || 'Bilinmeyen'}</span></span>
                      ) : (
                        <span>Savundunuz: <span className="text-amber-400">{match.attacker?.username || 'Bilinmeyen'}</span></span>
                      )}
                    </div>
                    <div className="text-sm text-gray-400 mt-1">
                      Sonuç: {isWinner ? 'Kazandınız' : 'Kaybettiniz'} | {match.is_critical_success ? '💥 Ezici Zafer' : ''}
                    </div>
                  </div>
                  <div className="text-right">
                    <div className={`font-bold ${isWinner ? 'text-amber-500' : 'text-gray-500'}`}>
                      {isWinner ? '+' : '-'}{match.gold_stolen?.toLocaleString() || 0} Gold
                    </div>
                    <div className={`text-sm ${isWinner ? 'text-blue-400' : 'text-gray-500'}`}>
                      {isWinner ? '+' : '-'}{isWinner ? match.rep_change_winner : match.rep_change_loser} Rep
                    </div>
                  </div>
                </div>
              </Card>
            );
          })}
        </div>
      )}
    </div>
  );
}
