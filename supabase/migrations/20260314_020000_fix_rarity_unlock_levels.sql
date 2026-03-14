-- Drop the existing function first or just replace it
CREATE OR REPLACE FUNCTION public._plan2_rarity_unlock_level(p_rarity text)
RETURNS integer
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  RETURN CASE lower(p_rarity)
    WHEN 'common' THEN 1
    WHEN 'uncommon' THEN 2
    WHEN 'rare' THEN 3
    WHEN 'epic' THEN 4
    WHEN 'legendary' THEN 5
    WHEN 'mythic' THEN 6
    ELSE 10
  END;
END;
$$;
