import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const supabaseUrl = Deno.env.get('SUPABASE_URL');
const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
// Passive suspicion reduction per hour (level-based)
// Level 1 = 2% reduction per hour, Level 20 = 40% reduction per hour
const SUSPICION_REDUCTION_PER_LEVEL_HOUR = 2;
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
    // Calculate suspicion reduction based on level and time passed
    const now = new Date();
    const lastReducedAt = facility.last_suspicion_reduced_at ? new Date(facility.last_suspicion_reduced_at) : new Date(facility.updated_at);
    const hoursPassed = (now.getTime() - lastReducedAt.getTime()) / (1000 * 60 * 60);
    // Reduction formula: facility_level * SUSPICION_REDUCTION_PER_LEVEL_HOUR * hoursPassed
    const reductionAmount = facility.level * SUSPICION_REDUCTION_PER_LEVEL_HOUR * hoursPassed;
    const newSuspicion = Math.max(facility.suspicion_level - reductionAmount, 0);
    console.log(`[reduce_facility_suspicion] Facility ${p_facility_id}, Level ${facility.level}, Hours ${hoursPassed.toFixed(2)}, Reduction ${reductionAmount.toFixed(2)}`);
    // Update facility
    const { data: updatedFacility, error: updateError } = await supabase.from('facilities').update({
      suspicion_level: newSuspicion,
      last_suspicion_reduced_at: now.toISOString(),
      updated_at: now.toISOString()
    }).eq('id', p_facility_id).select().single();
    if (updateError) {
      console.error('[reduce_facility_suspicion] Update error:', updateError);
      return new Response(JSON.stringify({
        success: false,
        error: updateError.message
      }), {
        status: 400,
        headers: {
          'Content-Type': 'application/json'
        }
      });
    }
    return new Response(JSON.stringify({
      success: true,
      facility: updatedFacility,
      old_suspicion: facility.suspicion_level,
      new_suspicion: newSuspicion,
      reduction_amount: reductionAmount,
      hours_passed: hoursPassed,
      facility_level: facility.level
    }), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });
  } catch (err) {
    console.error('[reduce_facility_suspicion] Error:', err);
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
