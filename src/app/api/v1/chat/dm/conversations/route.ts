import { NextResponse } from "next/server";

import { createChatRouteContext, handleRouteError, jsonError } from "@/lib/server/chatRoute";

export async function GET(request: Request) {
  try {
    const { supabase } = await createChatRouteContext(request);

    const { data, error } = await supabase.rpc("get_dm_conversations");

    if (error) {
      return jsonError(error.message, 400);
    }

    return NextResponse.json(Array.isArray(data) ? data : []);
  } catch (error) {
    return handleRouteError(error);
  }
}