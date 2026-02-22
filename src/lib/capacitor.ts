// ============================================================
// Capacitor Helpers — Kaynak: Plan Dosya 107
// Native plugin wrappers (haptics, status bar, keyboard)
// ============================================================

export function isNative(): boolean {
  try {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const { Capacitor } = require("@capacitor/core");
    return Capacitor.isNativePlatform();
  } catch {
    return false;
  }
}

export function getPlatform(): "web" | "ios" | "android" {
  try {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const { Capacitor } = require("@capacitor/core");
    return Capacitor.getPlatform() as "web" | "ios" | "android";
  } catch {
    return "web";
  }
}

export async function hapticFeedback(
  style: "light" | "medium" | "heavy" = "light"
): Promise<void> {
  if (!isNative()) return;
  try {
    // @ts-expect-error — optional Capacitor plugin
    const { Haptics, ImpactStyle } = await import("@capacitor/haptics");
    const styleMap = {
      light: ImpactStyle.Light,
      medium: ImpactStyle.Medium,
      heavy: ImpactStyle.Heavy,
    };
    await Haptics.impact({ style: styleMap[style] });
  } catch {
    // Haptics not available
  }
}

export async function setStatusBarDark(): Promise<void> {
  if (!isNative()) return;
  try {
    // @ts-expect-error — optional Capacitor plugin
    const { StatusBar, Style } = await import("@capacitor/status-bar");
    await StatusBar.setStyle({ style: Style.Dark });
    await StatusBar.setBackgroundColor({ color: "#1a1a2e" });
  } catch {
    // StatusBar not available
  }
}

export async function hideKeyboard(): Promise<void> {
  if (!isNative()) return;
  try {
    // @ts-expect-error — optional Capacitor plugin
    const { Keyboard } = await import("@capacitor/keyboard");
    await Keyboard.hide();
  } catch {
    // Keyboard not available
  }
}
