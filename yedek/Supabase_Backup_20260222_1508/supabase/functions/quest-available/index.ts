// Quest API - Get available quests
// GET /quest/available
import { createResponse, createErrorResponse, handleCORS, validateAuth, supabaseClient } from "../_shared/utils.ts";
Deno.serve(async (req)=>{
  const corsResponse = handleCORS(req);
  if (corsResponse) return corsResponse;
  try {
    const auth = await validateAuth(req);
    if (!auth.success) {
      return createErrorResponse("UNAUTHORIZED", auth.error || "Authentication required", null, 401);
    }
    // Get user level
    const { data: user } = await supabaseClient.from("users").select("id, level").eq("auth_id", auth.userId).single();
    if (!user) {
      return createErrorResponse("USER_NOT_FOUND", "User not found", null, 404);
    }
    // Get active quests
    const { data: quests, error } = await supabaseClient.from("quests").select("*").eq("is_active", true).lte("required_level", user.level);
    if (error) {
      return createErrorResponse("QUERY_FAILED", "Failed to load quests", {
        error: error.message
      }, 500);
    }
    // Get user's quest progress
    const { data: userQuests } = await supabaseClient.from("user_quests").select("quest_id, status, progress").eq("user_id", user.id);
    // Filter out already completed quests
    const completedQuestIds = (userQuests || []).filter((uq)=>uq.status === "completed").map((uq)=>uq.quest_id);
    const activeQuestIds = (userQuests || []).filter((uq)=>uq.status === "active").map((uq)=>uq.quest_id);
    const availableQuests = quests?.filter((q)=>!completedQuestIds.includes(q.id) && !activeQuestIds.includes(q.id));
    return createResponse({
      quests: availableQuests
    });
  } catch (error) {
    console.error("Available quests error:", error);
    return createErrorResponse("INTERNAL_ERROR", "An unexpected error occurred", null, 500);
  }
});
