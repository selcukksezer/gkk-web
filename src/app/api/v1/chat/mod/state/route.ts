import { NextResponse } from "next/server";

import { createChatRouteContext, handleRouteError, jsonError } from "@/lib/server/chatRoute";
import type { ChatChannel } from "@/hooks/useChat";

const CHANNELS: ChatChannel[] = ["global", "guild", "dm", "trade", "system"];

export async function GET(request: Request) {
  try {
    const { supabase } = await createChatRouteContext(request);
    const url = new URL(request.url);
    const channel = (url.searchParams.get("channel") || "global") as ChatChannel;

    if (!CHANNELS.includes(channel)) {
      return jsonError("Geçersiz kanal", 400);
    }

    const { data, error } = await supabase.rpc("get_chat_moderation_state", {
      p_channel: channel,
    });

    if (error) {
      return jsonError(error.message, 400);
    }

    return NextResponse.json(data);
  } catch (error) {
    return handleRouteError(error);
  }
}