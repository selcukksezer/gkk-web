// ============================================================
// Game Layout — Kimlik doğrulama guard + TopBar + BottomNav
// Tüm oyun sayfaları bu layout altında çalışır
// ============================================================

"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { TopBar } from "@/components/layout/TopBar";
import { BottomNav } from "@/components/layout/BottomNav";
import { ToastContainer } from "@/components/ui/ToastContainer";
import { LoadingScreen } from "@/components/ui/Spinner";
import { useAuthStore } from "@/stores/authStore";
import { usePlayerStore } from "@/stores/playerStore";
import { useEnergyRegen } from "@/hooks/useEnergyRegen";

export default function GameLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const router = useRouter();
  const isAuthenticated = useAuthStore((s) => s.isAuthenticated);
  const checkSession = useAuthStore((s) => s.checkSession);
  const fetchProfile = usePlayerStore((s) => s.fetchProfile);
  const startPrisonPolling = usePlayerStore((s) => s.startPrisonPolling);
  const stopPrisonPolling = usePlayerStore((s) => s.stopPrisonPolling);
  const [isChecking, setIsChecking] = useState(true);

  // Energy regen timer
  useEnergyRegen();

  useEffect(() => {
    async function init() {
      const hasSession = await checkSession();
      if (!hasSession) {
        router.replace("/login");
        return;
      }
      await fetchProfile();
      // Godot: StateStore.gd line 310 — Start real-time prison status polling
      startPrisonPolling();
      setIsChecking(false);
    }
    init();

    // Cleanup on unmount
    return () => {
      stopPrisonPolling();
    };
  }, [checkSession, fetchProfile, startPrisonPolling, stopPrisonPolling, router]);

  if (isChecking) {
    return <LoadingScreen message="Oturum kontrol ediliyor..." />;
  }

  if (!isAuthenticated) {
    return null; // Router will redirect
  }

  return (
    <div className="min-h-screen flex flex-col max-w-lg mx-auto relative">
      <TopBar />
      <main className="flex-1 overflow-y-auto pb-20 animate-page-enter">
        {children}
      </main>
      <BottomNav />
      <ToastContainer />
    </div>
  );
}
