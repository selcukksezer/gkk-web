// ============================================================
// Request Queue — Kaynak: RequestQueue.gd (131 satır)
// Offline request queue with localStorage persistence
// ============================================================

interface QueuedRequest {
  id: string;
  method: string;
  endpoint: string;
  body?: Record<string, unknown>;
  priority: number;
  retries: number;
  createdAt: string;
}

const STORAGE_KEY = "gkk_request_queue";
const MAX_RETRIES = 3;
const RETRY_DELAY = 2000;

function loadQueue(): QueuedRequest[] {
  if (typeof window === "undefined") return [];
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    return raw ? JSON.parse(raw) : [];
  } catch {
    return [];
  }
}

function saveQueue(queue: QueuedRequest[]): void {
  if (typeof window === "undefined") return;
  localStorage.setItem(STORAGE_KEY, JSON.stringify(queue));
}

let queue: QueuedRequest[] = loadQueue();
let isProcessing = false;

export function enqueue(
  method: string,
  endpoint: string,
  body?: Record<string, unknown>,
  priority = 0
): void {
  const request: QueuedRequest = {
    id: `${Date.now()}-${Math.random().toString(36).slice(2, 7)}`,
    method,
    endpoint,
    body,
    priority,
    retries: 0,
    createdAt: new Date().toISOString(),
  };

  queue.push(request);
  queue.sort((a, b) => b.priority - a.priority);
  saveQueue(queue);

  console.debug("[RequestQueue] Enqueued:", request.id, endpoint);
}

export async function processQueue(): Promise<void> {
  if (isProcessing || queue.length === 0) return;
  if (!navigator.onLine) return;

  isProcessing = true;

  while (queue.length > 0) {
    const request = queue[0];

    try {
      const { api } = await import("./api");
      let res;

      switch (request.method) {
        case "POST":
          res = await api.post(request.endpoint, request.body);
          break;
        case "PUT":
          res = await api.put(request.endpoint, request.body);
          break;
        case "PATCH":
          res = await api.patch(request.endpoint, request.body);
          break;
        case "DELETE":
          res = await api.del(request.endpoint);
          break;
        default:
          res = await api.get(request.endpoint);
      }

      if (res.success) {
        queue.shift();
        saveQueue(queue);
        console.debug("[RequestQueue] Processed:", request.id);
      } else {
        throw new Error(res.error || "Request failed");
      }
    } catch (err) {
      request.retries += 1;

      if (request.retries >= MAX_RETRIES) {
        console.warn("[RequestQueue] Dropping after max retries:", request.id);
        queue.shift();
        saveQueue(queue);
      } else {
        saveQueue(queue);
        await new Promise((r) => setTimeout(r, RETRY_DELAY));
      }
    }
  }

  isProcessing = false;
}

export function clearQueue(): void {
  queue = [];
  saveQueue(queue);
}

export function getQueueSize(): number {
  return queue.length;
}

// Auto-process on online
if (typeof window !== "undefined") {
  window.addEventListener("online", () => {
    console.debug("[RequestQueue] Online — processing queue...");
    processQueue();
  });
}
