"use client";

import { useEffect, useState, use } from "react";
import { useRouter } from "next/navigation";
import { useMekanStore } from "@/stores/mekanStore";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Spinner } from "@/components/ui/Spinner";
import { supabase } from "@/lib/supabase";
import type { Mekan, MekanStock } from "@/types/mekan";

export default function MekanDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const router = useRouter();
  const { buyFromMekan } = useMekanStore();
  const playerGold = usePlayerStore((s) => s.gold);
  const profile = usePlayerStore((s) => s.profile);
  const addToast = useUiStore((s) => s.addToast);

  const [mekan, setMekan] = useState<Mekan | null>(null);
  const [stock, setStock] = useState<MekanStock[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [buyLoading, setBuyLoading] = useState<string | null>(null);

  useEffect(() => {
    const fetchDetails = async () => {
      setIsLoading(true);
      try {
        const { data: mData, error: mError } = await supabase
          .from("mekans")
          .select("*")
          .eq("id", id)
          .single();

        if (mError) throw mError;
        setMekan(mData as Mekan);

        const { data: sData, error: sError } = await supabase
          .from("mekan_stock")
          .select("*")
          .eq("mekan_id", id)
          .gt("quantity", 0);

        if (sError) throw sError;
        setStock(sData as MekanStock[]);
      } catch (err) {
        console.error(err);
        addToast("Mekan detayları alınamadı", "error");
      } finally {
        setIsLoading(false);
      }
    };
    fetchDetails();
  }, [id, addToast]);

  const handleBuy = async (itemId: string, price: number) => {
    if (playerGold < price) {
      addToast("Yetersiz altın!", "error");
      return;
    }
    
    setBuyLoading(itemId);
    const success = await buyFromMekan(id, itemId, 1);
    setBuyLoading(null);
    
    if (success) {
      addToast("Satın alma başarılı!", "success");
      // Update local stock
      setStock(s => s.map(item => item.item_id === itemId ? { ...item, quantity: item.quantity - 1 } : item).filter(item => item.quantity > 0));
      usePlayerStore.getState().updateGold(-price, true);
    }
  };

  if (isLoading) return <Spinner />;
  if (!mekan) return <div className="p-8 text-center">Mekan bulunamadı</div>;

  const isOwner = profile?.id === mekan.owner_id;

  return (
    <div className="p-4 max-w-4xl mx-auto flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-amber-500">{mekan.name}</h1>
          <div className="text-sm text-gray-400">
            Tür: {mekan.mekan_type.replace('_', ' ')} | Seviye: {mekan.level} | Fame: {mekan.fame}
          </div>
        </div>
        <div className="flex gap-2">
          {isOwner && (
            <Button variant="secondary" onClick={() => router.push("/my-mekan")}>
              Mekanımı Yönet
            </Button>
          )}
          <Button variant="ghost" onClick={() => router.push("/mekans")}>
            Geri Dön
          </Button>
        </div>
      </div>

      {!mekan.is_open && (
        <div className="bg-red-900/50 text-red-200 p-4 rounded text-center border border-red-700">
          Bu mekan şu an kapalı.
        </div>
      )}

      {mekan.is_open && (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <Card className="p-4">
            <h2 className="text-lg font-bold mb-4 border-b border-slate-700 pb-2">Menü / Stok</h2>
            
            {stock.length === 0 ? (
              <div className="text-gray-500 text-center py-4">Stokta hiç ürün yok.</div>
            ) : (
              <ul className="flex flex-col gap-3">
                {stock.map(item => (
                  <li key={item.id} className="flex justify-between items-center bg-slate-800/50 p-3 rounded">
                    <div>
                      <div className="font-bold">{item.item_id}</div>
                      <div className="text-xs text-gray-400">Stok: {item.quantity}</div>
                    </div>
                    <div className="flex items-center gap-3">
                      <div className="text-amber-500 font-bold">{item.sell_price.toLocaleString()} G</div>
                      {!isOwner && (
                        <Button 
                          size="sm" 
                          onClick={() => handleBuy(item.item_id, item.sell_price)}
                          isLoading={buyLoading === item.item_id}
                          disabled={buyLoading !== null}
                        >
                          Satın Al
                        </Button>
                      )}
                    </div>
                  </li>
                ))}
              </ul>
            )}
          </Card>

          <Card className="p-4">
            <h2 className="text-lg font-bold mb-4 border-b border-slate-700 pb-2">Mekan Aktiviteleri</h2>
            
            <div className="flex flex-col gap-3">
              <Button variant="secondary" fullWidth disabled>
                Mekan Sohbetine Katıl (Yakında)
              </Button>
              
              {['dovus_kulubu', 'luks_lounge', 'yeralti'].includes(mekan.mekan_type) && (
                <Button variant="danger" fullWidth onClick={() => router.push(`/mekans/${mekan.id}/arena`)}>
                  PvP Arenasına Gir
                </Button>
              )}
            </div>
          </Card>
        </div>
      )}
    </div>
  );
}
