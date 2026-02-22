// Market API - Get active orders
// GET /market/orders
import { createResponse, createErrorResponse, handleCORS, supabaseClient } from "../_shared/utils.ts";
Deno.serve(async (req)=>{
  const corsResponse = handleCORS(req);
  if (corsResponse) return corsResponse;
  try {
    const url = new URL(req.url);
    const itemId = url.searchParams.get("item_id");
    const orderType = url.searchParams.get("type"); // buy or sell
    let query = supabaseClient.from("market_orders").select(`
        id,
        user_id,
        order_type,
        quantity,
        price_per_unit,
        total_price,
        enhancement_level,
        filled_quantity,
        created_at,
        expires_at,
        user:user_id (username),
        item:item_id (id, name, type, rarity, icon_url)
      `).eq("status", "active").gt("expires_at", new Date().toISOString()).order("created_at", {
      ascending: false
    }).limit(100);
    if (itemId) {
      query = query.eq("item_id", itemId);
    }
    if (orderType && (orderType === "buy" || orderType === "sell")) {
      query = query.eq("order_type", orderType);
    }
    const { data: orders, error } = await query;
    if (error) {
      return createErrorResponse("QUERY_FAILED", "Failed to load market orders", {
        error: error.message
      }, 500);
    }
    return createResponse({
      orders
    });
  } catch (error) {
    console.error("Market orders error:", error);
    return createErrorResponse("INTERNAL_ERROR", "An unexpected error occurred", null, 500);
  }
});
