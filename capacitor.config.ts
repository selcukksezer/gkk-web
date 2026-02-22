// ============================================================
// Capacitor Configuration — Gölge Krallık Mobil App
// ============================================================

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type CapacitorConfig = any;

const config: CapacitorConfig = {
  appId: "com.selcukksezer.golgekrallik",
  appName: "Gölge Krallık",
  webDir: "out",
  server: {
    androidScheme: "https",
  },
  plugins: {
    SplashScreen: {
      launchShowDuration: 2000,
      backgroundColor: "#0f0f14",
      showSpinner: false,
      androidScaleType: "CENTER_CROP",
    },
    StatusBar: {
      style: "DARK",
      backgroundColor: "#0f0f14",
    },
    Keyboard: {
      resize: "body",
      resizeOnFullScreen: true,
    },
    PushNotifications: {
      presentationOptions: ["badge", "sound", "alert"],
    },
  },
  android: {
    backgroundColor: "#0f0f14",
    allowMixedContent: true,
  },
  ios: {
    backgroundColor: "#0f0f14",
    contentInset: "automatic",
    preferredContentMode: "mobile",
  },
};

export default config;
