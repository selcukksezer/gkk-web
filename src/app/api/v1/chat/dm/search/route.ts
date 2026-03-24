import { NextResponse } from "next/server";

import { createChatRouteContext, handleRouteError, jsonError } from "@/lib/server/chatRoute";

export async function GET(request: Request) {
  try {
    const { supabase } = await createChatRouteContext(request);
    const url = new URL(request.url);
    const query = url.searchParams.get("query") || "";
    const limit = Number(url.searchParams.get("limit") || 8);

    if (query.trim().length < 2) {
      return NextResponse.json([]);
    }

    const { data, error } = await supabase.rpc("search_chat_users", {
      p_query: query,
      p_limit: Number.isFinite(limit) ? limit : 8,
    });

    if (error) {
      return jsonError(error.message, 400);
    }

    return NextResponse.json(Array.isArray(data) ? data : []);
  } catch (error) {
    return handleRouteError(error);
  }
}