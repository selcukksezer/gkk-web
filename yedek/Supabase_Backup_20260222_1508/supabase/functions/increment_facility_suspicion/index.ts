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
    const { p_facility_id, p_amount } = await req.json();
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
    if (!p_facility_id || p_amount === undefined) {
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
    console.log(`[increment_facility_suspicion] Player ${playerId}, Facility ${p_facility_id}, Amount +${p_amount}`);
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
    // Calculate new suspicion (max 100)
    const newSuspicion = Math.min(facility.suspicion_level + p_amount, 100);
    // Update facility
    const { data: updatedFacility, error: updateError } = await supabase.from('facilities').update({
      suspicion_level: newSuspicion,
      updated_at: new Date().toISOString()
    }).eq('id', p_facility_id).select().single();
    if (updateError) {
      console.error('[increment_facility_suspicion] Update error:', updateError);
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
    // Check if should admit to prison (80%+ suspicion = 50% + suspicion% chance)
    let admitted = false;
    let prisonData = null;
    if (newSuspicion >= 80) {
      // Roll for prison admission
      const imprisonmentChance = 50 + newSuspicion // At 80% = 130% (guaranteed), at 100% = 150%
      ;
      const roll = Math.random() * 100;
      if (roll < imprisonmentChance) {
        // Admit to prison
        const sentenceHours = Math.floor(2 + newSuspicion / 10) // 2-12 hours based on suspicion
        ;
        const releaseTime = new Date();
        releaseTime.setHours(releaseTime.getHours() + sentenceHours);
        const { data: prisonRecord, error: prisonError } = await supabase.from('prison_records').insert({
          player_id: playerId,
          facility_id: p_facility_id,
          reason: 'High suspicion at facility operations',
          sentence_hours: sentenceHours,
          admitted_at: new Date().toISOString(),
          released_at: releaseTime.toISOString()
        }).select().single();
        if (!prisonError && prisonRecord) {
          admitted = true;
          prisonData = {
            sentence_hours: sentenceHours,
            release_time: releaseTime.toISOString()
          };
          // Reset suspicion after admission
          await supabase.from('facilities').update({
            suspicion_level: 0
          }).eq('id', p_facility_id);
          console.log(`[increment_facility_suspicion] Player admitted to prison for ${sentenceHours} hours`);
        }
      }
    }
    console.log(`[increment_facility_suspicion] New suspicion: ${newSuspicion}${admitted ? ' (IMPRISONED)' : ''}`);
    return new Response(JSON.stringify({
      success: true,
      facility: updatedFacility,
      old_suspicion: facility.suspicion_level,
      new_suspicion: newSuspicion,
      admitted_to_prison: admitted,
      prison_data: prisonData
    }), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });
  } catch (err) {
    console.error('[increment_facility_suspicion] Error:', err);
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
