import { NextResponse } from "next/server";

import { createChatRouteContext, handleRouteError, jsonError } from "@/lib/server/chatRoute";

export async function POST(request: Request) {
  try {
    const { supabase } = await createChatRouteContext(request);
    const body = await request.json().catch(() => ({}));
    const playerId = typeof body.player_id === "string" ? body.player_id : "";

    if (!playerId) {
      return jsonError("Oyuncu seçilmedi", 400);
    }

    const { data, error } = await supabase.rpc("block_chat_user", {
      p_blocked_user_id: playerId,
    });

    if (error) {
      return jsonError(error.message, 400);
    }

    if (!data?.success) {
      return jsonError(data?.error || "Oyuncu engellenemedi", 400);
    }

    return NextResponse.json(data);
  } catch (error) {
    return handleRouteError(error);
  }
}