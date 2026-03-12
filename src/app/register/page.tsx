// ============================================================
// Register Page — Kaynak: scenes/ui/RegisterScreen.gd
// ============================================================

"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { motion } from "framer-motion";
import { useAuthStore } from "@/stores/authStore";
import { Button } from "@/components/ui/Button";
import { isValidEmail, isValidPassword, isValidUsername } from "@/lib/utils/string";

const CHARACTER_SELECTION_ROUTE = "/onboarding/character-select";

export default function RegisterPage() {
  const router = useRouter();
  const register = useAuthStore((s) => s.register);
  const isLoading = useAuthStore((s) => s.isLoading);
  const error = useAuthStore((s) => s.error);
  const clearError = useAuthStore((s) => s.clearError);

  const [email, setEmail] = useState("");
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [referralCode, setReferralCode] = useState("");

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    clearError();

    if (!isValidEmail(email)) {
      useAuthStore.getState().setError("Geçerli bir e-posta adresi girin");
      return;
    }
    if (!isValidUsername(username)) {
      useAuthStore
        .getState()
        .setError("Kullanıcı adı 3-20 karakter, alfanumerik olmalı");
      return;
    }
    if (!isValidPassword(password)) {
      useAuthStore.getState().setError("Şifre en az 6 karakter olmalı");
      return;
    }

    const success = await register(email, username, password, referralCode || undefined);
    if (success) {
      router.replace(CHARACTER_SELECTION_ROUTE);
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
        <div className="text-center mb-8">
          <h1 className="text-3xl font-bold text-[var(--accent-light)] mb-2">
            Gölge Krallık
          </h1>
          <p className="text-sm text-[var(--text-muted)]">Yeni Hesap Oluştur</p>
        </div>

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
            />
          </div>

          <div>
            <label className="block text-xs text-[var(--text-secondary)] mb-1">
              Kullanıcı Adı
            </label>
            <input
              type="text"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              className="w-full px-4 py-3 rounded-lg bg-[var(--bg-input)] border border-[var(--border-default)] text-[var(--text-primary)] placeholder-[var(--text-muted)] focus:outline-none focus:border-[var(--accent)] transition-colors"
              placeholder="savaşçı_kral"
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
            />
          </div>

          <div>
            <label className="block text-xs text-[var(--text-secondary)] mb-1">
              Referans Kodu (opsiyonel)
            </label>
            <input
              type="text"
              value={referralCode}
              onChange={(e) => setReferralCode(e.target.value)}
              className="w-full px-4 py-3 rounded-lg bg-[var(--bg-input)] border border-[var(--border-default)] text-[var(--text-primary)] placeholder-[var(--text-muted)] focus:outline-none focus:border-[var(--accent)] transition-colors"
              placeholder="ABC123"
            />
          </div>

          {error && (
            <motion.p
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              className="text-sm text-[var(--color-error)] text-center"
            >
              {typeof error === "string"
                ? error
                : (error as any)?.message ?? JSON.stringify(error)}
            </motion.p>
          )}

          <Button
            type="submit"
            variant="primary"
            size="lg"
            fullWidth
            isLoading={isLoading}
          >
            Kayıt Ol
          </Button>
        </form>

        <p className="text-center text-sm text-[var(--text-muted)] mt-6">
          Zaten hesabın var mı?{" "}
          <button
            onClick={() => router.push("/login")}
            className="text-[var(--accent-light)] hover:underline"
          >
            Giriş Yap
          </button>
        </p>
      </motion.div>
    </div>
  );
}
