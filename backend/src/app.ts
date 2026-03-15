/**
 * Express app factory - used by main.ts and E2E tests
 */

import express from 'express';
import { createVertexAIClient } from './infrastructure/vertex-ai-client.js';
import { createFirestoreRepositories } from './infrastructure/firestore-repository.js';
import {
  createHealthHandler,
  createAnalyzeMealHandler,
  createParseDietHandler,
  createSpeakHandler,
  createMealsHandler,
  createRulesHandler,
  createClearDataHandler,
  createGenerateImageHandler,
  createGeneratedImageHandler,
  createExplainMealHandler,
  createTasksHandler,
  createAddTaskHandler,
  createToggleTaskHandler,
} from './infrastructure/http-handlers.js';
import { createDemoMealsHandler, createDemoRulesHandler, getDemoMeals, getDemoRules } from './infrastructure/demo-handlers.js';
import type { VertexAIClient } from './infrastructure/vertex-ai-client.js';
import type { MealRepository, DietRulesRepository, TasksRepository } from './infrastructure/firestore-repository.js';

export interface AppDeps {
  vertexAI: VertexAIClient | null;
  mealRepo: MealRepository;
  dietRulesRepo: DietRulesRepository;
  tasksRepo?: TasksRepository;
  ttsClient?: { synthesize: (text: string) => Promise<Buffer> } | null;
  apiKey?: string;
  projectId?: string;
  location?: string;
}

export function createApp(deps: AppDeps) {
  const app = express();
  app.use(express.json({ limit: '10mb' }));
  // Catch body parser errors (payload too large, invalid JSON) so we return JSON and log
  app.use((err: unknown, _req: express.Request, res: express.Response, next: express.NextFunction) => {
    if (err && typeof err === 'object' && 'type' in err) {
      const e = err as { type?: string; message?: string; status?: number };
      if (e.type === 'entity.too.large') {
        console.warn('[body-parser] payload too large', e.message);
        res.status(413).json({ error: 'Request body too large', suggestion: 'Reduce image size. Max 10MB.' });
        return;
      }
      if (e.type === 'entity.parse.failed' || (e.message && /JSON|parse/i.test(e.message))) {
        console.warn('[body-parser] invalid JSON', e.message);
        res.status(400).json({ error: 'Invalid JSON body', suggestion: 'Send valid JSON with image_base64.' });
        return;
      }
    }
    next(err);
  });
  app.use(express.static('public'));
  const tasksRepo: TasksRepository = deps.tasksRepo ?? {
    listByUser: async () => [],
    add: async (userId, task, due) => ({ id: '', userId, task, due, done: false }),
    toggleDone: async () => {},
  };

  app.get('/health', createHealthHandler());
  app.post('/parse-diet', (req, res) => {
    if (!deps.vertexAI) {
      res.status(503).json({ error: 'Backend not configured. Set GOOGLE_CLOUD_PROJECT in .env' });
      return;
    }
    createParseDietHandler({
      vertexAI: deps.vertexAI,
      dietRulesRepo: deps.dietRulesRepo,
      apiKey: deps.apiKey,
    })(req, res);
  });
  app.post('/analyze-meal', (req, res) => {
    if (!deps.vertexAI) {
      res.status(503).json({ error: 'Backend not configured. Set GOOGLE_CLOUD_PROJECT in .env' });
      return;
    }
    createAnalyzeMealHandler({
      vertexAI: deps.vertexAI,
      mealRepo: deps.mealRepo,
      dietRulesRepo: deps.dietRulesRepo,
      apiKey: deps.apiKey,
    })(req, res);
  });
  app.get('/meals', createMealsHandler(deps.mealRepo, getDemoMeals));
  app.get('/tasks', createTasksHandler(tasksRepo));
  app.post('/tasks', createAddTaskHandler(tasksRepo));
  app.patch('/tasks/:id', createToggleTaskHandler(tasksRepo));
  app.delete('/meals', createClearDataHandler(deps.mealRepo));
  app.post('/clear-data', createClearDataHandler(deps.mealRepo));
  app.get('/rules', createRulesHandler(deps.dietRulesRepo, getDemoRules));
  app.get('/demo/meals', createDemoMealsHandler());
  app.get('/demo/rules', createDemoRulesHandler());

  app.post('/explain-meal', (req, res) => {
    if (!deps.vertexAI) {
      res.status(503).json({ error: 'Backend not configured' });
      return;
    }
    createExplainMealHandler({ vertexAI: deps.vertexAI })(req, res);
  });
  app.post('/speak', (req, res) => {
    if (!deps.ttsClient) {
      res.status(503).json({ error: 'TTS not configured. Set GOOGLE_CLOUD_PROJECT and enable Text-to-Speech API.' });
      return;
    }
    createSpeakHandler(deps.ttsClient)(req, res);
  });

  if (deps.projectId && deps.location) {
    app.post('/generate-image', createGenerateImageHandler({ projectId: deps.projectId, location: deps.location }));
  }
  app.get('/generated-image/:id', createGeneratedImageHandler());

  return app;
}
