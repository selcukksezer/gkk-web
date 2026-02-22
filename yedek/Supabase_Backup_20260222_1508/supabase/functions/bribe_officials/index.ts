import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const supabaseUrl = Deno.env.get('SUPABASE_URL');
const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
const BRIBE_COST_GEMS = 5;
const BRIBE_SUSPICION_REDUCTION = 10;
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
    const { p_facility_id, p_gems } = await req.json();
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
    // Always use fixed bribe cost, ignore p_gems to prevent accidental overspending
    const gemsAmount = BRIBE_COST_GEMS;
    console.log(`[bribe_officials] Player ${playerId}, Facility ${p_facility_id}, Cost: ${gemsAmount} gems`);
    // Get facility
    const { data: facility, error: facilityError } = await supabase.from('facilities').select('*').eq('id', p_facility_id).eq('user_id', playerId).single();
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
    // Get player gems
    const { data: playerData } = await supabase.from('users').select('gems').eq('auth_id', playerId).single();
    if (!playerData || playerData.gems < gemsAmount) {
      return new Response(JSON.stringify({
        success: false,
        error: `Insufficient gems. Required: ${gemsAmount}, Have: ${playerData?.gems || 0}`
      }), {
        status: 400,
        headers: {
          'Content-Type': 'application/json'
        }
      });
    }
    // Calculate new suspicion (reduce by amount, minimum 0)
    const suspicionReduction = BRIBE_SUSPICION_REDUCTION;
    const newSuspicion = Math.max(facility.suspicion_level - suspicionReduction, 0);
    // Update facility
    const { data: updatedFacility, error: updateError } = await supabase.from('facilities').update({
      suspicion_level: newSuspicion,
      updated_at: new Date().toISOString()
    }).eq('id', p_facility_id).select().single();
    if (updateError) {
      console.error('[bribe_officials] Update error:', updateError);
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
    // Deduct gems
    const { error: gemError } = await supabase.from('users').update({
      gems: playerData.gems - gemsAmount
    }).eq('auth_id', playerId);
    if (gemError) {
      console.error('[bribe_officials] Gem deduction error:', gemError);
    }
    console.log(`[bribe_officials] Suspicion reduced from ${facility.suspicion_level} to ${newSuspicion}, cost: ${gemsAmount} gems`);
    return new Response(JSON.stringify({
      success: true,
      facility: updatedFacility,
      old_suspicion: facility.suspicion_level,
      new_suspicion: newSuspicion,
      gems_deducted: gemsAmount,
      remaining_gems: playerData.gems - gemsAmount,
      suspicion_reduced: suspicionReduction
    }), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });
  } catch (err) {
    console.error('[bribe_officials] Error:', err);
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
