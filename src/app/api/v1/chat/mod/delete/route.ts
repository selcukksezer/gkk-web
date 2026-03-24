import { NextResponse } from "next/server";

import { createChatRouteContext, handleRouteError, jsonError } from "@/lib/server/chatRoute";

export async function POST(request: Request) {
  try {
    const { supabase } = await createChatRouteContext(request);
    const body = await request.json().catch(() => ({}));
    const messageId = typeof body.message_id === "string" ? body.message_id : "";
    const reason = typeof body.reason === "string" ? body.reason : null;

    if (!messageId) {
      return jsonError("Mesaj seçilmedi", 400);
    }

    const { data, error } = await supabase.rpc("delete_chat_message", {
      p_message_id: messageId,
      p_reason: reason,
    });

    if (error) {
      return jsonError(error.message, 400);
    }

    if (!data?.success) {
      return jsonError(data?.error || "Mesaj silinemedi", 400);
    }

    return NextResponse.json(data);
  } catch (error) {
    return handleRouteError(error);
  }
}