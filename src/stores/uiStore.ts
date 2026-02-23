// ============================================================
// UI Store — Global UI state, toast notification, modal
// ============================================================

import { create } from "zustand";

export type ToastType = "success" | "error" | "warning" | "info";

export interface Toast {
  id: string;
  message: string;
  type: ToastType;
  duration: number;
}

interface UIState {
  // Navigation
  currentRoute: string;
  previousRoute: string | null;
  isNavigating: boolean;

  // Toast
  toasts: Toast[];

  // Modal
  activeModal: string | null;
  modalData: Record<string, unknown> | null;

  // Loading
  globalLoading: boolean;
  loadingMessage: string | null;

  // Sidebar/Bottom Nav
  isSidebarOpen: boolean;

  // Settings
  settings: {
    musicVolume: number;
    sfxVolume: number;
    notificationsEnabled: boolean;
    autoBattle: boolean;
    language: "tr" | "en";
  };

  // Actions
  navigate: (route: string) => void;
  showToast: (message: string, type?: ToastType, duration?: number) => void;
  addToast: (message: string, type?: ToastType, duration?: number) => void;
  removeToast: (id: string) => void;
  openModal: (modalId: string, data?: Record<string, unknown>) => void;
  closeModal: () => void;
  setGlobalLoading: (loading: boolean, message?: string | null) => void;
  toggleSidebar: () => void;
  updateSettings: (settings: Partial<UIState["settings"]>) => void;
}

let toastCounter = 0;

export const useUIStore = create<UIState>()((set, get) => ({
  currentRoute: "/",
  previousRoute: null,
  isNavigating: false,
  toasts: [],
  activeModal: null,
  modalData: null,
  globalLoading: false,
  loadingMessage: null,
  isSidebarOpen: false,
  settings: {
    musicVolume: 0.8,
    sfxVolume: 1.0,
    notificationsEnabled: true,
    autoBattle: false,
    language: "tr" as const,
  },

  navigate: (route: string) => {
    set((s) => ({
      previousRoute: s.currentRoute,
      currentRoute: route,
      isNavigating: true,
    }));
    // Reset after animation frame
    setTimeout(() => set({ isNavigating: false }), 300);
  },

  showToast: (message: string, type: ToastType = "info", duration = 3000) => {
    const id = `toast-${++toastCounter}`;
    set((s) => ({
      toasts: [...s.toasts, { id, message, type, duration }],
    }));

    // Auto-remove
    setTimeout(() => {
      set((s) => ({
        toasts: s.toasts.filter((t) => t.id !== id),
      }));
    }, duration);
  },

  removeToast: (id: string) => {
    set((s) => ({
      toasts: s.toasts.filter((t) => t.id !== id),
    }));
  },

  // Alias
  addToast: (...args: Parameters<UIState["showToast"]>) => {
    get().showToast(...args);
  },

  openModal: (modalId: string, data?: Record<string, unknown>) => {
    set({ activeModal: modalId, modalData: data || null });
  },

  closeModal: () => {
    set({ activeModal: null, modalData: null });
  },

  setGlobalLoading: (loading: boolean, message: string | null = null) => {
    set({ globalLoading: loading, loadingMessage: message });
  },

  toggleSidebar: () => {
    set((s) => ({ isSidebarOpen: !s.isSidebarOpen }));
  },

  updateSettings: (newSettings) => {
    set((s) => ({
      settings: { ...s.settings, ...newSettings },
    }));
  },
}));

// Alias for convenience (pages use useUiStore)
export const useUiStore = useUIStore;
