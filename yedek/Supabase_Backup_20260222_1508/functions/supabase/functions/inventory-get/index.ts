// Inventory API - Get user inventory
// GET /inventory
import { createResponse, createErrorResponse, handleCORS, validateAuth, supabaseClient } from "../_shared/utils.ts";
Deno.serve(async (req)=>{
  const corsResponse = handleCORS(req);
  if (corsResponse) return corsResponse;
  try {
    const auth = await validateAuth(req);
    if (!auth.success) {
      return createErrorResponse("UNAUTHORIZED", auth.error || "Authentication required", null, 401);
    }
    // Get user ID from auth
    const { data: user } = await supabaseClient.from("users").select("id").eq("auth_id", auth.userId).single();
    if (!user) {
      return createErrorResponse("USER_NOT_FOUND", "User not found", null, 404);
    }
    // Get inventory with item details
    const { data: inventory, error } = await supabaseClient.from("inventory").select(`
        id,
        quantity,
        enhancement_level,
        is_equipped,
        equipment_slot,
        acquired_at,
        item:item_id (
          id,
          name,
          description,
          type,
          rarity,
          power,
          defense,
          icon_url
        )
      `).eq("user_id", user.id).order("acquired_at", {
      ascending: false
    });
    if (error) {
      return createErrorResponse("QUERY_FAILED", "Failed to load inventory", {
        error: error.message
      }, 500);
    }
    return createResponse({
      inventory
    });
  } catch (error) {
    console.error("Inventory error:", error);
    return createErrorResponse("INTERNAL_ERROR", "An unexpected error occurred", null, 500);
  }
});
