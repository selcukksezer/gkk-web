import { NextResponse } from "next/server";

import { supabase } from "@/lib/supabase";

export async function GET(request: Request) {
  const url = new URL(request.url);
  const status = (url.searchParams.get("status") || "").toLowerCase();

  // Prefer RPC-backed responses if quest functions are present.
  if (status === "active") {
    const { data, error } = await supabase.rpc("get_active_quests");
    if (!error && Array.isArray(data)) {
      return NextResponse.json(data);
    }
  }

  const { data, error } = await supabase.rpc("get_available_quests");
  if (!error && Array.isArray(data)) {
    return NextResponse.json(data);
  }

  // Keep frontend stable in environments where quest RPCs are not deployed yet.
  return NextResponse.json([]);
}
