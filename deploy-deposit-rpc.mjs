#!/usr/bin/env node

/**
 * Deploy deposit_to_bank RPC with quantity support to Supabase
 * Requires: .env.local with NEXT_PUBLIC_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY
 */

import { createClient } from "@supabase/supabase-js";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL;
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
  console.error(
    "❌ Missing SUPABASE_URL or SERVICE_ROLE_KEY in environment"
  );
  console.error("Add them to .env.local");
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  db: {
    schema: "public",
  },
});

const sql = `
-- ====================================================================
-- RPC: deposit_to_bank
-- Move items from inventory to bank (supports partial deposit per item)
-- ====================================================================
DROP FUNCTION IF EXISTS public.deposit_to_bank(uuid[]);

CREATE FUNCTION public.deposit_to_bank(p_item_row_ids uuid[], p_quantities integer[] DEFAULT NULL)
RETURNS TABLE (
  success boolean,
  message text,
  items_deposited integer,
  new_used_slots integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_deposit_count integer := 0;
  v_used_slots integer;
  v_max_slots integer;
  v_item_row uuid;
  v_quantity integer;
  v_idx integer := 1;
  v_inv_quantity integer;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'Not authenticated'::text, 0::integer, 0::integer;
    RETURN;
  END IF;

  -- Ensure bank account exists
  INSERT INTO public.user_bank_account (user_id) 
  VALUES (v_user_id)
  ON CONFLICT (user_id) DO NOTHING;

  -- Get current bank status
  SELECT total_slots, used_slots 
  INTO v_max_slots, v_used_slots
  FROM public.user_bank_account
  WHERE user_id = v_user_id;

  -- Check capacity before depositing
  IF v_used_slots + array_length(p_item_row_ids, 1) > v_max_slots THEN
    RETURN QUERY SELECT false, 
      'Bank capacity exceeded'::text, 
      0::integer, 
      v_used_slots;
    RETURN;
  END IF;

  -- Move each inventory item to bank (with optional quantity constraint)
  FOREACH v_item_row IN ARRAY p_item_row_ids
  LOOP
    -- Get quantity: use p_quantities[v_idx] if available, else get all
    v_quantity := COALESCE(p_quantities[v_idx], NULL);
    
    -- If quantity not specified, move entire stack
    IF v_quantity IS NULL THEN
      INSERT INTO public.bank_items (user_id, item_id, category, slot_position, quantity)
      SELECT v_user_id, inv.item_id, inv.quantity,
        CASE
          WHEN itm.type = 'equipment' THEN 'equipment'
          WHEN itm.type = 'consumable' THEN 'consumable'
          WHEN itm.type = 'special' THEN 'special'
          ELSE 'material'
        END,
        (SELECT COUNT(*) FROM public.bank_items WHERE user_id = v_user_id),
        inv.quantity
      FROM public.inventory inv
      JOIN public.items itm ON inv.item_id = itm.id
      WHERE inv.row_id = v_item_row AND inv.user_id = v_user_id;

      DELETE FROM public.inventory WHERE row_id = v_item_row;
      v_deposit_count := v_deposit_count + 1;
    ELSE
      -- Partial deposit: move only specified quantity
      SELECT quantity INTO v_inv_quantity
      FROM public.inventory
      WHERE row_id = v_item_row AND user_id = v_user_id;

      IF v_inv_quantity IS NOT NULL THEN
        -- Get item details for bank insert
        INSERT INTO public.bank_items (user_id, item_id, category, slot_position, quantity)
        SELECT v_user_id, inv.item_id,
          CASE
            WHEN itm.type = 'equipment' THEN 'equipment'
            WHEN itm.type = 'consumable' THEN 'consumable'
            WHEN itm.type = 'special' THEN 'special'
            ELSE 'material'
          END,
          (SELECT COUNT(*) FROM public.bank_items WHERE user_id = v_user_id),
          LEAST(v_quantity, v_inv_quantity)
        FROM public.inventory inv
        JOIN public.items itm ON inv.item_id = itm.id
        WHERE inv.row_id = v_item_row AND inv.user_id = v_user_id;

        -- Update inventory quantity or delete if none remaining
        UPDATE public.inventory
        SET quantity = quantity - LEAST(v_quantity, v_inv_quantity)
        WHERE row_id = v_item_row;

        -- Delete if quantity now 0
        DELETE FROM public.inventory
        WHERE row_id = v_item_row AND quantity <= 0;

        v_deposit_count := v_deposit_count + 1;
      END IF;
    END IF;

    v_idx := v_idx + 1;
  END LOOP;

  -- Update bank used slots
  UPDATE public.user_bank_account
  SET used_slots = used_slots + v_deposit_count,
      updated_at = now()
  WHERE user_id = v_user_id;

  -- Log transaction
  INSERT INTO public.bank_transactions (user_id, transaction_type, quantity_moved, slots_before, slots_after, success)
  VALUES (v_user_id, 'deposit', v_deposit_count, v_used_slots, v_used_slots + v_deposit_count, true);

  RETURN QUERY SELECT true, 
    'Deposited ' || v_deposit_count || ' item(s)'::text, 
    v_deposit_count::integer, 
    (v_used_slots + v_deposit_count)::integer;
END;
$$;

GRANT EXECUTE ON FUNCTION public.deposit_to_bank(uuid[], integer[]) TO authenticated;
`;

async function deploy() {
  console.log("🚀 Deploying deposit_to_bank RPC with quantity support...\n");

  try {
    const { data, error } = await supabase.rpc("execute_sql", {
      query: sql,
    });

    if (error) {
      console.error("❌ Error:", error.message);
      console.log("\n📋 Try manual deployment:");
      console.log("1. Go to: https://app.supabase.com/projects/znvsyzstmxhqvdkkmgdt/sql/new");
      console.log("2. Copy this SQL:");
      console.log("---");
      console.log(sql);
      console.log("---");
      console.log("3. Run it");
      process.exit(1);
    }

    console.log("✅ RPC deployed successfully!");
    console.log("   deposit_to_bank now supports p_quantities parameter");
    process.exit(0);
  } catch (err) {
    console.error("❌ Deployment failed:", err.message);
    console.log("\n💡 Fallback: Manual SQL deployment needed");
    console.log("1. Go to: https://app.supabase.com/projects/znvsyzstmxhqvdkkmgdt/sql/new");
    console.log("2. Paste the SQL above");
    console.log("3. Click 'Run'");
    process.exit(1);
  }
}

deploy();
