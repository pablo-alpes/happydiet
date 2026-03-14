/**
 * Generate meal images via Vertex AI Imagen.
 * Used by HTTP handler and Live API proxy.
 */

import { GoogleAuth } from 'google-auth-library';

const IMAGEN_MODEL = 'imagen-3.0-generate-002';

export async function generateMealImage(
  params: { projectId: string; location: string; prompt?: string; mealType?: string }
): Promise<{ imageBase64: string; mimeType: string } | { error: string }> {
  const { projectId, location, prompt, mealType } = params;
  const text = (prompt ?? '').trim() || (mealType ? `A healthy ${mealType} meal on a white plate, photorealistic, appetizing` : '');
  if (!text) {
    return { error: 'Missing prompt or meal_type' };
  }
  try {
    const auth = new GoogleAuth({ scopes: ['https://www.googleapis.com/auth/cloud-platform'] });
    const token = await auth.getAccessToken();
    if (!token) return { error: 'GCP auth failed' };

    const predictUrl = `https://${location}-aiplatform.googleapis.com/v1/projects/${projectId}/locations/${location}/publishers/google/models/${IMAGEN_MODEL}:predict`;
    const body = {
      instances: [{ prompt: text }],
      parameters: { sampleCount: 1, aspectRatio: '1:1' },
    };
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 90000);
    const resp = await fetch(predictUrl, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
      signal: controller.signal,
    });
    clearTimeout(timeout);
    if (!resp.ok) {
      const errText = await resp.text();
      console.error('[generate-meal-image]', resp.status, errText);
      return { error: resp.status === 404 ? 'Imagen may not be enabled. Try us-central1.' : errText.slice(0, 200) };
    }
    const data = (await resp.json()) as { predictions?: Array<{ bytesBase64Encoded?: string; mimeType?: string }> };
    const pred = data.predictions?.[0];
    if (!pred?.bytesBase64Encoded) {
      return { error: 'No image in response' };
    }
    return {
      imageBase64: pred.bytesBase64Encoded,
      mimeType: pred.mimeType || 'image/png',
    };
  } catch (err) {
    const msg = err instanceof Error ? err.message : 'Unknown error';
    console.error('[generate-meal-image]', err);
    return { error: msg };
  }
}
