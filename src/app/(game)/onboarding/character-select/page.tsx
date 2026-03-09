"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";
import { Button } from "@/components/ui/Button";
import { usePlayerStore } from "@/stores/playerStore";
import { Card } from "@/components/ui/Card";

type ClassType = 'warrior' | 'alchemist' | 'shadow';

interface CharacterClass {
  id: ClassType;
  name: string;
  description: string;
  baseAttack: number;
  baseDefense: number;
  baseHealth: number;
  baseLuck: number;
}

interface CharacterClassRpcResponse {
  success: boolean;
  classes: Array<{
    id: ClassType;
    name_tr: string;
    description_tr: string;
    base_stats: {
      attack: number;
      defense: number;
      health: number;
      luck: number;
    };
  }>;
}

const GAME_HOME_ROUTE = "/home";

export default function CharacterSelectPage() {
  const router = useRouter();
  const { profile, fetchProfile } = usePlayerStore();
  const [selectedClass, setSelectedClass] = useState<ClassType | null>(null);
  const [classes, setClasses] = useState<CharacterClass[]>([]);
  const [classesLoading, setClassesLoading] = useState(true);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (profile?.character_class) {
      router.push(GAME_HOME_ROUTE);
    }
  }, [profile, router]);

  useEffect(() => {
    const loadClasses = async () => {
      setClassesLoading(true);
      try {
        const { data, error: rpcError } = await supabase.rpc("get_character_classes");
        if (rpcError) throw rpcError;

        const response = data as CharacterClassRpcResponse | null;
        if (!response?.success) {
          throw new Error("Sınıf listesi alınamadı");
        }

        setClasses(
          response.classes.map((characterClass) => ({
            id: characterClass.id,
            name: characterClass.name_tr,
            description: characterClass.description_tr,
            baseAttack: characterClass.base_stats.attack,
            baseDefense: characterClass.base_stats.defense,
            baseHealth: characterClass.base_stats.health,
            baseLuck: characterClass.base_stats.luck,
          }))
        );
      } catch (loadError) {
        console.error(loadError);
        setError("Sınıflar yüklenemedi");
      } finally {
        setClassesLoading(false);
      }
    };

    void loadClasses();
  }, []);

  const handleSelectClass = async () => {
    if (!selectedClass) return;
    
    setLoading(true);
    setError(null);
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error("Oturum bulunamadı");

      const { data, error: rpcError } = await supabase.rpc('select_character_class', {
        p_class_id: selectedClass
      });

      if (rpcError) throw rpcError;
      if (data && !data.success) throw new Error(data.error || "Sınıf seçimi başarısız");

      await fetchProfile();
      
      // Show success message with grace period info
      const className = classes.find((characterClass) => characterClass.id === selectedClass)?.name || "Sınıf";
      alert(`${className} sınıfını seçtiniz!\n\nİlk 30 dakika içinde sınıfınızı değiştirebilirsiniz.`);
      
      router.push(GAME_HOME_ROUTE);
    } catch (err) {
      console.error(err);
      setError(err instanceof Error ? err.message : "Sınıf seçimi başarısız");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-slate-950 p-4">
      <Card className="w-full max-w-3xl p-8 bg-slate-900 border-slate-800">
        <h1 className="text-3xl font-bold text-center text-amber-500 mb-2">Sınıfını Seç</h1>
        <p className="text-center text-slate-400 mb-8">Kaderini belirleyecek yolu seç. Bu karar oyun tarzını kökten değiştirecek.</p>
        
        {error && <div className="bg-red-900/50 text-red-200 p-3 rounded mb-6 text-center">{error}</div>}

        {classesLoading ? (
          <div className="py-8 text-center text-slate-400">Sınıflar yükleniyor...</div>
        ) : (
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          {classes.map((c) => (
            <div 
              key={c.id}
              onClick={() => setSelectedClass(c.id)}
              className={`p-6 rounded-lg border-2 cursor-pointer transition-all duration-200 flex flex-col items-center text-center ${
                selectedClass === c.id 
                  ? 'border-amber-500 bg-amber-500/10' 
                  : 'border-slate-700 bg-slate-800 hover:border-slate-500'
              }`}
            >
              <h2 className="text-xl font-bold text-white mb-2">{c.name}</h2>
              <p className="text-slate-400 text-sm mb-4">{c.description}</p>
              
              <div className="w-full grid grid-cols-2 gap-2 text-xs">
                <div className="bg-slate-700 p-2 rounded">
                  <div className="text-slate-400">ATK</div>
                  <div className="font-bold text-orange-400">{c.baseAttack}</div>
                </div>
                <div className="bg-slate-700 p-2 rounded">
                  <div className="text-slate-400">DEF</div>
                  <div className="font-bold text-blue-400">{c.baseDefense}</div>
                </div>
                <div className="bg-slate-700 p-2 rounded">
                  <div className="text-slate-400">HP</div>
                  <div className="font-bold text-green-400">{c.baseHealth}</div>
                </div>
                <div className="bg-slate-700 p-2 rounded">
                  <div className="text-slate-400">LUCK</div>
                  <div className="font-bold text-yellow-400">{c.baseLuck}</div>
                </div>
              </div>
            </div>
          ))}
        </div>
        )}

        <div className="flex justify-center">
          <Button 
            size="lg" 
            onClick={handleSelectClass} 
            disabled={!selectedClass || loading || classesLoading}
            isLoading={loading}
            className="w-full md:w-1/2"
          >
            Maceraya Başla
          </Button>
        </div>
      </Card>
    </div>
  );
}
