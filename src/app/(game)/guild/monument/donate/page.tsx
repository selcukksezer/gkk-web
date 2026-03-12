"use client";

import { useState, useEffect } from "react";
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

  const [donatedToday, setDonatedToday] = useState({
    structural: 0,
    mystical: 0,
    critical: 0,
    gold: 0,
  });
  
  useEffect(() => {
    async function fetchDailyDonations() {
      if (!profile?.auth_id || !profile?.guild_id) return;
      
      const today = new Date().toISOString().split('T')[0];
      const { data, error } = await supabase
        .from('guild_daily_donations')
        .select('structural_today, mystical_today, critical_today, gold_today')
        .eq('user_id', profile.auth_id)
        .eq('guild_id', profile.guild_id)
        .eq('donation_date', today)
        .single();
        
      if (!error && data) {
        setDonatedToday({
          structural: data.structural_today || 0,
          mystical: data.mystical_today || 0,
          critical: data.critical_today || 0,
          gold: data.gold_today || 0,
        });
      }
    }
    fetchDailyDonations();
  }, [profile?.auth_id, profile?.guild_id]);

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
            <label className="flex justify-between text-sm mb-1 text-slate-300">
              <span>Yapısal Kaynak</span>
              <span className="text-slate-500">Bugün: {donatedToday.structural}/500</span>
            </label>
            <input className="w-full bg-slate-800 p-2 rounded border border-slate-700" type="number" min={0} max={Math.max(0, 500 - donatedToday.structural)} value={structural} onChange={(e: any) => setStructural(Math.min(Math.max(0, 500 - donatedToday.structural), Number(e.target.value)))} />
            <div className="h-1 w-full bg-slate-800 mt-1 rounded"><div className="h-full bg-blue-500 rounded" style={{width: `${(donatedToday.structural/500)*100}%`}}></div></div>
          </div>
          <div>
            <label className="flex justify-between text-sm mb-1 text-slate-300">
              <span>Mistik Kaynak</span>
              <span className="text-slate-500">Bugün: {donatedToday.mystical}/200</span>
            </label>
            <input className="w-full bg-slate-800 p-2 rounded border border-slate-700" type="number" min={0} max={Math.max(0, 200 - donatedToday.mystical)} value={mystical} onChange={(e: any) => setMystical(Math.min(Math.max(0, 200 - donatedToday.mystical), Number(e.target.value)))} />
            <div className="h-1 w-full bg-slate-800 mt-1 rounded"><div className="h-full bg-purple-500 rounded" style={{width: `${(donatedToday.mystical/200)*100}%`}}></div></div>
          </div>
          <div>
            <label className="flex justify-between text-sm mb-1 text-slate-300">
              <span>Kritik Kaynak</span>
              <span className="text-slate-500">Bugün: {donatedToday.critical}/50</span>
            </label>
            <input className="w-full bg-slate-800 p-2 rounded border border-slate-700" type="number" min={0} max={Math.max(0, 50 - donatedToday.critical)} value={critical} onChange={(e: any) => setCritical(Math.min(Math.max(0, 50 - donatedToday.critical), Number(e.target.value)))} />
            <div className="h-1 w-full bg-slate-800 mt-1 rounded"><div className="h-full bg-red-500 rounded" style={{width: `${(donatedToday.critical/50)*100}%`}}></div></div>
          </div>
          <div>
            <label className="flex justify-between text-sm mb-1 text-slate-300">
              <span>Altın</span>
              <span className="text-slate-500">Bugün: {donatedToday.gold.toLocaleString()}/10M</span>
            </label>
            <input className="w-full bg-slate-800 p-2 rounded border border-slate-700" type="number" min={0} max={Math.max(0, 10000000 - donatedToday.gold)} value={gold} onChange={(e: any) => setGold(Math.min(Math.max(0, 10000000 - donatedToday.gold), Number(e.target.value)))} />
            <div className="h-1 w-full bg-slate-800 mt-1 rounded"><div className="h-full bg-yellow-500 rounded" style={{width: `${(donatedToday.gold/10000000)*100}%`}}></div></div>
          </div>
        </div>

        <Button fullWidth onClick={handleDonate} isLoading={loading}>
          Bağışı Gönder
        </Button>
      </Card>
    </div>
  );
}
