import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const supabaseUrl = Deno.env.get('SUPABASE_URL');
const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
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
    const { p_facility_id } = await req.json();
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
    if (!p_facility_id) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Missing p_facility_id'
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
    console.log(`[collect_facility_production] Player ${playerId}, Facility ${p_facility_id}`);
    // Get facility (verify ownership)
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
    // Get all completed but not collected items from queue
    const { data: readyItems, error: queueError } = await supabase.from('facility_production_queue').select(`
        id,
        recipe_id,
        quantity,
        rarity_outcome,
        completed_at,
        facility_recipes(product_item_id, product_quantity)
      `).eq('facility_id', p_facility_id).not('completed_at', 'is', null).eq('collected', false).eq('failed', false);
    if (queueError) {
      console.error('[collect_facility_production] Query error:', queueError);
      return new Response(JSON.stringify({
        success: false,
        error: queueError.message
      }), {
        status: 400,
        headers: {
          'Content-Type': 'application/json'
        }
      });
    }
    if (!readyItems || readyItems.length === 0) {
      return new Response(JSON.stringify({
        success: true,
        message: 'No items to collect',
        items_collected: []
      }), {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      });
    }
    // Collect items: add to inventory and mark as collected
    const collectedItems = [];
    const queueIds = [];
    for (const item of readyItems){
      const recipe = Array.isArray(item.facility_recipes) ? item.facility_recipes[0] : item.facility_recipes;
      if (recipe && recipe.product_item_id) {
        const productItemId = recipe.product_item_id;
        const quantity = (recipe.product_quantity || 1) * (item.quantity || 1);
        const rarity = item.rarity_outcome || 'COMMON';
        // Add to inventory
        const { data: existingInventory } = await supabase.from('inventory').select('quantity').eq('player_id', playerId).eq('item_id', productItemId).single();
        if (existingInventory) {
          // Update quantity
          await supabase.from('inventory').update({
            quantity: existingInventory.quantity + quantity
          }).eq('player_id', playerId).eq('item_id', productItemId);
        } else {
          // Insert new item
          await supabase.from('inventory').insert({
            player_id: playerId,
            item_id: productItemId,
            quantity: quantity,
            rarity: rarity
          });
        }
        // Log crafted item
        await supabase.from('crafted_items_log').insert({
          player_id: playerId,
          item_id: productItemId,
          quantity: quantity,
          rarity: rarity,
          facility_id: p_facility_id,
          recipe_id: item.recipe_id,
          created_at: new Date().toISOString()
        });
        collectedItems.push({
          item_id: productItemId,
          quantity: quantity,
          rarity: rarity
        });
        queueIds.push(item.id);
      }
    }
    // Mark queue items as collected
    if (queueIds.length > 0) {
      const { error: updateError } = await supabase.from('facility_production_queue').update({
        collected: true,
        collected_at: new Date().toISOString()
      }).in('id', queueIds);
      if (updateError) {
        console.error('[collect_facility_production] Update error:', updateError);
      }
    }
    // Update facility's last_production_collected_at for offline production calculation
    await supabase.from('facilities').update({
      last_production_collected_at: new Date().toISOString()
    }).eq('id', p_facility_id);
    console.log(`[collect_facility_production] Collected ${collectedItems.length} items`);
    return new Response(JSON.stringify({
      success: true,
      items_collected: collectedItems,
      count: collectedItems.length
    }), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });
  } catch (err) {
    console.error('[collect_facility_production] Error:', err);
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
