import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const supabaseUrl = Deno.env.get('SUPABASE_URL');
const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
// Rarity distribution function (matches backend logic)
function determineRarityOutcome(facilityLevel, suspicionLevel) {
  const roll = Math.random() * 100;
  // Bonuses and penalties
  const facilityBonus = facilityLevel * 0.5 // +0.5% per level
  ;
  const suspicionPenalty = suspicionLevel * 0.5 // -0.5% per suspicion
  ;
  // Base probabilities
  const adjustedCommon = 70 + facilityBonus - suspicionPenalty;
  const adjustedUncommon = 20 + facilityBonus - suspicionPenalty;
  const adjustedRare = 8 + facilityBonus - suspicionPenalty;
  const adjustedEpic = 1.5 + facilityBonus - suspicionPenalty;
  const adjustedLegendary = 0.5 + facilityBonus - suspicionPenalty;
  if (roll < adjustedCommon) {
    return 'COMMON';
  } else if (roll < adjustedCommon + adjustedUncommon) {
    return 'UNCOMMON';
  } else if (roll < adjustedCommon + adjustedUncommon + adjustedRare) {
    return 'RARE';
  } else if (roll < adjustedCommon + adjustedUncommon + adjustedRare + adjustedEpic) {
    return 'EPIC';
  } else if (roll < adjustedCommon + adjustedUncommon + adjustedRare + adjustedEpic + adjustedLegendary) {
    return 'LEGENDARY';
  } else {
    return 'MYTHIC';
  }
}
// Helper function to extract user ID from JWT
function extractUserIdFromJWT(token) {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return null;
    const payload = parts[1];
    const decoded = JSON.parse(atob(payload));
    return decoded.sub || null;
  } catch  {
    return null;
  }
}
Deno.serve(async (req)=>{
  try {
    if (req.method === 'OPTIONS') {
      return new Response('ok', {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST, OPTIONS',
          'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
        }
      });
    }
    const { p_facility_id, p_recipe_id, p_quantity } = await req.json();
    const authHeader = req.headers.get('authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Missing or invalid authorization header'
      }), {
        status: 401,
        headers: {
          'Content-Type': 'application/json'
        }
      });
    }
    if (!p_facility_id || !p_recipe_id) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Missing required parameters'
      }), {
        status: 400,
        headers: {
          'Content-Type': 'application/json'
        }
      });
    }
    const token = authHeader.slice(7);
    const playerId = extractUserIdFromJWT(token);
    if (!playerId) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Invalid JWT or missing user ID'
      }), {
        status: 401,
        headers: {
          'Content-Type': 'application/json'
        }
      });
    }
    const supabase = createClient(supabaseUrl, supabaseKey);
    const quantity = p_quantity || 1;
    console.log(`[start_facility_production] Player ${playerId}, Facility ${p_facility_id}, Recipe ${p_recipe_id}, Qty ${quantity}`);
    // Get facility
    const { data: facility, error: facilityError } = await supabase.from('facilities').select('*').eq('id', p_facility_id).eq('player_id', playerId).single();
    if (facilityError || !facility) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Facility not found or not owned'
      }), {
        status: 404,
        headers: {
          'Content-Type': 'application/json'
        }
      });
    }
    // Get recipe details
    const { data: recipe, error: recipeError } = await supabase.from('facility_recipes').select('*').eq('recipe_id', p_recipe_id).eq('facility_type', facility.facility_type).single();
    if (recipeError || !recipe) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Recipe not found for this facility'
      }), {
        status: 404,
        headers: {
          'Content-Type': 'application/json'
        }
      });
    }
    // Check facility level requirement
    if (facility.level < recipe.min_facility_level) {
      return new Response(JSON.stringify({
        success: false,
        error: `Facility level ${facility.level} is too low. Required: ${recipe.min_facility_level}`
      }), {
        status: 400,
        headers: {
          'Content-Type': 'application/json'
        }
      });
    }
    // Check if player has required materials
    const requiredMaterials = recipe.required_materials || {};
    const { data: inventory } = await supabase.from('inventory').select('item_id, quantity').eq('player_id', playerId);
    const inventoryMap = new Map();
    if (inventory) {
      inventory.forEach((item)=>{
        inventoryMap.set(item.item_id, item.quantity);
      });
    }
    // Validate materials
    for (const [materialId, required] of Object.entries(requiredMaterials)){
      const have = inventoryMap.get(materialId) || 0;
      const totalNeeded = required * quantity;
      if (have < totalNeeded) {
        return new Response(JSON.stringify({
          success: false,
          error: `Insufficient ${materialId}. Required: ${totalNeeded}, Have: ${have}`
        }), {
          status: 400,
          headers: {
            'Content-Type': 'application/json'
          }
        });
      }
    }
    // Check queue limit (max 10 items)
    const { data: queueItems, error: queueError } = await supabase.from('facility_production_queue').select('id').eq('facility_id', p_facility_id).is('completed_at', null).is('failed', false);
    if (queueItems && queueItems.length >= 10) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Queue is full (max 10 items)'
      }), {
        status: 400,
        headers: {
          'Content-Type': 'application/json'
        }
      });
    }
    // Determine rarity outcome
    const rarityOutcome = determineRarityOutcome(facility.level, facility.suspicion_level);
    // Calculate production duration with facility level bonus
    const speedBonus = facility.level * 0.1 + 1.0 // 1.1x at level 1, 1.5x at level 5, etc
    ;
    const baseDuration = recipe.duration_seconds;
    const adjustedDuration = Math.floor(baseDuration / speedBonus);
    // Create production queue item for each quantity
    const queueInserts = [];
    for(let i = 0; i < quantity; i++){
      queueInserts.push({
        facility_id: p_facility_id,
        recipe_id: p_recipe_id,
        quantity: 1,
        started_at: new Date().toISOString(),
        duration_seconds: adjustedDuration,
        rarity_outcome: rarityOutcome,
        completed_at: null,
        collected: false,
        failed: false
      });
    }
    const { data: queueData, error: insertError } = await supabase.from('facility_production_queue').insert(queueInserts).select();
    if (insertError) {
      console.error('[start_facility_production] Insert error:', insertError);
      return new Response(JSON.stringify({
        success: false,
        error: insertError.message
      }), {
        status: 400,
        headers: {
          'Content-Type': 'application/json'
        }
      });
    }
    // Deduct materials from inventory
    for (const [materialId, required] of Object.entries(requiredMaterials)){
      const totalNeeded = required * quantity;
      const have = inventoryMap.get(materialId);
      const { error: updateError } = await supabase.from('inventory').update({
        quantity: have - totalNeeded
      }).eq('player_id', playerId).eq('item_id', materialId);
      if (updateError) {
        console.error('[start_facility_production] Material deduction error:', updateError);
      }
    }
    // Increment suspicion slightly (production increases risk)
    const newSuspicion = Math.min(facility.suspicion_level + 2, 100);
    await supabase.from('facilities').update({
      suspicion_level: newSuspicion
    }).eq('id', p_facility_id);
    console.log(`[start_facility_production] Successfully started production. Rarity: ${rarityOutcome}, Duration: ${adjustedDuration}s`);
    return new Response(JSON.stringify({
      success: true,
      queue_items: queueData,
      rarity_outcome: rarityOutcome,
      adjusted_duration: adjustedDuration,
      suspicion_increased: 2,
      new_suspicion: newSuspicion
    }), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });
  } catch (err) {
    console.error('[start_facility_production] Error:', err);
    return new Response(JSON.stringify({
      success: false,
      error: err.message
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json'
      }
    });
  }
});
