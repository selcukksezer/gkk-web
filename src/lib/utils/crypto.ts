// ============================================================
// Crypto Utils — Kaynak: CryptoUtils.gd (171 satır)
// SHA-256, device ID, random token
// ============================================================

export async function sha256(message: string): Promise<string> {
  const msgBuffer = new TextEncoder().encode(message);
  const hashBuffer = await crypto.subtle.digest("SHA-256", msgBuffer);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

export function generateDeviceId(): string {
  if (typeof window === "undefined") return "ssr-placeholder";
  let deviceId = localStorage.getItem("gkk_device_id");
  if (!deviceId) {
    deviceId = crypto.randomUUID();
    localStorage.setItem("gkk_device_id", deviceId);
  }
  return deviceId;
}

export function generateRandomToken(length = 32): string {
  const array = new Uint8Array(length);
  crypto.getRandomValues(array);
  return Array.from(array)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export function generateUUID(): string {
  return crypto.randomUUID();
}
