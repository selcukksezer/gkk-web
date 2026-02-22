// @ts-nocheck
// Deno runtime globals
// @ts-ignore: provided at runtime
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};
serve(async (req)=>{
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: corsHeaders
    });
  }
  try {
    const supabaseClient = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_ANON_KEY') ?? '', {
      global: {
        headers: {
          Authorization: req.headers.get('Authorization')
        }
      }
    });
    const { data: { user } } = await supabaseClient.auth.getUser();
    if (!user) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Unauthorized'
      }), {
        status: 401,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    const url = new URL(req.url);
    const method = url.pathname.split('/').pop();
    switch(method){
      case 'status':
        return await handleStatus(supabaseClient, user.id);
      case 'release':
        return await handleRelease(supabaseClient, user.id, req);
      case 'admit':
        return await handleAdmit(supabaseClient, user.id, req);
      default:
        return new Response(JSON.stringify({
          success: false,
          error: 'Method not found'
        }), {
          status: 404,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json'
          }
        });
    }
  } catch (error) {
    console.error('Error:', error);
    return new Response(JSON.stringify({
      success: false,
      error: error?.message || String(error)
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  }
});
async function handleStatus(supabaseClient, userId) {
  const { data, error } = await supabaseClient.from('game.users').select('hospital_until, hospital_reason').eq('auth_id', userId).single();
  if (error) {
    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  }
  const inHospital = data.hospital_until && new Date(data.hospital_until) > new Date();
  const releaseTime = data.hospital_until ? Math.floor(new Date(data.hospital_until).getTime() / 1000) : 0;
  return new Response(JSON.stringify({
    success: true,
    in_hospital: inHospital,
    release_time: releaseTime,
    reason: data.hospital_reason || ''
  }), {
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json'
    }
  });
}
async function handleRelease(supabaseClient, userId, req) {
  const body = await req.json();
  const { method, cost } = body;
  // Get current user data
  const { data: userData, error: userError } = await supabaseClient.from('game.users').select('gems, hospital_until').eq('auth_id', userId).single();
  if (userError) {
    return new Response(JSON.stringify({
      success: false,
      error: userError.message
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  }
  // Check if in hospital
  if (!userData.hospital_until || new Date(userData.hospital_until) <= new Date()) {
    return new Response(JSON.stringify({
      success: false,
      error: 'Not in hospital'
    }), {
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  }
  if (method === 'gems') {
    // Check gems
    if (userData.gems < cost) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Insufficient gems'
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    // Update gems and clear hospital
    const { error: updateError } = await supabaseClient.from('game.users').update({
      gems: userData.gems - cost,
      hospital_until: null,
      hospital_reason: null,
      updated_at: new Date().toISOString()
    }).eq('auth_id', userId);
    if (updateError) {
      return new Response(JSON.stringify({
        success: false,
        error: updateError.message
      }), {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    return new Response(JSON.stringify({
      success: true,
      method: 'gems',
      cost: cost,
      new_gems: userData.gems - cost
    }), {
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  }
  // For other methods (guild, quest), just clear hospital
  const { error: updateError } = await supabaseClient.from('game.users').update({
    hospital_until: null,
    hospital_reason: null,
    updated_at: new Date().toISOString()
  }).eq('auth_id', userId);
  if (updateError) {
    return new Response(JSON.stringify({
      success: false,
      error: updateError.message
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  }
  return new Response(JSON.stringify({
    success: true,
    method: method
  }), {
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json'
    }
  });
}
async function handleAdmit(supabaseClient, userId, req) {
  const body = await req.json();
  const { reason, release_time } = body;
  // Update hospital status
  const { error: updateError } = await supabaseClient.from('game.users').update({
    hospital_until: new Date(release_time * 1000).toISOString(),
    hospital_reason: reason,
    updated_at: new Date().toISOString()
  }).eq('auth_id', userId);
  if (updateError) {
    return new Response(JSON.stringify({
      success: false,
      error: updateError.message
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  }
  return new Response(JSON.stringify({
    success: true,
    reason: reason,
    release_time: release_time
  }), {
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json'
    }
  });
}
