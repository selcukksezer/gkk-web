// Enhancement API - Enhance item
// POST /enhancement/enhance
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
      "item_id"
    ]);
    if (!validation.valid) {
      return createErrorResponse("MISSING_FIELDS", "Missing required fields", {
        missing: validation.missing
      }, 400);
    }
    const { item_id, rune_type = "none" } = body;
    // Get user
    const { data: user } = await supabaseClient.from("users").select("id, gold").eq("auth_id", auth.userId).single();
    if (!user) {
      return createErrorResponse("USER_NOT_FOUND", "User not found", null, 404);
    }
    // Get inventory item
    const { data: inventoryItem } = await supabaseClient.from("inventory").select("*, item:item_id(can_enhance, max_enhancement)").eq("id", item_id).eq("user_id", user.id).single();
    if (!inventoryItem) {
      return createErrorResponse("ITEM_NOT_FOUND", "Item not found in inventory", null, 404);
    }
    if (!inventoryItem.item.can_enhance) {
      return createErrorResponse("CANNOT_ENHANCE", "This item cannot be enhanced", null, 400);
    }
    const currentLevel = inventoryItem.enhancement_level || 0;
    const maxLevel = inventoryItem.item.max_enhancement || 10;
    if (currentLevel >= maxLevel) {
      return createErrorResponse("MAX_LEVEL", "Item is already at maximum enhancement", null, 400);
    }
    // Success rates
    const baseRates = {
      0: 100,
      1: 95,
      2: 90,
      3: 80,
      4: 70,
      5: 60,
      6: 50,
      7: 40,
      8: 30,
      9: 20
    };
    const runeBonus = {
      none: 0,
      basic: 5,
      advanced: 10,
      superior: 20,
      legendary: 30
    };
    const successRate = Math.min(100, baseRates[currentLevel] + (runeBonus[rune_type] || 0));
    // Calculate cost
    const baseCost = 100 * Math.pow(2, currentLevel);
    const runeCost = rune_type !== "none" ? 100 : 0;
    const totalCost = baseCost + runeCost;
    if (user.gold < totalCost) {
      return createErrorResponse("INSUFFICIENT_GOLD", "Not enough gold", {
        required: totalCost,
        current: user.gold
      }, 400);
    }
    // Deduct gold
    await supabaseClient.from("users").update({
      gold: user.gold - totalCost
    }).eq("id", user.id);
    // Roll for success
    const roll = Math.random() * 100;
    const success = roll <= successRate;
    let newLevel = currentLevel;
    let destroyed = false;
    if (success) {
      newLevel = currentLevel + 1;
    } else {
      // Failure penalties
      if (currentLevel >= 6) {
        // Can destroy item
        if (Math.random() < 0.2 && rune_type !== "protection") {
          destroyed = true;
        } else {
          newLevel = Math.max(0, currentLevel - (currentLevel >= 7 ? 3 : 2));
        }
      } else if (currentLevel >= 3) {
        newLevel = Math.max(0, currentLevel - 1);
      }
    }
    if (destroyed) {
      // Remove item
      await supabaseClient.from("inventory").delete().eq("id", item_id);
      return createResponse({
        success: false,
        enhanced: false,
        destroyed: true,
        gold_spent: totalCost
      });
    } else {
      // Update enhancement level
      await supabaseClient.from("inventory").update({
        enhancement_level: newLevel
      }).eq("id", item_id);
      return createResponse({
        success: true,
        enhanced: success,
        new_level: newLevel,
        old_level: currentLevel,
        destroyed: false,
        gold_spent: totalCost
      });
    }
  } catch (error) {
    console.error("Enhancement error:", error);
    return createErrorResponse("INTERNAL_ERROR", "An unexpected error occurred", null, 500);
  }
});
