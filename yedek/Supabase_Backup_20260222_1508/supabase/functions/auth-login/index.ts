import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};
serve(async (req)=>{
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: corsHeaders
    });
  }
  try {
    const { email, password, device_id } = await req.json();
    console.log('Login attempt with email:', email);
    // Validation
    if (!email || !password) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Email and password are required'
      }), {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        },
        status: 400
      });
    }
    // Validate password length
    if (password.length < 8) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Password must be at least 8 characters'
      }), {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        },
        status: 401
      });
    }
    // Create Supabase admin client
    const supabaseAdmin = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '', {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    });
    console.log('Attempting to sign in with email:', email);
    // Sign in with email and password
    const { data: sessionData, error: sessionError } = await supabaseAdmin.auth.signInWithPassword({
      email: email,
      password
    });
    if (sessionError) {
      console.error('Supabase auth error:', sessionError.message);
      return new Response(JSON.stringify({
        success: false,
        error: 'Invalid login credentials'
      }), {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        },
        status: 401
      });
    }
    if (!sessionData?.user || !sessionData?.session) {
      console.error('No session data returned');
      return new Response(JSON.stringify({
        success: false,
        error: 'Login failed'
      }), {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        },
        status: 401
      });
    }
    const authId = sessionData.user.id;
    // Get user profile from public.users
    const { data: userProfile, error: profileError } = await supabaseAdmin.from('public.users').select('*').eq('auth_id', authId).maybeSingle();
    if (profileError) {
      console.error('Profile fetch error:', profileError);
    }
    // Try to update last login in public.users
    if (userProfile?.id) {
      await supabaseAdmin.from('public.users').update({
        last_login_at: new Date().toISOString(),
        is_online: true
      }).eq('id', userProfile.id).catch((err)=>console.error('Update last_login error:', err));
    }
    // Return success with user data
    const responseUser = userProfile || {
      id: authId,
      auth_id: authId,
      email: sessionData.user.email,
      username: sessionData.user.user_metadata?.username || sessionData.user.email?.split('@')[0],
      level: 1,
      gold: 1000,
      gems: 100,
      energy: 100,
      max_energy: 100
    };
    return new Response(JSON.stringify({
      success: true,
      message: 'Login successful',
      data: {
        session: sessionData.session,
        user: responseUser
      }
    }), {
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      },
      status: 200
    });
  } catch (error) {
    console.error('Unexpected error:', error);
    return new Response(JSON.stringify({
      success: false,
      error: error.message || 'An error occurred'
    }), {
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      },
      status: 500
    });
  }
});
