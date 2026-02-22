// Production API - Start production
// POST /production/start
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
      "building_id",
      "recipe_id"
    ]);
    if (!validation.valid) {
      return createErrorResponse("MISSING_FIELDS", "Missing required fields", {
        missing: validation.missing
      }, 400);
    }
    const { building_id, recipe_id } = body;
    // Get user
    const { data: user } = await supabaseClient.from("users").select("id").eq("auth_id", auth.userId).single();
    if (!user) {
      return createErrorResponse("USER_NOT_FOUND", "User not found", null, 404);
    }
    // Get building
    const { data: building } = await supabaseClient.from("production_buildings").select("*").eq("id", building_id).eq("user_id", user.id).single();
    if (!building) {
      return createErrorResponse("BUILDING_NOT_FOUND", "Building not found", null, 404);
    }
    // Recipe definitions (would be in database in production)
    const recipes = {
      wheat: {
        duration: 60,
        output: {
          wheat: 10
        }
      },
      iron_ore: {
        duration: 120,
        output: {
          iron_ore: 5
        }
      },
      health_potion: {
        duration: 60,
        output: {
          health_potion: 5
        }
      }
    };
    const recipe = recipes[recipe_id];
    if (!recipe) {
      return createErrorResponse("INVALID_RECIPE", "Recipe not found", null, 404);
    }
    // Check queue size (max 10)
    const { count } = await supabaseClient.from("production_queue").select("*", {
      count: "exact",
      head: true
    }).eq("user_id", user.id).eq("is_collected", false);
    if ((count || 0) >= 10) {
      return createErrorResponse("QUEUE_FULL", "Production queue is full", null, 400);
    }
    // Add to queue
    const { data: queueItem, error } = await supabaseClient.from("production_queue").insert({
      user_id: user.id,
      building_id: building.id,
      recipe_id,
      recipe_name: recipe_id.replace("_", " ").replace(/\b\w/g, (l)=>l.toUpperCase()),
      duration: recipe.duration,
      output_items: recipe.output
    }).select().single();
    if (error) {
      return createErrorResponse("PRODUCTION_START_FAILED", "Failed to start production", {
        error: error.message
      }, 500);
    }
    return createResponse({
      production: queueItem
    });
  } catch (error) {
    console.error("Start production error:", error);
    return createErrorResponse("INTERNAL_ERROR", "An unexpected error occurred", null, 500);
  }
});
