// PvP API - Attack player
// POST /pvp/attack
import { createResponse, createErrorResponse, handleCORS, validateAuth, validateBody, supabaseClient, addXP } from "../_shared/utils.ts";
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
      "defender_id"
    ]);
    if (!validation.valid) {
      return createErrorResponse("MISSING_FIELDS", "Missing required fields", {
        missing: validation.missing
      }, 400);
    }
    const { defender_id } = body;
    // Get attacker
    const { data: attacker } = await supabaseClient.from("users").select("*").eq("auth_id", auth.userId).single();
    if (!attacker) {
      return createErrorResponse("USER_NOT_FOUND", "Attacker not found", null, 404);
    }
    // Check energy
    const pvpEnergyCost = 10;
    if (attacker.energy < pvpEnergyCost) {
      return createErrorResponse("INSUFFICIENT_ENERGY", "Not enough energy", {
        required: pvpEnergyCost,
        current: attacker.energy
      }, 400);
    }
    // Check hospital
    if (attacker.hospital_until && new Date(attacker.hospital_until) > new Date()) {
      return createErrorResponse("IN_HOSPITAL", "You are in hospital", {
        until: attacker.hospital_until
      }, 400);
    }
    // Get defender
    const { data: defender } = await supabaseClient.from("users").select("*").eq("id", defender_id).single();
    if (!defender) {
      return createErrorResponse("DEFENDER_NOT_FOUND", "Target player not found", null, 404);
    }
    // Can't attack yourself
    if (attacker.id === defender.id) {
      return createErrorResponse("INVALID_TARGET", "Cannot attack yourself", null, 400);
    }
    // Calculate powers (simplified - would be more complex in production)
    const attackerPower = attacker.level * 10 + attacker.pvp_rating / 10;
    const defenderPower = defender.level * 10 + defender.pvp_rating / 10;
    // Determine winner (with some randomness)
    const attackerChance = attackerPower / (attackerPower + defenderPower);
    const roll = Math.random();
    const attackerWins = roll < attackerChance;
    const winnerId = attackerWins ? attacker.id : defender.id;
    const goldStolen = attackerWins ? Math.floor(defender.gold * 0.05) : 0; // 5% of defender's gold
    const ratingChange = attackerWins ? 10 : -5;
    // Update attacker
    await supabaseClient.from("users").update({
      energy: attacker.energy - pvpEnergyCost,
      gold: attacker.gold + goldStolen,
      pvp_rating: Math.max(0, attacker.pvp_rating + ratingChange),
      pvp_wins: attackerWins ? attacker.pvp_wins + 1 : attacker.pvp_wins,
      pvp_losses: attackerWins ? attacker.pvp_losses : attacker.pvp_losses + 1,
      pvp_streak: attackerWins ? (attacker.pvp_streak || 0) + 1 : 0
    }).eq("id", attacker.id);
    // Update defender
    const defenderUpdate = {
      gold: Math.max(0, defender.gold - goldStolen),
      pvp_rating: Math.max(0, defender.pvp_rating - ratingChange)
    };
    if (!attackerWins) {
      defenderUpdate.pvp_wins = defender.pvp_wins + 1;
    } else {
      defenderUpdate.pvp_losses = defender.pvp_losses + 1;
      // Send to hospital if loss
      const hospitalDuration = 60 * 30; // 30 minutes
      defenderUpdate.hospital_until = new Date(Date.now() + hospitalDuration * 1000).toISOString();
      defenderUpdate.hospital_reason = `Defeated by ${attacker.username}`;
    }
    await supabaseClient.from("users").update(defenderUpdate).eq("id", defender.id);
    // Record battle
    await supabaseClient.from("pvp_battles").insert({
      attacker_id: attacker.id,
      defender_id: defender.id,
      attacker_power: attackerPower,
      defender_power: defenderPower,
      winner_id: winnerId,
      gold_stolen: goldStolen,
      rating_change: ratingChange
    });
    // Add XP
    const xpGained = attackerWins ? 100 : 25;
    const levelUpInfo = await addXP(attacker.id, xpGained);
    return createResponse({
      result: attackerWins ? "victory" : "defeat",
      gold_change: attackerWins ? goldStolen : 0,
      rating_change: ratingChange,
      xp_gained: xpGained,
      energy_spent: pvpEnergyCost,
      level_up: levelUpInfo
    });
  } catch (error) {
    console.error("PvP attack error:", error);
    return createErrorResponse("INTERNAL_ERROR", "An unexpected error occurred", null, 500);
  }
});
