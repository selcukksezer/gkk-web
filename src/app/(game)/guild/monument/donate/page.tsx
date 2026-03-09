"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { supabase } from "@/lib/supabase";

export default function MonumentDonatePage() {
  const router = useRouter();
  const profile = usePlayerStore((s) => s.profile);
  const addToast = useUiStore((s) => s.addToast);
  
  const [loading, setLoading] = useState(false);
  const [structural, setStructural] = useState(0);
  const [mystical, setMystical] = useState(0);
  const [critical, setCritical] = useState(0);
  const [gold, setGold] = useState(0);

  const handleDonate = async () => {
    if (structural === 0 && mystical === 0 && critical === 0 && gold === 0) {
      addToast("Lütfen bağışlamak için bir miktar girin", "error");
      return;
    }

    setLoading(true);
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error("Oturum yok");

      const { data, error } = await supabase.rpc('donate_to_monument', {
        p_user_id: user.id,
        p_structural: structural,
        p_mystical: mystical,
        p_critical: critical,
        p_gold: gold
      });

      if (error) throw error;
      if (!data.success) throw new Error(data.error);

      addToast(`Bağış başarılı! +${data.score_added} Katkı Puanı`, "success");
      router.push("/guild/monument");
    } catch (err: any) {
      console.error(err);
      addToast(err.message || "Bağış yapılamadı", "error");
    } finally {
      setLoading(false);
    }
  };

  if (!profile?.guild_id) {
    return <div className="p-8 text-center">Lonca bulunamadı.</div>;
  }

  return (
    <div className="p-4 max-w-2xl mx-auto flex flex-col gap-6">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-bold text-blue-400">Anıta Bağış Yap</h1>
        <Button onClick={() => router.back()} variant="ghost">İptal</Button>
      </div>

      <Card className="p-6">
        <p className="text-slate-400 mb-6">Loncaya yapacağınız bağışlar anıtın seviyesini artırmanızı sağlar. Günlük limitlere dikkat edin.</p>
        
        <div className="flex flex-col gap-4 mb-6">
          <div>
            <label className="block text-sm mb-1 text-slate-300">Yapısal Kaynak (Max: 500/gün)</label>
            <input className="w-full bg-slate-800 p-2 rounded border border-slate-700" type="number" min={0} value={structural} onChange={(e: any) => setStructural(Number(e.target.value))} />
          </div>
          <div>
            <label className="block text-sm mb-1 text-slate-300">Mistik Kaynak (Max: 200/gün)</label>
            <input className="w-full bg-slate-800 p-2 rounded border border-slate-700" type="number" min={0} value={mystical} onChange={(e: any) => setMystical(Number(e.target.value))} />
          </div>
          <div>
            <label className="block text-sm mb-1 text-slate-300">Kritik Kaynak (Max: 50/gün)</label>
            <input className="w-full bg-slate-800 p-2 rounded border border-slate-700" type="number" min={0} value={critical} onChange={(e: any) => setCritical(Number(e.target.value))} />
          </div>
          <div>
            <label className="block text-sm mb-1 text-slate-300">Altın (Max: 10M/gün)</label>
            <input className="w-full bg-slate-800 p-2 rounded border border-slate-700" type="number" min={0} value={gold} onChange={(e: any) => setGold(Number(e.target.value))} />
          </div>
        </div>

        <Button fullWidth onClick={handleDonate} isLoading={loading}>
          Bağışı Gönder
        </Button>
      </Card>
    </div>
  );
}
