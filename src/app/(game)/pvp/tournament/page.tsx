"use client";

import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";

// Mock Data for the Bracket
const MOCK_ROUNDS = [
  {
    title: "Çeyrek Final",
    matches: [
      { id: 1, p1: "KralŞövalye", p2: "KaranlıkOkçu", s1: 2, s2: 1, winner: "KralŞövalye" },
      { id: 2, p1: "BüyücüGandalf", p2: "GölgeSuikastçi", s1: 0, s2: 2, winner: "GölgeSuikastçi" },
      { id: 3, p1: "KanlıBalta", p2: "SessizGölge", s1: 2, s2: 0, winner: "KanlıBalta" },
      { id: 4, p1: "EjderAvcısı", p2: "AteşBüyücüsü", s1: 1, s2: 2, winner: "AteşBüyücüsü" },
    ]
  },
  {
    title: "Yarı Final",
    matches: [
      { id: 5, p1: "KralŞövalye", p2: "GölgeSuikastçi", s1: 2, s2: 0, winner: "KralŞövalye" },
      { id: 6, p1: "KanlıBalta", p2: "AteşBüyücüsü", s1: 1, s2: 2, winner: "AteşBüyücüsü" },
    ]
  },
  {
    title: "Final",
    matches: [
      { id: 7, p1: "KralŞövalye", p2: "AteşBüyücüsü", s1: 3, s2: 2, winner: "KralŞövalye" },
    ]
  }
];

export default function PvpTournamentPage() {
  return (
    <div className="p-4 max-w-6xl mx-auto flex flex-col gap-6">
      <div className="flex justify-between items-center">
        <h1 className="text-3xl font-bold text-amber-500">Haftalık Turnuva</h1>
        <Button variant="ghost">Kurallar</Button>
      </div>
      
      <Card className="p-6 bg-slate-900 border-amber-900/50 overflow-hidden">
        <h2 className="text-xl font-bold text-amber-400 mb-6 text-center">Sezon Ortası Şampiyonası</h2>
        
        {/* Bracket Container */}
        <div className="flex justify-between items-stretch gap-6 overflow-x-auto pb-4 px-2 min-h-[400px]">
          {MOCK_ROUNDS.map((round, rIndex) => (
            <div key={rIndex} className="flex flex-col justify-around min-w-[200px] flex-1">
              <h3 className="text-center font-semibold text-slate-300 mb-4 h-6">{round.title}</h3>
              <div className="flex flex-col justify-around h-full gap-4">
                {round.matches.map((match) => (
                  <div key={match.id} className="flex flex-col justify-center relative flex-1">
                    {/* Match Card */}
                    <div className="bg-slate-800 border border-slate-700 rounded-md overflow-hidden text-sm shadow-md z-10">
                      <div className={`flex justify-between p-2 items-center ${match.winner === match.p1 ? 'bg-amber-900/30 text-amber-300 font-bold' : 'text-slate-400'}`}>
                        <span className="truncate pr-2">{match.p1}</span>
                        <span className="bg-slate-900 px-2 py-0.5 rounded">{match.s1}</span>
                      </div>
                      <div className="h-[1px] bg-slate-700 w-full"></div>
                      <div className={`flex justify-between p-2 items-center ${match.winner === match.p2 ? 'bg-amber-900/30 text-amber-300 font-bold' : 'text-slate-400'}`}>
                        <span className="truncate pr-2">{match.p2}</span>
                        <span className="bg-slate-900 px-2 py-0.5 rounded">{match.s2}</span>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          ))}
          
          {/* Winner Column */}
          <div className="flex flex-col justify-center min-w-[150px] relative">
            <h3 className="text-center font-semibold text-amber-500 mb-4 absolute top-0 w-full">Şampiyon</h3>
            <div className="bg-gradient-to-b from-amber-600 to-amber-700 border-2 border-amber-400 rounded-lg p-4 text-center text-white shadow-[0_0_20px_rgba(251,191,36,0.4)] z-10 transform scale-110">
              <span className="text-3xl block mb-2 drop-shadow-lg">👑</span>
              <span className="font-bold text-lg drop-shadow-md">KralŞövalye</span>
            </div>
          </div>
        </div>
      </Card>
      
      <div className="flex justify-center gap-4">
        <Button disabled variant="secondary" className="px-8 py-2">Turnuvaya Katıl (Kayıtlar Kapalı)</Button>
      </div>
    </div>
  );
}
