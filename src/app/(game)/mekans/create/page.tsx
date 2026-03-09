"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useMekanStore } from "@/stores/mekanStore";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { MekanType } from "@/types/mekan";

const MEKAN_TYPES = [
  { type: "bar" as MekanType, name: "Bar", desc: "İksir satışı + sosyal alan", cost: 5000000, reqLevel: 15 },
  { type: "kahvehane" as MekanType, name: "Kahvehane", desc: "Buff iksir + detox satışı", cost: 8000000, reqLevel: 20 },
  { type: "dovus_kulubu" as MekanType, name: "Dövüş Kulübü", desc: "PvP arena + bahis", cost: 15000000, reqLevel: 30 },
  { type: "luks_lounge" as MekanType, name: "Lüks Lounge", desc: "Tüm özellikler + VIP", cost: 50000000, reqLevel: 45 },
  { type: "yeralti" as MekanType, name: "Yeraltı İmparatorluğu", desc: "Tüm özellikler + kaçak ticaret", cost: 200000000, reqLevel: 60 },
];

export default function CreateMekanPage() {
  const router = useRouter();
  const { openMekan, isLoading } = useMekanStore();
  const playerLevel = usePlayerStore((s) => s.level);
  const playerGold = usePlayerStore((s) => s.gold);
  const addToast = useUiStore((s) => s.addToast);

  const [name, setName] = useState("");
  const [selectedType, setSelectedType] = useState<MekanType | "">("");

  const handleCreate = async () => {
    if (!name.trim()) {
      addToast("Mekan adı boş olamaz!", "warning");
      return;
    }
    if (!selectedType) {
      addToast("Mekan türü seçmelisiniz!", "warning");
      return;
    }

    const typeInfo = MEKAN_TYPES.find((t) => t.type === selectedType);
    if (!typeInfo) return;

    if (playerLevel < typeInfo.reqLevel) {
      addToast(`Bu mekanı açmak için Level ${typeInfo.reqLevel} gerekiyor!`, "error");
      return;
    }

    if (playerGold < typeInfo.cost) {
      addToast(`Yetersiz altın! (${typeInfo.cost.toLocaleString()} G gerekli)`, "error");
      return;
    }

    const success = await openMekan(selectedType, name);
    if (success) {
      addToast("Mekan başarıyla açıldı!", "success");
      // Redirect to My Mekan page
      router.push("/my-mekan");
    }
  };

  return (
    <div className="p-4 max-w-2xl mx-auto flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-amber-500">Yeni Mekan Aç</h1>
        <Button variant="ghost" onClick={() => router.push("/mekans")}>
          Geri Dön
        </Button>
      </div>

      <Card className="p-4">
        <h2 className="text-lg font-semibold mb-2">Mekan Adı</h2>
        <input
          type="text"
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="Mekanınıza bir isim verin..."
          className="w-full bg-slate-800 border border-slate-700 rounded p-2 text-white placeholder-slate-400 focus:outline-none focus:border-amber-500"
          maxLength={30}
        />
      </Card>

      <div className="grid grid-cols-1 gap-4">
        {MEKAN_TYPES.map((t) => {
          const canAfford = playerGold >= t.cost;
          const meetsLevel = playerLevel >= t.reqLevel;
          const isSelected = selectedType === t.type;

          return (
            <Card
              key={t.type}
              className={`p-4 cursor-pointer transition-colors ${
                isSelected ? "border-amber-500 bg-slate-800" : "hover:border-slate-500"
              }`}
              onClick={() => setSelectedType(t.type)}
            >
              <div className="flex justify-between items-start">
                <div>
                  <h3 className="text-lg font-bold text-amber-400">{t.name}</h3>
                  <p className="text-sm text-gray-400">{t.desc}</p>
                </div>
                <div className="text-right">
                  <div className={`text-sm font-bold ${canAfford ? "text-yellow-500" : "text-red-500"}`}>
                    {t.cost.toLocaleString()} G
                  </div>
                  <div className={`text-xs ${meetsLevel ? "text-green-500" : "text-red-500"}`}>
                    Gereksinim: Lv {t.reqLevel}
                  </div>
                </div>
              </div>
            </Card>
          );
        })}
      </div>

      <Button
        variant="primary"
        size="lg"
        onClick={handleCreate}
        disabled={isLoading || !name.trim() || !selectedType}
        isLoading={isLoading}
      >
        Mekanı Aç
      </Button>
    </div>
  );
}
