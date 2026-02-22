import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const supabaseUrl = Deno.env.get('SUPABASE_URL');
const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
// Simple JWT decoder that doesn't require Supabase SDK
function decodeJWT(token) {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return null;
    const payload = parts[1];
    const padded = payload + '='.repeat((4 - payload.length % 4) % 4);
    const decoded = atob(padded);
    return JSON.parse(decoded);
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
          'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
          'Access-Control-Allow-Headers': 'authorization, content-type'
        }
      });
    }
    // Extract and verify JWT
    const authHeader = req.headers.get('authorization') || '';
    const token = authHeader.replace('Bearer ', '').trim();
    if (!token) {
      return new Response(JSON.stringify({
        error: 'Missing authorization header'
      }), {
        status: 401,
        headers: {
          'Content-Type': 'application/json'
        }
      });
    }
    const jwtPayload = decodeJWT(token);
    if (!jwtPayload || !jwtPayload.sub) {
      return new Response(JSON.stringify({
        error: 'Invalid JWT'
      }), {
        status: 401,
        headers: {
          'Content-Type': 'application/json'
        }
      });
    }
    const playerId = jwtPayload.sub;
    console.log(`[get_player_facilities] Authenticated: ${playerId}`);
    const supabase = createClient(supabaseUrl, supabaseKey);
    // Simple REST query
    const { data, error } = await supabase.from('facilities').select('*').eq('player_id', playerId).order('facility_type', {
      ascending: true
    });
    if (error) {
      console.error(`[get_player_facilities] Query error: ${error.message}`);
      return new Response(JSON.stringify({
        error: error.message
      }), {
        status: 400,
        headers: {
          'Content-Type': 'application/json'
        }
      });
    }
    return new Response(JSON.stringify({
      success: true,
      data: data || []
    }), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });
  } catch (err) {
    const errMsg = err instanceof Error ? err.message : String(err);
    console.error(`[get_player_facilities] Exception: ${errMsg}`);
    return new Response(JSON.stringify({
      error: errMsg
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json'
      }
    });
  }
});
