import { NextResponse } from "next/server";

import { createChatRouteContext, handleRouteError, jsonError } from "@/lib/server/chatRoute";
import type { ChatChannel } from "@/hooks/useChat";

const CHANNELS: ChatChannel[] = ["global", "guild", "dm", "trade"];

export async function POST(request: Request) {
  try {
    const { supabase } = await createChatRouteContext(request);
    const body = await request.json().catch(() => ({}));
    const channel = body.channel as ChatChannel;
    const content = typeof body.content === "string" ? body.content : "";
    const recipientId = typeof body.recipient_id === "string" ? body.recipient_id : null;

    if (!CHANNELS.includes(channel)) {
      return jsonError("Geçersiz kanal", 400);
    }

    if (!content.trim()) {
      return jsonError("Boş mesaj gönderilemez", 400);
    }

    const { data, error } = await supabase.rpc("send_chat_message", {
      p_channel: channel,
      p_content: content,
      p_recipient_user_id: recipientId,
    });

    if (error) {
      return jsonError(error.message, 400);
    }

    if (!data?.success) {
      return jsonError(data?.error || "Mesaj gönderilemedi", 400);
    }

    return NextResponse.json(data);
  } catch (error) {
    return handleRouteError(error);
  }
}