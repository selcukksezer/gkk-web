-- Migration: 20260312_111000_dismantle_blueprint.sql
-- Description: RPC for dismantling excess blueprints into critical fragments for guild monument

CREATE OR REPLACE FUNCTION dismantle_blueprint(p_blueprint_type text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_player record;
  v_guild_id uuid;
  v_blueprint_record guild_blueprints%ROWTYPE;
  v_fragments_earned int;
BEGIN
  -- 1. Get player and guild
  SELECT * INTO v_player FROM public.users WHERE auth_id = v_user_id;
  v_guild_id := v_player.guild_id;

  IF v_guild_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Bir loncada değilsiniz.');
  END IF;

  -- 2. Check officer rights (optional, maybe anyone can dismantle?)
  -- For now, let's allow officers/leader
  IF v_player.guild_role NOT IN ('leader', 'officer') THEN
    RETURN json_build_object('success', false, 'message', 'Sadece lonca lideri ve subaylar parçalama yapabilir.');
  END IF;

  -- 3. Check if blueprint exists and fragments > 0
  SELECT * INTO v_blueprint_record FROM guild_blueprints WHERE guild_id = v_guild_id AND blueprint_type = p_blueprint_type;
  
  IF NOT FOUND OR v_blueprint_record.fragments_collected < 1 THEN
    RETURN json_build_object('success', false, 'message', 'Bu blueprint türünden yeterli parçanız yok.');
  END IF;

  -- 4. Decrement blueprint fragment
  UPDATE guild_blueprints 
  SET fragments_collected = fragments_collected - 1
  WHERE id = v_blueprint_record.id;

  -- 5. Random yield 3-10 fragments
  v_fragments_earned := floor(random() * 8 + 3)::int;

  -- 6. Add to monument_critical pool
  -- Check if monument_critical row exists, else insert
  INSERT INTO guild_monument_progress (guild_id, resource_type, amount_donated)
  VALUES (v_guild_id, 'monument_critical', v_fragments_earned)
  ON CONFLICT (guild_id, resource_type) 
  DO UPDATE SET amount_donated = guild_monument_progress.amount_donated + v_fragments_earned;

  RETURN json_build_object(
    'success', true, 
    'message', 'Blueprint parçalandı! Loncaya ' || v_fragments_earned || ' adet Critical Kaynak eklendi.',
    'fragments', v_fragments_earned
  );
END;
$$;
