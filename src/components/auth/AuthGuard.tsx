// ============================================================
// AuthGuard — Client-side auth check wrapper
// Redirects to /login if not authenticated
// ============================================================

"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useAuthStore } from "@/stores/authStore";
import { LoadingScreen } from "@/components/ui/Spinner";

interface AuthGuardProps {
  children: React.ReactNode;
  fallback?: React.ReactNode;
}

export function AuthGuard({ children, fallback }: AuthGuardProps) {
  const router = useRouter();
  const isAuthenticated = useAuthStore((s) => s.isAuthenticated);
  const checkSession = useAuthStore((s) => s.checkSession);
  const [isChecking, setIsChecking] = useState(true);

  useEffect(() => {
    async function check() {
      const valid = await checkSession();
      if (!valid) {
        router.replace("/login");
      }
      setIsChecking(false);
    }
    check();
  }, [checkSession, router]);

  if (isChecking) {
    return fallback ?? <LoadingScreen message="Oturum kontrol ediliyor..." />;
  }

  if (!isAuthenticated) return null;

  return <>{children}</>;
}
