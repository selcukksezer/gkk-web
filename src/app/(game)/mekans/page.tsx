"use client";

import { useEffect } from "react";
import { useMekanStore } from "@/stores/mekanStore";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Spinner } from "@/components/ui/Spinner";
import { useRouter } from "next/navigation";

export default function MekansPage() {
  const { mekans, isLoading, error, fetchMekans } = useMekanStore();
  const router = useRouter();

  useEffect(() => {
    fetchMekans();
  }, [fetchMekans]);

  const mekanTypes: Record<string, string> = {
    bar: "Bar",
    kahvehane: "Kahvehane",
    dovus_kulubu: "Dövüş Kulübü",
    luks_lounge: "Lüks Lounge",
    yeralti: "Yeraltı İmparatorluğu",
  };

  if (isLoading && mekans.length === 0) return <Spinner />;

  return (
    <div className="p-4 max-w-4xl mx-auto">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold text-amber-500">Hanlar ve Mekanlar</h1>
        <div className="flex gap-2">
          <Button variant="secondary" onClick={() => router.push("/my-mekan")}>
            Benim Mekanım
          </Button>
          <Button variant="primary" onClick={() => router.push("/mekans/create")}>
            Yeni Mekan Aç
          </Button>
        </div>
      </div>

      {error && <div className="text-red-500 mb-4 p-2 bg-red-900/50 rounded">{error}</div>}

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {mekans.map((mekan) => (
          <Card key={mekan.id} className="p-4 flex flex-col gap-2">
            <div className="flex justify-between items-start">
              <h2 className="text-xl font-bold">{mekan.name}</h2>
              <span className={`px-2 py-1 text-xs rounded ${mekan.is_open ? 'bg-green-600/30 text-green-400' : 'bg-red-600/30 text-red-400'}`}>
                {mekan.is_open ? 'AÇIK' : 'KAPALI'}
              </span>
            </div>
            
            <div className="text-sm text-gray-400">
              Tür: <span className="text-gray-200">{mekanTypes[mekan.mekan_type]}</span>
            </div>
            
            <div className="flex justify-between mt-2">
              <div className="text-sm">
                <span className="text-amber-500">Seviye:</span> {mekan.level}
              </div>
              <div className="text-sm">
                <span className="text-purple-400">Ün (Fame):</span> {mekan.fame}
              </div>
            </div>

            <Button 
              className="mt-4" 
              variant="secondary"
              onClick={() => router.push(`/mekans/${mekan.id}`)}
            >
              Mekanı Ziyaret Et
            </Button>
          </Card>
        ))}
        {mekans.length === 0 && !isLoading && (
          <div className="col-span-full text-center p-8 text-gray-500">
            Henüz açık bir mekan yok. İlk açan sen ol!
          </div>
        )}
      </div>
    </div>
  );
}
