import { NextResponse } from "next/server";

import { createChatRouteContext, handleRouteError, jsonError } from "@/lib/server/chatRoute";

export async function POST(request: Request) {
  try {
    const { supabase } = await createChatRouteContext(request);
    const body = await request.json().catch(() => ({}));
    const peerUserId = typeof body.peer_user_id === "string" ? body.peer_user_id : "";

    if (!peerUserId) {
      return jsonError("Konuşma seçilmedi", 400);
    }

    const { data, error } = await supabase.rpc("mark_dm_conversation_read", {
      p_peer_user_id: peerUserId,
    });

    if (error) {
      return jsonError(error.message, 400);
    }

    if (!data?.success) {
      return jsonError(data?.error || "Mesajlar okundu olarak işaretlenemedi", 400);
    }

    return NextResponse.json(data);
  } catch (error) {
    return handleRouteError(error);
  }
}