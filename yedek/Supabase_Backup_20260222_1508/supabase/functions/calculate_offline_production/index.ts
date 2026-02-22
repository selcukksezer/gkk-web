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
    console.log(`[calculate_offline_production] Facility ${p_facility_id}, Last collected: ${facility.last_production_collected_at}`);
    // Get all incomplete production queue items
    const { data: queueItems, error: queueError } = await supabase.from('facility_production_queue').select('*').eq('facility_id', p_facility_id).is('completed_at', null).order('created_at', {
      ascending: true
    });
    if (queueError) {
      console.error('[calculate_offline_production] Queue error:', queueError);
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
    const now = new Date();
    const lastCollected = facility.last_production_collected_at ? new Date(facility.last_production_collected_at) : new Date(facility.created_at);
    const offlineSeconds = (now.getTime() - lastCollected.getTime()) / 1000;
    let completedItems = [];
    let totalTimeUsed = 0;
    console.log(`[calculate_offline_production] Offline seconds: ${offlineSeconds.toFixed(0)}`);
    // Process each queue item to see if it should complete offline
    for (const item of queueItems){
      const itemCreated = new Date(item.created_at);
      const itemTimeElapsed = (now.getTime() - itemCreated.getTime()) / 1000;
      // If item took longer than production time, it's ready
      if (itemTimeElapsed >= item.production_time_seconds) {
        const completedTime = new Date(itemCreated.getTime() + item.production_time_seconds * 1000);
        // Mark as completed
        const { error: updateError } = await supabase.from('facility_production_queue').update({
          completed_at: completedTime.toISOString(),
          updated_at: now.toISOString()
        }).eq('id', item.id);
        if (!updateError) {
          completedItems.push({
            id: item.id,
            item_id: item.item_id,
            quantity: item.quantity,
            rarity: item.rarity,
            completed_at: completedTime,
            completed_offline: true
          });
          totalTimeUsed += item.production_time_seconds;
        }
      } else {
        break;
      }
    }
    console.log(`[calculate_offline_production] Completed offline: ${completedItems.length} items`);
    // Get all completed items that haven't been collected yet
    const { data: allCompleted } = await supabase.from('facility_production_queue').select('*').eq('facility_id', p_facility_id).not('completed_at', 'is', null).eq('collected', false).order('completed_at', {
      ascending: true
    });
    const readyToCollect = allCompleted || [];
    return new Response(JSON.stringify({
      success: true,
      facility_id: p_facility_id,
      offline_seconds: offlineSeconds,
      completed_offline: completedItems.length,
      newly_completed: completedItems,
      ready_to_collect: readyToCollect.length,
      total_time_used_seconds: totalTimeUsed,
      last_collected_at: facility.last_production_collected_at,
      current_time: now.toISOString()
    }), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });
  } catch (err) {
    console.error('[calculate_offline_production] Error:', err);
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
