// ============================================================
// Auth Store — Kaynak: SessionManager.gd (438 satır)
// Oturum yönetimi: login, register, logout, token refresh
// ============================================================

import { create } from "zustand";
import { persist } from "zustand/middleware";
import { supabase } from "@/lib/supabase";
import { api } from "@/lib/api";
import { APIEndpoints } from "@/lib/endpoints";
import type { AuthUser, AuthSession } from "@/types/auth";

interface AuthState {
  // State
  user: AuthUser | null;
  session: AuthSession | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  error: string | null;
  deviceId: string;

  // Actions
  login: (email: string, password: string) => Promise<boolean>;
  loginWithUsername: (username: string, password: string) => Promise<boolean>;
  register: (
    email: string,
    username: string,
    password: string,
    referralCode?: string
  ) => Promise<boolean>;
  logout: () => Promise<void>;
  refreshSession: () => Promise<boolean>;
  checkSession: () => Promise<boolean>;
  setError: (error: string | null) => void;
  clearError: () => void;
}

function generateDeviceId(): string {
  const stored = typeof window !== "undefined" ? localStorage.getItem("gk_device_id") : null;
  if (stored) return stored;
  const id = `${Date.now()}-${Math.floor(Math.random() * 999999)}`;
  if (typeof window !== "undefined") {
    localStorage.setItem("gk_device_id", id);
  }
  return id;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set, get) => ({
      user: null,
      session: null,
      isAuthenticated: false,
      isLoading: false,
      error: null,
      deviceId: generateDeviceId(),

      login: async (email: string, password: string) => {
        set({ isLoading: true, error: null });
        try {
          const res = await api.post<{ session: AuthSession; user: AuthUser }>(
            APIEndpoints.AUTH_LOGIN,
            { email, password, device_id: get().deviceId }
          );

          if (res.success && res.data) {
            const { session, user } = res.data;

            // Logical error in a 200 OK response
            if (!session && (res.data as any).error) {
              set({ isLoading: false, error: (res.data as any).error });
              return false;
            }

            // Check if backend nested it inside `data` property
            const actualSession = session || (res.data as any).data?.session;
            const actualUser = user || (res.data as any).data?.user;

            if (actualSession) {
              // Set Supabase session
              await supabase.auth.setSession({
                access_token: actualSession.access_token,
                refresh_token: actualSession.refresh_token,
              });
              set({
                user: actualUser,
                session: actualSession,
                isAuthenticated: true,
                isLoading: false,
                error: null,
              });

              // Send initial user block directly to playerStore
              if (actualUser) {
                const { usePlayerStore } = await import("@/stores/playerStore");
                usePlayerStore.getState().loadPlayerData(actualUser as unknown as Record<string, unknown>);
              }

              return true;
            }

            // If session is still missing despite success
            set({ isLoading: false, error: "Sunucudan geçerli bir oturum bilgisi alınamadı." });
            return false;
          }

          set({ isLoading: false, error: res.error || "Giriş başarısız" });
          return false;
        } catch (err) {
          set({
            isLoading: false,
            error: err instanceof Error ? err.message : "Giriş başarısız",
          });
          return false;
        }
      },

      loginWithUsername: async (username: string, password: string) => {
        // Try login with username directly via the auth endpoint
        // The backend may resolve username→email, or reject if not supported.
        // NOTE: We do NOT store username→email map in localStorage (security risk).
        return get().login(username, password);
      },

      register: async (
        email: string,
        username: string,
        password: string,
        referralCode?: string
      ) => {
        set({ isLoading: true, error: null });
        try {
          const body: Record<string, string> = {
            email,
            username,
            password,
            device_id: get().deviceId,
          };
          if (referralCode) body.referral_code = referralCode;

          const res = await api.post<{ session?: AuthSession; user?: AuthUser }>(
            APIEndpoints.AUTH_REGISTER,
            body
          );

          if (res.success && res.data) {
            // Logical error in a 200 OK response
            if (!res.data.session && (res.data as any).error) {
              set({ isLoading: false, error: (res.data as any).error });
              return false;
            }

            const actualSession = res.data.session || (res.data as any).data?.session;
            const actualUser = res.data.user || (res.data as any).data?.user;

            if (actualSession && actualUser) {
              await supabase.auth.setSession({
                access_token: actualSession.access_token,
                refresh_token: actualSession.refresh_token,
              });
              set({
                user: actualUser,
                session: actualSession,
                isAuthenticated: true,
                isLoading: false,
              });
              return true;
            }

            // Email confirmation might be required
            set({ isLoading: false, error: null });
            return true;
          }

          set({ isLoading: false, error: res.error || "Kayıt başarısız" });
          return false;
        } catch (err) {
          set({
            isLoading: false,
            error: err instanceof Error ? err.message : "Kayıt başarısız",
          });
          return false;
        }
      },

      logout: async () => {
        await supabase.auth.signOut();
        set({
          user: null,
          session: null,
          isAuthenticated: false,
          error: null,
        });
      },

      refreshSession: async () => {
        try {
          const { data, error } = await supabase.auth.refreshSession();
          if (error || !data.session) {
            set({ isAuthenticated: false, session: null, user: null });
            return false;
          }
          set({
            session: {
              access_token: data.session.access_token,
              refresh_token: data.session.refresh_token,
              expires_at: data.session.expires_at || 0,
            },
            isAuthenticated: true,
          });
          return true;
        } catch {
          return false;
        }
      },

      checkSession: async () => {
        try {
          const { data } = await supabase.auth.getSession();
          if (data.session) {
            set({
              session: {
                access_token: data.session.access_token,
                refresh_token: data.session.refresh_token,
                expires_at: data.session.expires_at || 0,
              },
              isAuthenticated: true,
            });

            // Fetch user profile if not loaded
            if (!get().user) {
              const { data: authUser } = await supabase.auth.getUser();
              if (authUser.user?.id) {
                // Get game user profile directly from public.users table
                const { data: gameUser, error } = await supabase
                  .from("users")
                  .select("*")
                  .eq("auth_id", authUser.user.id)
                  .single();

                if (gameUser && !error) {
                  set({ user: gameUser as AuthUser });

                  // Optimistically update playerStore to prevent "Oyuncu" display issue
                  const { usePlayerStore } = await import("@/stores/playerStore");
                  usePlayerStore.getState().loadPlayerData(gameUser as Record<string, unknown>);
                } else if (error) {
                  console.warn("[AuthStore] Failed to fetch public.users:", error.message);
                }
              }
            } else if (get().user) {
              // If already fetched, just make sure playerStore has it too
              const { usePlayerStore } = await import("@/stores/playerStore");
              if (!usePlayerStore.getState().player) {
                usePlayerStore.getState().loadPlayerData(get().user as unknown as Record<string, unknown>);
              }
            }
            return true;
          }
          return false;
        } catch (err) {
          console.error("[AuthStore] checkSession error:", err);
          return false;
        }
      },

      setError: (error) => set({ error }),
      clearError: () => set({ error: null }),
    }),
    {
      name: "gkk-auth",
      partialize: (state) => ({
        // Only persist auth status + device ID — never tokens.
        // Supabase client persists tokens in its own localStorage key.
        isAuthenticated: state.isAuthenticated,
        deviceId: state.deviceId,
      }),
    }
  )
);
