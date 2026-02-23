import { createClient } from "@supabase/supabase-js";

export const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || "https://placeholder.supabase.co";
export const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || "placeholder-anon-key";

// Warn when running with placeholder credentials (build-time static generation only)
if (typeof window !== "undefined" && !process.env.NEXT_PUBLIC_SUPABASE_URL) {
  console.warn(
    "[Supabase] NEXT_PUBLIC_SUPABASE_URL is not set. " +
    "The app will not be able to connect to the database. " +
    "Please set the required environment variables."
  );
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: false, // Capacitor'da URL redirect yok
  },
  realtime: {
    params: {
      eventsPerSecond: 10,
    },
  },
});
