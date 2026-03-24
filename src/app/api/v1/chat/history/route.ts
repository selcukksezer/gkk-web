import { NextResponse } from "next/server";

import { createChatRouteContext, handleRouteError, jsonError } from "@/lib/server/chatRoute";
import type { ChatChannel } from "@/hooks/useChat";

const CHANNELS: ChatChannel[] = ["global", "guild", "dm", "trade", "system"];

export async function GET(request: Request) {
  try {
    const { supabase } = await createChatRouteContext(request);
    const url = new URL(request.url);
    const channel = (url.searchParams.get("channel") || "global") as ChatChannel;
    const limit = Number(url.searchParams.get("limit") || 50);
    const peerId = url.searchParams.get("peer_id");

    if (!CHANNELS.includes(channel)) {
      return jsonError("Geçersiz kanal", 400);
    }

    if (channel === "dm" && peerId) {
      const { data, error } = await supabase.rpc("get_dm_messages", {
        p_peer_user_id: peerId,
        p_limit: Number.isFinite(limit) ? limit : 50,
      });

      if (error) {
        return jsonError(error.message, 400);
      }

      const history = Array.isArray(data) ? [...data].reverse() : [];
      return NextResponse.json(history);
    }

    const { data, error } = await supabase.rpc("get_chat_history", {
      p_channel: channel,
      p_limit: Number.isFinite(limit) ? limit : 50,
    });

    if (error) {
      return jsonError(error.message, 400);
    }

    const history = Array.isArray(data) ? [...data].reverse() : [];
    return NextResponse.json(history);
  } catch (error) {
    return handleRouteError(error);
  }
}