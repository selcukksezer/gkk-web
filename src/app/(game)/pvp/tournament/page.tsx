"use client";

import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";

export default function PvpTournamentPage() {
  return (
    <div className="p-4 max-w-4xl mx-auto flex flex-col gap-6">
      <div className="flex justify-between items-center">
        <h1 className="text-3xl font-bold text-amber-500">Haftalık Turnuva</h1>
        <Button variant="ghost">Kurallar</Button>
      </div>
      
      <Card className="p-8 text-center bg-slate-900 border-amber-900">
        <h2 className="text-2xl font-bold text-amber-400 mb-2">Sezon Ortası Şampiyonası Yaklaşıyor</h2>
        <p className="text-slate-400 mb-6">
          Sadece en güçlü savaşçılar hayatta kalacak. Turnuva ağacı yakında bu ekranda aktifleşecek. 
          Sıralamanı yükseltmeye devam et!
        </p>
        
        <div className="flex justify-center gap-4">
          <Button disabled variant="secondary">Turnuvaya Katıl</Button>
        </div>
      </Card>
    </div>
  );
}
