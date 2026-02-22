import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const supabaseUrl = Deno.env.get('SUPABASE_URL');
const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
// Facility configuration (must match FacilityManager.gd)
// Includes both old and new naming conventions for compatibility
const FACILITIES_CONFIG = {
  // Mining variants
  mine: {
    base_upgrade_cost: 2000,
    upgrade_multiplier: 1.6,
    workers_per_level: 2,
    offline_cap_per_level: 50
  },
  mining: {
    base_upgrade_cost: 2000,
    upgrade_multiplier: 1.6,
    workers_per_level: 2,
    offline_cap_per_level: 50
  },
  // Wood variants
  sawmill: {
    base_upgrade_cost: 1500,
    upgrade_multiplier: 1.5,
    workers_per_level: 2,
    offline_cap_per_level: 50
  },
  woodworking: {
    base_upgrade_cost: 1500,
    upgrade_multiplier: 1.5,
    workers_per_level: 2,
    offline_cap_per_level: 50
  },
  lumber_mill: {
    base_upgrade_cost: 1500,
    upgrade_multiplier: 1.5,
    workers_per_level: 2,
    offline_cap_per_level: 50
  },
  // Farm variants
  farm: {
    base_upgrade_cost: 1200,
    upgrade_multiplier: 1.5,
    workers_per_level: 2,
    offline_cap_per_level: 50
  },
  farming: {
    base_upgrade_cost: 1200,
    upgrade_multiplier: 1.5,
    workers_per_level: 2,
    offline_cap_per_level: 50
  },
  herb_garden: {
    base_upgrade_cost: 1800,
    upgrade_multiplier: 1.6,
    workers_per_level: 2,
    offline_cap_per_level: 50
  },
  blacksmith: {
    base_upgrade_cost: 3000,
    upgrade_multiplier: 1.7,
    workers_per_level: 3,
    offline_cap_per_level: 100
  },
  armorer: {
    base_upgrade_cost: 3000,
    upgrade_multiplier: 1.7,
    workers_per_level: 3,
    offline_cap_per_level: 100
  },
  alchemy_lab: {
    base_upgrade_cost: 2500,
    upgrade_multiplier: 1.6,
    workers_per_level: 2,
    offline_cap_per_level: 100
  },
  runesmith: {
    base_upgrade_cost: 4000,
    upgrade_multiplier: 1.8,
    workers_per_level: 3,
    offline_cap_per_level: 120
  },
  scroll_library: {
    base_upgrade_cost: 3500,
    upgrade_multiplier: 1.7,
    workers_per_level: 2,
    offline_cap_per_level: 120
  },
  gem_cutter: {
    base_upgrade_cost: 3200,
    upgrade_multiplier: 1.7,
    workers_per_level: 2,
    offline_cap_per_level: 100
  },
  enhancement_master: {
    base_upgrade_cost: 5000,
    upgrade_multiplier: 1.8,
    workers_per_level: 3,
    offline_cap_per_level: 150
  },
  master_alchemist: {
    base_upgrade_cost: 5500,
    upgrade_multiplier: 1.8,
    workers_per_level: 3,
    offline_cap_per_level: 150
  },
  master_armorer: {
    base_upgrade_cost: 6000,
    upgrade_multiplier: 1.8,
    workers_per_level: 3,
    offline_cap_per_level: 160
  },
  warehouse: {
    base_upgrade_cost: 2000,
    upgrade_multiplier: 1.5,
    workers_per_level: 1,
    offline_cap_per_level: 0
  },
  market_hub: {
    base_upgrade_cost: 2500,
    upgrade_multiplier: 1.5,
    workers_per_level: 1,
    offline_cap_per_level: 0
  }
};
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
    const { p_facility_id, p_type } = await req.json();
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
    if (!p_facility_id || !p_type) {
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
    console.log(`[upgrade_facility] Player ${playerId}, Facility ${p_facility_id}`);
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
    // Check if max level
    const maxLevel = 20;
    if (facility.level >= maxLevel) {
      return new Response(JSON.stringify({
        success: false,
        error: `Facility already at max level (${maxLevel})`
      }), {
        status: 400,
        headers: {
          'Content-Type': 'application/json'
        }
      });
    }
    // Calculate upgrade cost
    const config = FACILITIES_CONFIG[p_type];
    if (!config) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Invalid facility type'
      }), {
        status: 400,
        headers: {
          'Content-Type': 'application/json'
        }
      });
    }
    const currentLevel = facility.level;
    const baseCost = config.base_upgrade_cost;
    const multiplier = config.upgrade_multiplier;
    const upgradeCost = Math.floor(baseCost * Math.pow(multiplier, currentLevel));
    // Check player has gold
    const { data: playerData } = await supabase.from('users').select('gold').eq('auth_id', playerId).single();
    if (!playerData || playerData.gold < upgradeCost) {
      return new Response(JSON.stringify({
        success: false,
        error: `Insufficient gold. Required: ${upgradeCost}, Have: ${playerData?.gold || 0}`
      }), {
        status: 400,
        headers: {
          'Content-Type': 'application/json'
        }
      });
    }
    // Calculate new level benefits
    const newLevel = currentLevel + 1;
    const newWorkers = config.workers_per_level * newLevel;
    const newOfflineCap = config.offline_cap_per_level * newLevel;
    // Update facility (upgrade_cost is calculated client-side, not stored in DB)
    const { data: updatedFacility, error: updateError } = await supabase.from('facilities').update({
      level: newLevel,
      workers: newWorkers,
      offline_production_cap: newOfflineCap,
      updated_at: new Date().toISOString()
    }).eq('id', p_facility_id).select().single();
    if (updateError) {
      console.error('[upgrade_facility] Update error:', updateError);
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
    // Deduct gold
    const { error: goldError } = await supabase.from('users').update({
      gold: playerData.gold - upgradeCost
    }).eq('auth_id', playerId);
    if (goldError) {
      console.error('[upgrade_facility] Gold deduction error:', goldError);
    }
    console.log(`[upgrade_facility] Successfully upgraded to level ${newLevel}, cost: ${upgradeCost}`);
    return new Response(JSON.stringify({
      success: true,
      facility: updatedFacility,
      new_level: newLevel,
      new_workers: newWorkers,
      new_offline_cap: newOfflineCap,
      gold_deducted: upgradeCost,
      remaining_gold: playerData.gold - upgradeCost
    }), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });
  } catch (err) {
    console.error('[upgrade_facility] Error:', err);
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
