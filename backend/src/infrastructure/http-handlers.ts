/**
 * Infrastructure: HTTP handlers for Express
 */

import type { Request, Response } from 'express';
import { GoogleAuth } from 'google-auth-library';
import { analyzeMeal } from '../application/analyze-meal.js';
import type { VertexAIClient } from './vertex-ai-client.js';
import type { MealRepository, DietRulesRepository } from './firestore-repository.js';
import type { DietRule } from '../domain/diet-rules.js';

export function createHealthHandler() {
  return (_req: Request, res: Response) => {
    res.json({ status: 'ok', service: 'happydiet-backend' });
  };
}

export function createAnalyzeMealHandler(deps: {
  vertexAI: VertexAIClient;
  mealRepo: MealRepository;
  dietRulesRepo: DietRulesRepository;
  apiKey?: string;
}) {
  return async (req: Request, res: Response) => {
    const apiKey = req.headers['x-api-key'] as string | undefined;
    if (deps.apiKey && apiKey !== deps.apiKey) {
      res.status(401).json({ error: 'Invalid or missing API key' });
      return;
    }

    const { image_base64, imageBase64, user_id, userId, diet_text, dietText, diet_rules } = req.body ?? {};
    const imageBase64Value = image_base64 ?? imageBase64;
    const user = user_id ?? userId ?? 'demo';
    const dietTextValue = diet_text ?? dietText;
    const dietRulesValue = diet_rules as DietRule[] | undefined;

    if (!imageBase64Value || typeof imageBase64Value !== 'string') {
      res.status(400).json({
        error: 'Missing image_base64 or imageBase64',
        suggestion: 'Provide base64-encoded image in request body',
      });
      return;
    }

    try {
      const result = await analyzeMeal(
        {
          imageBase64: imageBase64Value,
          userId: user,
          ...(dietRulesValue?.length && { dietRules: dietRulesValue }),
          ...(dietTextValue && { dietText: dietTextValue }),
        },
        {
          vertexAI: deps.vertexAI,
          mealRepo: deps.mealRepo,
          getRules: (uid) => deps.dietRulesRepo.getByUser(uid),
        }
      );

      res.json({
        score: result.score,
        compliantItems: result.compliantItems,
        nonCompliantItems: result.nonCompliantItems,
        uncertainItems: result.uncertainItems,
        suggestions: result.suggestions,
        detalle: result.detalle,
        message: result.message,
        ingredients: result.ingredients,
        estimatedKcal: result.estimatedKcal,
      });
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Unknown error';
      console.error('analyze-meal error:', err);
      res.status(500).json({
        error: 'Could not analyze. Please describe the meal.',
        detail: message,
      });
    }
  };
}

export function createParseDietHandler(deps: {
  vertexAI: VertexAIClient;
  dietRulesRepo: DietRulesRepository;
  apiKey?: string;
}) {
  return async (req: Request, res: Response) => {
    const apiKey = req.headers['x-api-key'] as string | undefined;
    if (deps.apiKey && apiKey !== deps.apiKey) {
      res.status(401).json({ error: 'Invalid or missing API key' });
      return;
    }

    const { diet_text, dietText, image_base64, imageBase64, user_id, userId, save } = req.body ?? {};
    const text = diet_text ?? dietText;
    const imageBase64Value = image_base64 ?? imageBase64;
    const user = user_id ?? userId ?? 'demo';
    const shouldSave = save === true || save === 'true';

    if (!text && !imageBase64Value) {
      res.status(400).json({
        error: 'Missing diet_text, dietText, or image_base64',
        suggestion: 'Provide diet description, e.g. "No sugar, no soda" or an image of diet rules',
      });
      return;
    }

    try {
      const rules = imageBase64Value && typeof imageBase64Value === 'string'
        ? await deps.vertexAI.parseDietImage(imageBase64Value)
        : await deps.vertexAI.parseDietText((text ?? '').trim());
      if (shouldSave && rules.length > 0) {
        await deps.dietRulesRepo.saveRules(user, rules, 'Parsed diet');
      }
      res.json({ rules, saved: shouldSave });
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Unknown error';
      console.error('parse-diet error:', err);
      res.status(500).json({ error: 'Could not parse diet', detail: message });
    }
  };
}

export function createSpeakHandler(ttsClient: { synthesize: (text: string) => Promise<Buffer> }) {
  return async (req: Request, res: Response) => {
    const { text } = req.body ?? {};
    if (!text || typeof text !== 'string') {
      res.status(400).json({ error: 'Missing text' });
      return;
    }
    try {
      const audio = await ttsClient.synthesize(text.trim());
      res.set('Content-Type', 'audio/mpeg');
      res.send(audio);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Unknown error';
      console.error('speak error:', err);
      res.status(500).json({ error: 'TTS failed', detail: message });
    }
  };
}

export function createRulesHandler(dietRulesRepo: DietRulesRepository) {
  return async (req: Request, res: Response) => {
    const userId = (req.query.user_id as string) ?? req.query.userId ?? 'demo';
    try {
      const rules = await dietRulesRepo.getByUser(userId);
      res.json({ rules });
    } catch (err) {
      console.error('get-rules error:', err);
      res.status(500).json({ error: 'Failed to fetch rules' });
    }
  };
}

export function createMealsHandler(mealRepo: MealRepository) {
  return async (req: Request, res: Response) => {
    const userId = (req.query.user_id as string) ?? req.query.userId ?? 'demo';

    try {
      const meals = await mealRepo.listByUser(userId);
      res.json({ meals });
    } catch (err) {
      console.error('get-meals error:', err);
      res.status(500).json({ error: 'Failed to fetch meals' });
    }
  };
}

export function createExplainMealHandler(deps: { vertexAI: VertexAIClient }) {
  return async (req: Request, res: Response) => {
    const { meal_type, prompt, allowed, forbidden } = req.body ?? {};
    const mealType = (meal_type || 'meal').toString();
    const promptStr = (prompt || '').toString().trim();
    const allowedArr = Array.isArray(allowed) ? allowed.filter((x): x is string => typeof x === 'string') : [];
    const forbiddenArr = Array.isArray(forbidden) ? forbidden.filter((x): x is string => typeof x === 'string') : [];
    if (!promptStr) {
      res.status(400).json({ error: 'Missing prompt' });
      return;
    }
    try {
      const explanation = await deps.vertexAI.explainMealConcept(mealType, promptStr, allowedArr, forbiddenArr);
      res.json({ explanation });
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Unknown error';
      console.error('explain-meal error:', err);
      res.status(500).json({ error: 'Could not generate explanation', detail: message });
    }
  };
}

const IMAGEN_MODEL = 'imagen-3.0-generate-002';

export function createGenerateImageHandler(deps: {
  projectId: string;
  location: string;
}) {
  const auth = new GoogleAuth({ scopes: ['https://www.googleapis.com/auth/cloud-platform'] });
  const predictUrl = `https://${deps.location}-aiplatform.googleapis.com/v1/projects/${deps.projectId}/locations/${deps.location}/publishers/google/models/${IMAGEN_MODEL}:predict`;

  return async (req: Request, res: Response) => {
    const { prompt, meal_type } = req.body ?? {};
    const text = (prompt ?? '').trim() || (meal_type ? `A healthy ${meal_type} meal on a white plate, photorealistic, appetizing` : '');
    if (!text) {
      res.status(400).json({ error: 'Missing prompt or meal_type', suggestion: 'Provide prompt or meal_type (e.g. breakfast, lunch, dinner)' });
      return;
    }
    try {
      const token = await auth.getAccessToken();
      if (!token) {
        res.status(503).json({ error: 'GCP auth failed' });
        return;
      }
      const body = {
        instances: [{ prompt: text }],
        parameters: { sampleCount: 1, aspectRatio: '1:1' },
      };
      const resp = await fetch(predictUrl, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(body),
      });
      if (!resp.ok) {
        const errText = await resp.text();
        console.error('[generate-image]', resp.status, errText);
        res.status(resp.status).json({
          error: 'Image generation failed',
          detail: resp.status === 404 ? 'Imagen may not be enabled in this region. Try us-central1.' : errText.slice(0, 200),
        });
        return;
      }
      const data = (await resp.json()) as { predictions?: Array<{ bytesBase64Encoded?: string; mimeType?: string }> };
      const pred = data.predictions?.[0];
      if (!pred?.bytesBase64Encoded) {
        res.status(500).json({ error: 'No image in response' });
        return;
      }
      const mime = pred.mimeType || 'image/png';
      res.set('Content-Type', mime);
      res.send(Buffer.from(pred.bytesBase64Encoded, 'base64'));
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Unknown error';
      console.error('generate-image error:', err);
      res.status(500).json({ error: 'Image generation failed', detail: message });
    }
  };
}
