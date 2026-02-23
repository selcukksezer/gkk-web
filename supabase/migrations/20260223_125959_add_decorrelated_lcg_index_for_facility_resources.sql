-- Migration: add_decorrelated_lcg_index_for_facility_resources
-- Created: 2026-02-23 12:59:59 (file timestamp included in name)
-- Purpose: provide a helper function that computes a deterministic, decorrelated
-- resource-pool index using a second LCG. This lets collect functions choose
-- items with more variety while remaining deterministic per seed.

-- NOTE: This migration only adds the helper function. To apply the new index
-- selection in the main RPC `collect_facility_resources_v2`, update the RPC
-- implementation to call `public._facility_resource_index(p_seed, v_i, array_length(v_resources_pool,1))`
-- where appropriate. This avoids editing backup SQL files directly.

CREATE OR REPLACE FUNCTION public._facility_resource_index(
    p_seed bigint,
    p_i int,
    p_pool_len int
) RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_index_rng double precision;
    v_idx int;
BEGIN
    -- Use a second LCG to decorrelate index selection from rarity RNG.
    -- Constants: multiplier 48271 (Park-Miller), modulus 2147483647 (2^31-1)
    v_index_rng := ((p_seed + (p_i * 7)) * 48271.0 % 2147483647.0) / 2147483647.0;

    IF p_pool_len <= 0 THEN
        RETURN 0;
    END IF;

    v_idx := floor(v_index_rng * p_pool_len)::INT;

    IF v_idx < 0 THEN
        v_idx := 0;
    ELSIF v_idx >= p_pool_len THEN
        v_idx := p_pool_len - 1;
    END IF;

    RETURN v_idx;
END;
$$;

-- Example usage (SQL snippet to integrate into `collect_facility_resources_v2`):
-- v_resource_index := public._facility_resource_index(p_seed, v_i, array_length(v_resources_pool,1));
-- v_item_id := v_resources_pool[v_resource_index + 1];

-- End of migration
