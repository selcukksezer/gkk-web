// ============================================================
// Splash / Root Page — Yönlendirme
// ============================================================

"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuthStore } from "@/stores/authStore";
import { LoadingScreen } from "@/components/ui/Spinner";

export default function SplashPage() {
  const router = useRouter();
  const checkSession = useAuthStore((s) => s.checkSession);

  useEffect(() => {
    async function init() {
      const hasSession = await checkSession();
      if (hasSession) {
        router.replace("/home");
      } else {
        router.replace("/login");
      }
    }
    init();
  }, [checkSession, router]);

  return <LoadingScreen message="Gölge Krallık yükleniyor..." />;
}
