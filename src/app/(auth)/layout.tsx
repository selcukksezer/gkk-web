// ============================================================
// Auth Layout — Minimal layout for login/register pages
// No TopBar/BottomNav, centered content
// ============================================================

import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Gölge Krallık — Giriş",
};

export default function AuthLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="min-h-screen bg-[var(--bg)] flex items-center justify-center p-4">
      {children}
    </div>
  );
}
