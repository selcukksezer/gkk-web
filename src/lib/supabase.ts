import { createClient } from "@supabase/supabase-js";

// Fallback values allow static export prerendering to complete without env vars.
// At runtime (in the browser), missing credentials will cause API calls to fail
// with network errors rather than crashing the module at load time.
export const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://placeholder.supabase.co';
export const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || 'placeholder-anon-key';

if (typeof window !== 'undefined' && !process.env.NEXT_PUBLIC_SUPABASE_URL) {
  console.error('[Supabase] NEXT_PUBLIC_SUPABASE_URL is not set. API calls will fail.');
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
