// Market API - Place order
// POST /market/place-order
import { createResponse, createErrorResponse, handleCORS, validateAuth, validateBody, supabaseClient } from "../_shared/utils.ts";
Deno.serve(async (req)=>{
  const corsResponse = handleCORS(req);
  if (corsResponse) return corsResponse;
  try {
    const auth = await validateAuth(req);
    if (!auth.success) {
      return createErrorResponse("UNAUTHORIZED", auth.error || "Authentication required", null, 401);
    }
    const body = await req.json();
    const validation = validateBody(body, [
      "item_id",
      "order_type",
      "quantity",
      "price_per_unit"
    ]);
    if (!validation.valid) {
      return createErrorResponse("MISSING_FIELDS", "Missing required fields", {
        missing: validation.missing
      }, 400);
    }
    const { item_id, order_type, quantity, price_per_unit, enhancement_level = 0 } = body;
    // Validate order type
    if (order_type !== "buy" && order_type !== "sell") {
      return createErrorResponse("INVALID_ORDER_TYPE", "Order type must be 'buy' or 'sell'", null, 400);
    }
    // Get user
    const { data: user } = await supabaseClient.from("users").select("id, gold").eq("auth_id", auth.userId).single();
    if (!user) {
      return createErrorResponse("USER_NOT_FOUND", "User not found", null, 404);
    }
    // Validate item exists
    const { data: item } = await supabaseClient.from("items").select("id, name, is_tradeable").eq("id", item_id).single();
    if (!item) {
      return createErrorResponse("ITEM_NOT_FOUND", "Item not found", null, 404);
    }
    if (!item.is_tradeable) {
      return createErrorResponse("NOT_TRADEABLE", "This item cannot be traded", null, 400);
    }
    const totalPrice = quantity * price_per_unit;
    if (order_type === "sell") {
      // Check if user has the item
      const { data: inventoryItem } = await supabaseClient.from("inventory").select("quantity").eq("user_id", user.id).eq("item_id", item_id).eq("enhancement_level", enhancement_level).single();
      if (!inventoryItem || inventoryItem.quantity < quantity) {
        return createErrorResponse("INSUFFICIENT_ITEMS", "Not enough items in inventory", null, 400);
      }
      // Remove items from inventory
      await supabaseClient.rpc("decrease_inventory_item", {
        p_user_id: user.id,
        p_item_id: item_id,
        p_quantity: quantity,
        p_enhancement_level: enhancement_level
      });
    } else {
      // Buy order - check gold
      if (user.gold < totalPrice) {
        return createErrorResponse("INSUFFICIENT_GOLD", "Not enough gold", {
          required: totalPrice,
          current: user.gold
        }, 400);
      }
      // Reserve gold
      await supabaseClient.from("users").update({
        gold: user.gold - totalPrice
      }).eq("id", user.id);
    }
    // Create order
    const { data: order, error } = await supabaseClient.from("market_orders").insert({
      user_id: user.id,
      item_id,
      order_type,
      quantity,
      price_per_unit,
      enhancement_level,
      status: "active"
    }).select().single();
    if (error) {
      return createErrorResponse("ORDER_CREATION_FAILED", "Failed to create order", {
        error: error.message
      }, 500);
    }
    return createResponse({
      order
    });
  } catch (error) {
    console.error("Place order error:", error);
    return createErrorResponse("INTERNAL_ERROR", "An unexpected error occurred", null, 500);
  }
});
