import { create } from "zustand";
import { supabase } from "@/lib/supabase";
import type { Mekan, MekanStock, MekanSale, MekanType } from "@/types/mekan";

interface MekanStore {
  mekans: Mekan[];
  myMekan: Mekan | null;
  myStock: MekanStock[];
  mySales: MekanSale[];
  isLoading: boolean;
  error: string | null;

  fetchMekans: () => Promise<void>;
  fetchMyMekan: (userId: string) => Promise<void>;
  openMekan: (type: MekanType, name: string) => Promise<boolean>;
  buyFromMekan: (mekanId: string, itemId: string, quantity: number) => Promise<boolean>;
  useHanItem: (rowId: string) => Promise<{ success: boolean; overdose?: boolean; hospital_minutes?: number }>;
  
  // Owner actions
  updateStock: (itemId: string, quantity: number, price: number) => Promise<boolean>;
  toggleMekanStatus: (isOpen: boolean) => Promise<boolean>;
}

export const useMekanStore = create<MekanStore>((set, get) => ({
  mekans: [],
  myMekan: null,
  myStock: [],
  mySales: [],
  isLoading: false,
  error: null,

  fetchMekans: async () => {
    set({ isLoading: true, error: null });
    try {
      const { data, error } = await supabase
        .from("mekans")
        .select("*")
        .order("fame", { ascending: false });

      if (error) throw error;
      set({ mekans: data as Mekan[] });
    } catch (err: any) {
      console.error("fetchMekans error:", err);
      set({ error: err.message });
    } finally {
      set({ isLoading: false });
    }
  },

  fetchMyMekan: async (userId: string) => {
    if (!userId) return;
    set({ isLoading: true, error: null });
    try {
      // 1. Get mekan
      const { data: mekanData, error: mekanError } = await supabase
        .from("mekans")
        .select("*")
        .eq("owner_id", userId)
        .single();

      if (mekanError && mekanError.code !== "PGRST116") throw mekanError; // PGRST116 is not found

      if (!mekanData) {
        set({ myMekan: null, myStock: [], mySales: [], isLoading: false });
        return;
      }

      const mekanId = mekanData.id;

      // 2. Get stock
      const { data: stockData, error: stockError } = await supabase
        .from("mekan_stock")
        .select("*")
        .eq("mekan_id", mekanId);

      if (stockError) throw stockError;

      // 3. Get recent sales
      const { data: salesData, error: salesError } = await supabase
        .from("mekan_sales")
        .select("*")
        .eq("mekan_id", mekanId)
        .order("created_at", { ascending: false })
        .limit(20);

      if (salesError) throw salesError;

      set({
        myMekan: mekanData as Mekan,
        myStock: stockData as MekanStock[],
        mySales: salesData as MekanSale[],
      });
    } catch (err: any) {
      console.error("fetchMyMekan error:", err);
      set({ error: err.message });
    } finally {
      set({ isLoading: false });
    }
  },

  openMekan: async (type: MekanType, name: string) => {
    set({ isLoading: true, error: null });
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error("Not authenticated");

      const { data, error } = await supabase.rpc("open_mekan", {
        p_user_id: user.id,
        p_mekan_type: type,
        p_name: name,
      });

      if (error) throw error;
      if (!data.success) throw new Error(data.error || "Bilinmeyen hata");

      await get().fetchMyMekan(user.id);
      await get().fetchMekans();
      return true;
    } catch (err: any) {
      console.error("openMekan error:", err);
      set({ error: err.message });
      return false;
    } finally {
      set({ isLoading: false });
    }
  },

  buyFromMekan: async (mekanId: string, itemId: string, quantity: number) => {
    set({ isLoading: true, error: null });
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error("Not authenticated");

      const { data, error } = await supabase.rpc("buy_from_mekan", {
        p_buyer_id: user.id,
        p_mekan_id: mekanId,
        p_item_id: itemId,
        p_quantity: quantity,
      });

      if (error) throw error;
      if (!data.success) throw new Error(data.error || "Satın alma başarısız");

      return true;
    } catch (err: any) {
      console.error("buyFromMekan error:", err);
      set({ error: err.message });
      return false;
    } finally {
      set({ isLoading: false });
    }
  },

  useHanItem: async (rowId: string) => {
    set({ isLoading: true, error: null });
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error("Not authenticated");

      const { data, error } = await supabase.rpc("use_han_item", {
        p_user_id: user.id,
        p_row_id: rowId,
      });

      if (error) throw error;
      if (data.error) throw new Error(data.error);

      return {
        success: data.success,
        overdose: data.overdose,
        hospital_minutes: data.hospital_minutes
      };
    } catch (err: any) {
      console.error("useHanItem error:", err);
      set({ error: err.message });
      return { success: false };
    } finally {
      set({ isLoading: false });
    }
  },

  updateStock: async (itemId: string, quantity: number, price: number) => {
    const { myMekan } = get();
    if (!myMekan) return false;

    set({ isLoading: true, error: null });
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error("Not authenticated");

      const { data, error } = await supabase.rpc("update_mekan_stock", {
        p_owner_id: user.id,
        p_mekan_id: myMekan.id,
        p_item_id: itemId,
        p_new_quantity: quantity,
        p_price: price,
      });

      if (error) throw error;
      if (!data.success) throw new Error(data.error || "Stok güncellenemedi");

      await get().fetchMyMekan(user.id);
      return true;
    } catch (err: any) {
      console.error("updateStock error:", err);
      set({ error: err.message });
      return false;
    } finally {
      set({ isLoading: false });
    }
  },

  toggleMekanStatus: async (isOpen: boolean) => {
    const { myMekan } = get();
    if (!myMekan) return false;

    set({ isLoading: true, error: null });
    try {
      const { error } = await supabase
        .from("mekans")
        .update({ is_open: isOpen })
        .eq("id", myMekan.id);

      if (error) throw error;
      
      const { data: { user } } = await supabase.auth.getUser();
      if (user) await get().fetchMyMekan(user.id);
      
      return true;
    } catch (err: any) {
      console.error("toggleMekanStatus error:", err);
      set({ error: err.message });
      return false;
    } finally {
      set({ isLoading: false });
    }
  }
}));
