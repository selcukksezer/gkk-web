import { NextResponse } from "next/server";

import { createChatRouteContext, handleRouteError, jsonError } from "@/lib/server/chatRoute";
import type { ChatChannel } from "@/hooks/useChat";

const CHANNELS: ChatChannel[] = ["global", "guild", "dm", "trade"];

export async function POST(request: Request) {
  try {
    const { supabase } = await createChatRouteContext(request);
    const body = await request.json().catch(() => ({}));
    const channel = body.channel as ChatChannel;
    const term = typeof body.term === "string" ? body.term : "";
    const replacement = typeof body.replacement === "string" ? body.replacement : "***";

    if (!CHANNELS.includes(channel)) {
      return jsonError("Geçersiz kanal", 400);
    }

    const { data, error } = await supabase.rpc("create_chat_filter", {
      p_term: term,
      p_replacement: replacement,
      p_channel: channel,
    });

    if (error) {
      return jsonError(error.message, 400);
    }

    if (!data?.success) {
      return jsonError(data?.error || "Filtre eklenemedi", 400);
    }

    return NextResponse.json(data);
  } catch (error) {
    return handleRouteError(error);
  }
}

export async function DELETE(request: Request) {
  try {
    const { supabase } = await createChatRouteContext(request);
    const url = new URL(request.url);
    const filterId = url.searchParams.get("filter_id") || "";

    if (!filterId) {
      return jsonError("Filtre seçilmedi", 400);
    }

    const { data, error } = await supabase.rpc("delete_chat_filter", {
      p_filter_id: filterId,
    });

    if (error) {
      return jsonError(error.message, 400);
    }

    if (!data?.success) {
      return jsonError(data?.error || "Filtre silinemedi", 400);
    }

    return NextResponse.json(data);
  } catch (error) {
    return handleRouteError(error);
  }
}