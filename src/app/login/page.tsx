// ============================================================
// Login Page — Kaynak: scenes/ui/LoginScreen.gd
// ============================================================

"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { motion } from "framer-motion";
import { useAuthStore } from "@/stores/authStore";
import { Button } from "@/components/ui/Button";
import { isValidEmail, isValidPassword } from "@/lib/utils/string";

export default function LoginPage() {
  const router = useRouter();
  const login = useAuthStore((s) => s.login);
  const isLoading = useAuthStore((s) => s.isLoading);
  const error = useAuthStore((s) => s.error);
  const clearError = useAuthStore((s) => s.clearError);

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    clearError();

    if (!isValidEmail(email)) {
      useAuthStore.getState().setError("Geçerli bir e-posta adresi girin");
      return;
    }
    if (!isValidPassword(password)) {
      useAuthStore.getState().setError("Şifre en az 6 karakter olmalı");
      return;
    }

    const success = await login(email, password);
    if (success) {
      router.replace("/home");
    }
  };

  return (
    <div className="min-h-screen flex flex-col items-center justify-center p-6 bg-[var(--bg-darker)]">
      <motion.div
        initial={{ opacity: 0, y: 30 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5 }}
        className="w-full max-w-sm"
      >
        {/* Logo / Title */}
        <div className="text-center mb-8">
          <h1 className="text-3xl font-bold text-[var(--accent-light)] mb-2">
            Gölge Krallık
          </h1>
          <p className="text-sm text-[var(--text-muted)]">
            Kadim Mühür&apos;ün Çöküşü
          </p>
        </div>

        {/* Login Form */}
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-xs text-[var(--text-secondary)] mb-1">
              E-posta
            </label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full px-4 py-3 rounded-lg bg-[var(--bg-input)] border border-[var(--border-default)] text-[var(--text-primary)] placeholder-[var(--text-muted)] focus:outline-none focus:border-[var(--accent)] transition-colors"
              placeholder="ornek@email.com"
              autoComplete="email"
            />
          </div>

          <div>
            <label className="block text-xs text-[var(--text-secondary)] mb-1">
              Şifre
            </label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full px-4 py-3 rounded-lg bg-[var(--bg-input)] border border-[var(--border-default)] text-[var(--text-primary)] placeholder-[var(--text-muted)] focus:outline-none focus:border-[var(--accent)] transition-colors"
              placeholder="••••••"
              autoComplete="current-password"
            />
          </div>

          {error && (
            <motion.p
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              className="text-sm text-[var(--color-error)] text-center"
            >
              {error}
            </motion.p>
          )}

          <Button
            type="submit"
            variant="primary"
            size="lg"
            fullWidth
            isLoading={isLoading}
          >
            Giriş Yap
          </Button>
        </form>

        {/* Register link */}
        <p className="text-center text-sm text-[var(--text-muted)] mt-6">
          Hesabın yok mu?{" "}
          <button
            onClick={() => router.push("/register")}
            className="text-[var(--accent-light)] hover:underline"
          >
            Kayıt Ol
          </button>
        </p>
      </motion.div>
    </div>
  );
}
