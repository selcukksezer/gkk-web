// ============================================================
// API Client — Kaynak: NetworkManager.gd (408 satır)
// Rate limiting, retry logic, auth header injection
// ============================================================

import { supabase, supabaseUrl, supabaseAnonKey } from "./supabase";
import { APIEndpoints } from "./endpoints";

// Rate limiting state
let requestTokens = 60;
let lastTokenUpdate = Date.now();
const TOKEN_REFILL_RATE = 1; // 1 token/second
const MAX_TOKENS = 60;
const MAX_RETRIES = 3;
const RETRY_DELAY = 2000; // ms
const REQUEST_TIMEOUT_MS = 15_000; // 15s fetch timeout
const MAX_429_RETRIES = 3; // prevent infinite 429 retry loop

function updateRateLimitTokens(): void {
  const now = Date.now();
  const secondsPassed = (now - lastTokenUpdate) / 1000;
  if (secondsPassed >= 1) {
    requestTokens = Math.min(requestTokens + Math.floor(secondsPassed * TOKEN_REFILL_RATE), MAX_TOKENS);
    lastTokenUpdate = now;
  }
}

function canMakeRequest(): boolean {
  updateRateLimitTokens();
  return requestTokens > 0;
}

function consumeToken(): void {
  requestTokens = Math.max(requestTokens - 1, 0);
}

export interface ApiResponse<T = unknown> {
  success: boolean;
  data?: T;
  error?: string;
  code?: number;
}

async function getAuthHeaders(endpoint: string): Promise<Record<string, string>> {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    "apikey": supabaseAnonKey,
  };

  // Do not send expired/current user token when explicitly trying to login/register
  const isAuthRoute = endpoint.includes('/auth-login') || endpoint.includes('/auth-register');

  // If Supabase env is not configured, avoid calling supabase.auth.getSession()
  // which may perform network calls against placeholder client and hang.
  if (!supabaseUrl || !supabaseAnonKey) {
    headers["Authorization"] = `Bearer ${supabaseAnonKey || ""}`;
    return headers;
  }

  const { data: { session } } = await supabase.auth.getSession();

  if (session?.access_token && !isAuthRoute) {
    headers["Authorization"] = `Bearer ${session.access_token}`;
  } else {
    headers["Authorization"] = `Bearer ${supabaseAnonKey}`;
  }

  return headers;
}

function getBaseUrl(): string {
  // Use dedicated backend API URL if available, otherwise fall back to Supabase
  const backendUrl = process.env.NEXT_PUBLIC_API_URL;
  if (backendUrl) {
    return backendUrl;
  }
  return supabaseUrl;
}

async function request<T = unknown>(
  method: "GET" | "POST" | "PUT" | "PATCH" | "DELETE",
  endpoint: string,
  body?: Record<string, unknown>,
  retryCount = 0,
  rateLimitRetries = 0
): Promise<ApiResponse<T>> {
  // Rate limit check
  if (!canMakeRequest()) {
    console.warn("[API] Rate limit exceeded, queuing...");
    await new Promise((r) => setTimeout(r, 1000));
    return request<T>(method, endpoint, body, retryCount, rateLimitRetries);
  }

  consumeToken();

  // Determine base URL:
  // - Internal Next API routes (starting with `/api/`) should be requested via relative path
  //   so the browser talks to our Next server (avoids CORS to Supabase).
  // - Edge Functions and Supabase REST should use Supabase directly.
  const isInternalApi = endpoint.startsWith("/api/");
  const isSupabaseEndpoint = endpoint.startsWith("/functions/v1/") ||
    endpoint.startsWith("/auth/v1/") ||
    endpoint.startsWith("/rest/v1/");

  const baseUrl = isInternalApi ? "" : (isSupabaseEndpoint ? supabaseUrl : getBaseUrl());
  const url = (baseUrl || "") + endpoint;
  const headers = await getAuthHeaders(endpoint);

  // AbortController for request timeout
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

  try {
    const res = await fetch(url, {
      method,
      headers,
      body: method !== "GET" && body ? JSON.stringify(body) : undefined,
      signal: controller.signal,
    });

    clearTimeout(timeoutId);

    // Parse rate limit headers
    const remaining = res.headers.get("x-ratelimit-remaining");
    if (remaining !== null) {
      requestTokens = parseInt(remaining, 10);
    }

    // 429 Rate Limit — with depth limit to prevent infinite recursion
    if (res.status === 429) {
      if (rateLimitRetries >= MAX_429_RETRIES) {
        console.error("[API] Max 429 retries exceeded");
        return { success: false, error: "Rate limit exceeded. Lütfen daha sonra tekrar deneyin.", code: 429 };
      }
      console.warn(`[API] Server rate limit 429 (retry ${rateLimitRetries + 1}/${MAX_429_RETRIES})`);
      const retryAfter = Math.min(parseInt(res.headers.get("retry-after") || "2", 10), 30);
      await new Promise((r) => setTimeout(r, retryAfter * 1000));
      return request<T>(method, endpoint, body, retryCount, rateLimitRetries + 1);
    }

    // 401 Unauthorized — attempt token refresh only when we have a refresh token
    if (res.status === 401 && retryCount < 1) {
      console.warn("[API] 401 - checking for refresh token before attempting refresh");
      try {
        const { data: { session } } = await supabase.auth.getSession();
        // If there's no refresh token available (e.g. running on server or storage empty), don't call refresh
        if (!session || !session.refresh_token) {
          return { success: false, error: "Oturum süresi doldu. Lütfen tekrar giriş yapın.", code: 401 };
        }

        const { error } = await supabase.auth.refreshSession();
        if (!error) {
          return request<T>(method, endpoint, body, retryCount + 1, rateLimitRetries);
        }
        return { success: false, error: "Oturum süresi doldu. Lütfen tekrar giriş yapın.", code: 401 };
      } catch (e) {
        console.warn("[API] Failed to refresh session or check session:", e);
        return { success: false, error: "Oturum süresi doldu. Lütfen tekrar giriş yapın.", code: 401 };
      }
    }

    const data = await res.json().catch(() => null);
    const success = res.status >= 200 && res.status < 300;

    return {
      success,
      data: success ? (data as T) : undefined,
      error: !success ? (data?.error || data?.message || `HTTP ${res.status}`) : undefined,
      code: res.status,
    };
  } catch (err) {
    clearTimeout(timeoutId);

    // Handle abort (timeout)
    if (err instanceof DOMException && err.name === "AbortError") {
      console.error("[API] Request timeout:", endpoint);
      return { success: false, error: "İstek zaman aşımına uğradı. Bağlantınızı kontrol edin." };
    }

    console.error("[API] Network error:", err);

    // Retry logic for network errors
    if (retryCount < MAX_RETRIES) {
      await new Promise((r) => setTimeout(r, RETRY_DELAY));
      return request<T>(method, endpoint, body, retryCount + 1, rateLimitRetries);
    }

    return {
      success: false,
      error: err instanceof Error ? err.message : "Bağlantı hatası",
    };
  }
}

// ============================================================
// Public API Methods
// ============================================================

export const api = {
  get: <T = unknown>(endpoint: string) => request<T>("GET", endpoint),
  post: <T = unknown>(endpoint: string, body?: Record<string, unknown>) =>
    request<T>("POST", endpoint, body),
  put: <T = unknown>(endpoint: string, body?: Record<string, unknown>) =>
    request<T>("PUT", endpoint, body),
  patch: <T = unknown>(endpoint: string, body?: Record<string, unknown>) =>
    request<T>("PATCH", endpoint, body),
  del: <T = unknown>(endpoint: string) => request<T>("DELETE", endpoint),

  // Supabase RPC shortcut
  rpc: async <T = unknown>(fnName: string, params?: Record<string, unknown>): Promise<ApiResponse<T>> => {
    const { data, error } = await supabase.rpc(fnName, params);
    if (error) {
      return { success: false, error: error.message, code: error.code ? parseInt(error.code) : undefined };
    }
    return { success: true, data: data as T };
  },
};

// Re-export endpoints
export { APIEndpoints };
