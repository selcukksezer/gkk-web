import { NextResponse } from "next/server";

import { createChatRouteContext, handleRouteError, jsonError } from "@/lib/server/chatRoute";
import type { ChatChannel } from "@/hooks/useChat";

const CHANNELS: ChatChannel[] = ["global", "guild", "dm", "trade"];

export async function POST(request: Request) {
  try {
    const { supabase } = await createChatRouteContext(request);
    const body = await request.json().catch(() => ({}));
    const targetUserId = typeof body.target_user_id === "string" ? body.target_user_id : "";
    const channel = body.channel as ChatChannel;

    if (!targetUserId) {
      return jsonError("Hedef oyuncu seçilmedi", 400);
    }

    if (!CHANNELS.includes(channel)) {
      return jsonError("Geçersiz kanal", 400);
    }

    const { data, error } = await supabase.rpc("assign_chat_moderator", {
      p_target_user_id: targetUserId,
      p_channel: channel,
    });

    if (error) {
      return jsonError(error.message, 400);
    }

    if (!data?.success) {
      return jsonError(data?.error || "Moderator atanamadı", 400);
    }

    return NextResponse.json(data);
  } catch (error) {
    return handleRouteError(error);
  }
}