"use client";

import { useEffect, useState, useMemo } from "react";
import { useRouter } from "next/navigation";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Spinner } from "@/components/ui/Spinner";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { useInventoryStore } from "@/stores/inventoryStore";
import { supabase } from "@/lib/supabase";

interface GuildContributionRow {
  user_id: string;
  contribution_score: number;
  gold_donated: number;
}

interface GuildBlueprintRow {
  blueprint_type: string;
  fragments: number;
  fragments_required: number;
  is_complete: boolean;
}

interface MonumentUpgradeRpc {
  success: boolean;
  new_level?: number;
  error?: string;
}

// Monument bonuses (PLAN_10 §5)
const MONUMENT_BONUSES = [
  { level: 5, type: "XP Bonusu", bonus: "+%5 XP" },
  { level: 10, type: "Gold Bonusu", bonus: "+%3 Gold" },
  { level: 15, type: "Max Enerji", bonus: "+5 Max Enerji" },
  { level: 20, type: "Overdose Koruması", bonus: "-%10 Overdose Şansı" },
  { level: 25, type: "Tesis Hız", bonus: "-%5 Üretim Süresi" },
  { level: 30, type: "Zindan Şansı", bonus: "+10 Loot Şansı" },
  { level: 35, type: "Crafting Bonusu", bonus: "+%3 Craft Başarısı" },
  { level: 40, type: "PvP Kalkanı", bonus: "+%5 PvP Savunması" },
];

// Size multiplier (PLAN_10 §3.0)
function getGuildSizeMultiplier(memberCount: number): { multiplier: number; label: string } {
  if (memberCount <= 10) return { multiplier: 0.35, label: "Küçük Lonca" };
  if (memberCount <= 20) return { multiplier: 0.55, label: "Orta Lonca" };
  if (memberCount <= 30) return { multiplier: 0.75, label: "Büyük Lonca" };
  if (memberCount <= 40) return { multiplier: 0.9, label: "Çok Büyük Lonca" };
  return { multiplier: 1.0, label: "Maksimum Lonca" };
}

export default function GuildMonumentPage() {
  const router = useRouter();
  const profile = usePlayerStore((s) => s.profile);
  const addToast = useUiStore((s) => s.addToast);
  const inventoryItems = useInventoryStore((s) => s.items);
  const fetchInventory = useInventoryStore((s) => s.fetchInventory);
  
  const [guild, setGuild] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [upgradeLoading, setUpgradeLoading] = useState(false);
  const [memberCount, setMemberCount] = useState(0);
  const [topContributors, setTopContributors] = useState<GuildContributionRow[]>([]);
  const [blueprints, setBlueprints] = useState<GuildBlueprintRow[]>([]);

  useEffect(() => {
    if (!profile?.guild_id) {
      setLoading(false);
      return;
    }
    
    const fetchGuild = async () => {
      try {
        const [{ data: guildData, error: guildError }, { count }, { data: contributionData, error: contributionError }, { data: blueprintData, error: blueprintError }] = await Promise.all([
          supabase.from("guilds").select("*").eq("id", profile.guild_id).single(),
          supabase.from("users").select("id", { count: "exact", head: true }).eq("guild_id", profile.guild_id),
          supabase
            .from("guild_contributions")
            .select("user_id, contribution_score, gold_donated")
            .eq("guild_id", profile.guild_id)
            .order("contribution_score", { ascending: false })
            .limit(5),
          supabase
            .from("guild_blueprints")
            .select("blueprint_type, fragments, fragments_required, is_complete")
            .eq("guild_id", profile.guild_id)
            .order("blueprint_type", { ascending: true }),
        ]);

        if (guildError) throw guildError;
        if (contributionError) throw contributionError;
        if (blueprintError) throw blueprintError;

        setGuild(guildData);
        setMemberCount(count || 0);
        setTopContributors((contributionData as GuildContributionRow[] | null) ?? []);
        setBlueprints((blueprintData as GuildBlueprintRow[] | null) ?? []);
      } catch (error) {
        console.error(error);
        addToast("Anıt verileri yüklenemedi", "error");
      } finally {
        setLoading(false);
      }
    };
    void fetchGuild();
  }, [addToast, profile]);
  
  const sizeMultiplier = useMemo(
    () => getGuildSizeMultiplier(memberCount),
    [memberCount]
  );

  const canUpgrade = profile?.guild_role === "leader" || profile?.guild_role === "commander";

  const handleUpgrade = async () => {
    if (!profile?.auth_id) {
      addToast("Oturum bilgisi bulunamadı", "error");
      return;
    }

    setUpgradeLoading(true);
    try {
      const { data, error } = await supabase.rpc("upgrade_monument", { p_user_id: profile.auth_id });
      if (error) throw error;

      const response = data as MonumentUpgradeRpc | null;
      if (!response?.success) {
        throw new Error(response?.error || "Anıt yükseltilemedi");
      }

      setGuild((currentGuild: any) => currentGuild ? { ...currentGuild, monument_level: response.new_level ?? currentGuild.monument_level } : currentGuild);
      addToast(`Anıt seviye ${response.new_level} oldu`, "success");
    } catch (error) {
      console.error(error);
      addToast(error instanceof Error ? error.message : "Anıt yükseltilemedi", "error");
    } finally {
      setUpgradeLoading(false);
    }
  };

  if (loading) return <Spinner />;

  if (!profile?.guild_id) {
    return (
      <div className="p-8 text-center">
        <h1 className="text-2xl text-red-500 mb-4">Bir Loncaya Üye Değilsiniz</h1>
        <Button onClick={() => router.push("/guild")}>Lonca Bul</Button>
      </div>
    );
  }

  return (
    <div className="p-4 max-w-4xl mx-auto flex flex-col gap-6">
      <div className="flex justify-between items-center">
        <h1 className="text-3xl font-bold text-blue-400">Lonca Anıtı</h1>
        <div className="flex gap-2">
          <Button onClick={() => router.push("/guild/monument/donate")} variant="primary">
            Bağış Yap
          </Button>
          {canUpgrade && (
            <Button onClick={handleUpgrade} variant="secondary" isLoading={upgradeLoading}>
              Yükselt
            </Button>
          )}
        </div>
      </div>
      
      <Card className="p-6 bg-slate-900 border-blue-900">
        <div className="flex flex-col md:flex-row gap-8 items-center">
          <div className="w-48 h-48 bg-slate-800 rounded-lg flex items-center justify-center border-4 border-blue-500 shadow-[0_0_15px_rgba(59,130,246,0.5)]">
            <span className="text-4xl">🏛️</span>
          </div>
          
          <div className="flex-1 w-full">
            <h2 className="text-2xl font-bold mb-2">Seviye {guild?.monument_level || 0} Anıt</h2>
            <p className="text-slate-400 mb-4">Lonca üyelerinin güçlerini birleştirerek yükselttiği kutsal yapı.</p>
            
            <div className="bg-slate-700 p-3 rounded mb-4 text-xs border border-slate-600">
              <div className="text-slate-400 mb-1">Lonca Büyüklüğü</div>
              <div className="flex justify-between items-center">
                <span className="font-bold">{memberCount} / 50 Aktif Üye</span>
                <span className="text-amber-500 font-bold">{sizeMultiplier.label} ({sizeMultiplier.multiplier.toFixed(2)}x)</span>
              </div>
            </div>
            
            <div className="grid grid-cols-2 gap-4">
              <div className="bg-slate-800 p-3 rounded">
                <div className="text-xs text-slate-400">Yapısal Kaynak</div>
                <div className="font-bold">{guild?.monument_structural?.toLocaleString() || 0}</div>
              </div>
              <div className="bg-slate-800 p-3 rounded">
                <div className="text-xs text-slate-400">Mistik Kaynak</div>
                <div className="font-bold">{guild?.monument_mystical?.toLocaleString() || 0}</div>
              </div>
              <div className="bg-slate-800 p-3 rounded">
                <div className="text-xs text-slate-400">Kritik Kaynak</div>
                <div className="font-bold">{guild?.monument_critical?.toLocaleString() || 0}</div>
              </div>
              <div className="bg-slate-800 p-3 rounded">
                <div className="text-xs text-slate-400">Altın Havuzu</div>
                <div className="font-bold text-amber-500">{guild?.monument_gold_pool?.toLocaleString() || 0}</div>
              </div>
            </div>
          </div>
        </div>
      </Card>
      
      {/* Monument Bonuses */}
      <Card className="p-6 bg-slate-900 border-purple-900">
        <h3 className="text-lg font-bold text-purple-400 mb-4">✨ Anıt Bonusları</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-3">
          {MONUMENT_BONUSES.map((bonus) => (
            <div key={bonus.level} className="bg-slate-800 p-3 rounded border border-slate-700 text-xs">
              <div className="text-slate-400">Lv {bonus.level}</div>
              <div className="font-bold text-white mb-1">{bonus.type}</div>
              <div className="text-green-400 font-medium">{bonus.bonus}</div>
            </div>
          ))}
        </div>
      </Card>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Card className="p-6 bg-slate-900 border-amber-900">
          <h3 className="text-lg font-bold text-amber-400 mb-4">🏆 Katkı Liderleri</h3>
          {topContributors.length === 0 ? (
            <p className="text-sm text-slate-400">Henüz katkı kaydı bulunmuyor.</p>
          ) : (
            <div className="space-y-3">
              {topContributors.map((contributor, index) => (
                <div key={`${contributor.user_id}-${index}`} className="flex items-center justify-between rounded bg-slate-800 px-3 py-2 text-sm">
                  <span className="text-slate-300">#{index + 1} {contributor.user_id.slice(0, 8)}</span>
                  <span className="font-bold text-amber-400">{contributor.contribution_score.toLocaleString()}</span>
                </div>
              ))}
            </div>
          )}
        </Card>

        <Card className="p-6 bg-slate-900 border-emerald-900">
          <div className="flex justify-between items-center mb-4">
            <h3 className="text-lg font-bold text-emerald-400">🧩 Blueprint İlerlemesi</h3>
          </div>
          {blueprints.length === 0 ? (
            <p className="text-sm text-slate-400 mb-4">Henüz blueprint ilerlemesi yok.</p>
          ) : (
            <div className="space-y-3 mb-6">
              {blueprints.map((blueprint) => (
                <div key={blueprint.blueprint_type} className="rounded bg-slate-800 p-3 text-sm">
                  <div className="flex items-center justify-between">
                    <span className="font-semibold text-white">{blueprint.blueprint_type}</span>
                    <span className={blueprint.is_complete ? "text-emerald-400" : "text-slate-400"}>
                      {blueprint.is_complete ? "Tamamlandı" : `${blueprint.fragments}/${blueprint.fragments_required}`}
                    </span>
                  </div>
                </div>
              ))}
            </div>
          )}
          
          <div className="mt-4 pt-4 border-t border-slate-700">
            <h4 className="text-sm font-semibold text-amber-400 mb-2">♻️ Fazla Blueprint Parçalama</h4>
            <p className="text-xs text-slate-400 mb-3">
              Tamamlanmış veya fazla olan blueprintlerinizi parçalayarak loncaya 3-10 arası Critical Kaynak ekleyebilirsiniz.
            </p>
            <div className="space-y-2 max-h-32 overflow-y-auto pr-1">
              {blueprints.filter(b => b.fragments > 0).length === 0 ? (
                <p className="text-xs text-slate-500 italic">Parçalanabilecek blueprint parçası bulunmuyor.</p>
              ) : (
                blueprints.filter(b => b.fragments > 0).map(blueprint => (
                  <div key={blueprint.blueprint_type} className="flex justify-between items-center bg-slate-800 p-2 rounded">
                    <span className="text-xs text-white">{blueprint.blueprint_type} <span className="text-slate-400">(x{blueprint.fragments})</span></span>
                    <Button
                      size="sm"
                      variant="danger"
                      onClick={async () => {
                        try {
                          const { api } = await import("@/lib/api");
                          const res = await api.rpc("dismantle_blueprint", { p_blueprint_type: blueprint.blueprint_type });
                          if (res.success && (res.data as any)?.success) {
                            addToast((res.data as any)?.message, "success");
                            // refresh page or reload guild data
                            window.location.reload();
                          } else {
                            addToast((res.data as any)?.message || "Parçalama başarısız", "error");
                          }
                        } catch(err) {
                          addToast("Parçalama işlemi sırasında bir hata oluştu", "error");
                        }
                      }}
                    >
                      Parçala
                    </Button>
                  </div>
                ))
              )}
            </div>
          </div>
        </Card>
      </div>
    </div>
  );
}
