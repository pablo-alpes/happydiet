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
  createGenerateImageHandler,
  createExplainMealHandler,
} from './infrastructure/http-handlers.js';
import { createDemoMealsHandler, createDemoRulesHandler } from './infrastructure/demo-handlers.js';
import type { VertexAIClient } from './infrastructure/vertex-ai-client.js';
import type { MealRepository, DietRulesRepository } from './infrastructure/firestore-repository.js';

export interface AppDeps {
  vertexAI: VertexAIClient | null;
  mealRepo: MealRepository;
  dietRulesRepo: DietRulesRepository;
  ttsClient?: { synthesize: (text: string) => Promise<Buffer> } | null;
  apiKey?: string;
  projectId?: string;
  location?: string;
}

export function createApp(deps: AppDeps) {
  const app = express();
  app.use(express.json({ limit: '10mb' }));
  app.use(express.static('public'));

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
  app.get('/meals', createMealsHandler(deps.mealRepo));
  app.get('/rules', createRulesHandler(deps.dietRulesRepo));
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

  return app;
}
