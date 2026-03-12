import { createClient } from "@supabase/supabase-js";

export const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || "";
export const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || "";

// Gracefully handle missing env vars during build/prerender
const isBuildTime = !supabaseUrl || !supabaseAnonKey;

// During local development some environments use a proxy or self-signed certs.
// Disable strict TLS validation only in non-production dev to allow connecting
// to Supabase instances behind such proxies. This is safe for local dev but
// MUST NOT be enabled in production.
if (!isBuildTime && process.env.NODE_ENV !== "production") {
  try {
    // eslint-disable-next-line @typescript-eslint/ban-ts-comment
    // @ts-ignore
    process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0";
    // Helpful warning for developers
    // eslint-disable-next-line no-console
    console.warn("[supabase] NODE_TLS_REJECT_UNAUTHORIZED=0 (dev only)");
  } catch (e) {
    // ignore
  }
}

export const supabase = isBuildTime
  ? createClient("https://placeholder.supabase.co", "placeholder", {
      auth: { persistSession: false, autoRefreshToken: false },
    })
  : createClient(supabaseUrl, supabaseAnonKey, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: false,
      },
      realtime: {
        params: {
          eventsPerSecond: 10,
        },
      },
      // Development: disable TLS rejection for self-signed certs (local Supabase or proxy)
      // In production, this should never be set (defaults to true)
      global: {
        fetch: (url: any, options?: any) => {
          const isHttps = String(url).startsWith('https');
          if (isHttps && process.env.NODE_ENV !== 'production') {
            // Add Node.js https agent that ignores cert errors for dev
            const https = require('https');
            const agent = new https.Agent({  
              rejectUnauthorized: false,
            });
            return fetch(url, { ...options, agent } as any);
          }
          return fetch(url, options);
        },
      },
    });
