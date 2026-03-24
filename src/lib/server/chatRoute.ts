import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { NextResponse } from "next/server";

type RouteContext = {
  supabase: SupabaseClient;
  bearerToken: string;
};

function getEnv() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!url || !anonKey) {
    throw new Error("Supabase environment variables are missing");
  }

  return { url, anonKey };
}

export function getBearerToken(request: Request): string | null {
  const authorization = request.headers.get("authorization") || "";
  const match = authorization.match(/^Bearer\s+(.+)$/i);
  return match?.[1] ?? null;
}

export async function createChatRouteContext(request: Request): Promise<RouteContext> {
  const bearerToken = getBearerToken(request);
  if (!bearerToken) {
    throw new Error("UNAUTHORIZED");
  }

  const { url, anonKey } = getEnv();
  const supabase = createClient(url, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: {
      headers: {
        Authorization: `Bearer ${bearerToken}`,
      },
    },
  });

  const { data, error } = await supabase.auth.getUser(bearerToken);
  if (error || !data.user) {
    throw new Error("UNAUTHORIZED");
  }

  return { supabase, bearerToken };
}

export function jsonError(message: string, status = 400) {
  return NextResponse.json({ success: false, error: message }, { status });
}

export function handleRouteError(error: unknown) {
  if (error instanceof Error && error.message === "UNAUTHORIZED") {
    return jsonError("Kimlik doğrulama gerekli", 401);
  }

  console.error("[chat-route] unexpected error", error);
  return jsonError("Beklenmeyen bir hata oluştu", 500);
}