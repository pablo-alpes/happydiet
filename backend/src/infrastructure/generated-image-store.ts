/**
 * In-memory store for generated meal images.
 * Used to avoid sending large base64 payloads over WebSocket (message too long).
 * Images expire after 5 minutes.
 */

const EXPIRY_MS = 5 * 60 * 1000;

interface StoredImage {
  base64: string;
  mimeType: string;
  storedAt: number;
}

const store = new Map<string, StoredImage>();

function pruneExpired() {
  const now = Date.now();
  for (const [id, img] of store.entries()) {
    if (now - img.storedAt > EXPIRY_MS) store.delete(id);
  }
}

export function storeGeneratedImage(base64: string, mimeType: string): string {
  pruneExpired();
  const id = crypto.randomUUID();
  store.set(id, { base64, mimeType, storedAt: Date.now() });
  return id;
}

export function getGeneratedImage(id: string): { base64: string; mimeType: string } | null {
  const img = store.get(id);
  if (!img) return null;
  if (Date.now() - img.storedAt > EXPIRY_MS) {
    store.delete(id);
    return null;
  }
  return { base64: img.base64, mimeType: img.mimeType };
}
