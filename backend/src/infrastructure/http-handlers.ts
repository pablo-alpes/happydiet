/**
 * Infrastructure: HTTP handlers for Express
 */

import type { Request, Response } from 'express';
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

    const rawBase64 = imageBase64Value.replace(/^data:image\/\w+;base64,/, '');
    if (rawBase64.length < 100) {
      res.status(400).json({
        error: 'Image data too short',
        detail: 'Base64 payload is too small to be a valid image. Re-upload or capture again.',
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
      const message = err instanceof Error ? err.message : String(err);
      const code = err && typeof err === 'object' && 'code' in err ? String((err as { code: unknown }).code) : '';
      const fullDetail = [message, code].filter(Boolean).join(' ') || JSON.stringify(err);
      console.error('analyze-meal error:', err);
      const lower = (message + ' ' + code).toLowerCase();
      let hint = 'Could not analyze. Please describe the meal.';
      if (lower.includes('429') || lower.includes('resource_exhausted') || lower.includes('quota')) {
        hint = 'Quota exceeded (429). Try again later or check Vertex AI quotas in GCP.';
      } else if (lower.includes('403') || lower.includes('permission') || lower.includes('not found')) {
        hint = 'Permission or project error. Check GOOGLE_CLOUD_PROJECT and Vertex AI API is enabled.';
      } else if (lower.includes('401') || lower.includes('unauthenticated')) {
        hint = 'Authentication failed. Check service account or gcloud auth application-default login.';
      } else if (lower.includes('503') || lower.includes('unavailable')) {
        hint = 'Vertex AI temporarily unavailable. Try again in a moment.';
      } else if (lower.includes('no response') || lower.includes('vision failed')) {
        hint = 'Vision returned no result. Try a clearer meal photo.';
      } else if (message && message.length < 200) {
        hint = `Could not analyze: ${message}`;
      }
      res.status(500).json({
        error: hint,
        detail: fullDetail,
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
      const trimmed = text.trim();
      const limited = trimmed.length > 5000 ? trimmed.slice(0, 5000) : trimmed;
      const audio = await ttsClient.synthesize(limited);
      res.writeHead(200, {
        'Content-Type': 'audio/mpeg',
        'Content-Length': String(audio.length),
      });
      res.end(audio);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Unknown error';
      console.error('speak error:', err);
      res.status(500).json({ error: 'TTS failed', detail: message });
    }
  };
}

export function createRulesHandler(
  dietRulesRepo: DietRulesRepository,
  getDemoRules: () => Array<Record<string, unknown>>
) {
  return async (req: Request, res: Response) => {
    const userId = (req.query.user_id as string) ?? req.query.userId ?? 'demo';
    try {
      const rules = await dietRulesRepo.getByUser(userId);
      res.json({ rules });
    } catch (err) {
      console.error('get-rules error:', err);
      if (userId === 'demo') {
        res.json({ rules: getDemoRules() });
        return;
      }
      res.status(500).json({ error: 'Failed to fetch rules' });
    }
  };
}

export function createMealsHandler(
  mealRepo: MealRepository,
  getDemoMeals: () => Array<Record<string, unknown>>
) {
  return async (req: Request, res: Response) => {
    const userId = (req.query.user_id as string) ?? req.query.userId ?? 'demo';

    try {
      const meals = await mealRepo.listByUser(userId);
      if (meals.length === 0 && userId === 'demo') {
        res.json({ meals: getDemoMeals() });
        return;
      }
      res.json({ meals });
    } catch (err) {
      console.error('get-meals error:', err);
      if (userId === 'demo') {
        res.json({ meals: getDemoMeals() });
        return;
      }
      res.status(500).json({ error: 'Failed to fetch meals' });
    }
  };
}

export function createClearDataHandler(mealRepo: MealRepository) {
  return async (req: Request, res: Response) => {
    const { user_id, userId } = (req.body ?? req.query) as { user_id?: string; userId?: string };
    const user = user_id ?? userId ?? 'demo';

    try {
      const count = await mealRepo.deleteAllByUser(user);
      res.json({ cleared: count, message: `Deleted ${count} meal(s) for user ${user}` });
    } catch (err) {
      console.error('clear-data error:', err);
      res.status(500).json({ error: 'Failed to clear data' });
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

import { generateMealImage } from './generate-meal-image.js';
import { getGeneratedImage } from './generated-image-store.js';
import type { TasksRepository } from './firestore-repository.js';

export function createTasksHandler(tasksRepo: TasksRepository) {
  return async (req: Request, res: Response) => {
    const userId = (req.query.user_id as string) ?? req.query.userId ?? 'demo';
    try {
      const tasks = await tasksRepo.listByUser(userId);
      res.json({ tasks });
    } catch (err) {
      console.error('get-tasks error:', err);
      res.status(500).json({ error: 'Failed to fetch tasks' });
    }
  };
}

export function createAddTaskHandler(tasksRepo: TasksRepository) {
  return async (req: Request, res: Response) => {
    const { task, due, user_id, userId } = req.body ?? {};
    const user = user_id ?? userId ?? 'demo';
    const taskStr = (task ?? '').toString().trim();
    if (!taskStr) {
      res.status(400).json({ error: 'Missing task' });
      return;
    }
    try {
      const added = await tasksRepo.add(user, taskStr, (due ?? '').toString().trim());
      res.status(201).json(added);
    } catch (err) {
      console.error('add-task error:', err);
      res.status(500).json({ error: 'Failed to add task' });
    }
  };
}

export function createToggleTaskHandler(tasksRepo: TasksRepository) {
  return async (req: Request, res: Response) => {
    const taskId = req.params.id as string;
    const userId = (req.query.user_id as string) ?? req.query.userId ?? 'demo';
    if (!taskId) {
      res.status(400).json({ error: 'Missing task id' });
      return;
    }
    try {
      await tasksRepo.toggleDone(userId, taskId);
      res.json({ ok: true });
    } catch (err) {
      console.error('toggle-task error:', err);
      res.status(500).json({ error: 'Failed to toggle task' });
    }
  };
}

export function createGeneratedImageHandler() {
  return (req: Request, res: Response) => {
    const id = req.params.id as string;
    if (!id) {
      res.status(400).send('Missing image id');
      return;
    }
    const img = getGeneratedImage(id);
    if (!img) {
      res.status(404).send('Image not found or expired');
      return;
    }
    res.set('Content-Type', img.mimeType || 'image/png');
    res.send(Buffer.from(img.base64, 'base64'));
  };
}

export function createGenerateImageHandler(deps: {
  projectId: string;
  location: string;
}) {
  return async (req: Request, res: Response) => {
    const { prompt, meal_type } = req.body ?? {};
    const result = await generateMealImage({
      projectId: deps.projectId,
      location: deps.location,
      prompt: (prompt ?? '').trim() || undefined,
      mealType: meal_type,
    });
    if ('error' in result) {
      const status = result.error.includes('auth') || result.error.includes('GCP') ? 503 : 500;
      res.status(status).json({ error: result.error, suggestion: 'Provide prompt or meal_type (e.g. breakfast, lunch, dinner)' });
      return;
    }
    const mime = result.mimeType || 'image/png';
    res.set('Content-Type', mime);
    res.send(Buffer.from(result.imageBase64, 'base64'));
  };
}
