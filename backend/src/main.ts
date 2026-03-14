/**
 * HappyDiet Backend - Entry point
 * Tool endpoints for Live API: analyze_meal, meals
 */

import { config } from 'dotenv';
import { resolve } from 'path';
config({ path: resolve(process.cwd(), '.env') });
config({ path: resolve(process.cwd(), '../.env') });
import { createVertexAIClient } from './infrastructure/vertex-ai-client.js';
import { createFirestoreRepositories } from './infrastructure/firestore-repository.js';
import { createGoogleTTSClient } from './infrastructure/google-tts.js';
import { createApp } from './app.js';
import WebSocket from 'ws';
import { attachLiveProxy } from './infrastructure/live-api-proxy.js';

const PORT = parseInt(process.env.PORT ?? '8080', 10);
const PROJECT_ID = process.env.GOOGLE_CLOUD_PROJECT ?? '';
const LOCATION = process.env.GOOGLE_CLOUD_LOCATION ?? 'us-central1';
const FIRESTORE_DATABASE_MEALS = process.env.FIRESTORE_DATABASE_MEALS ?? process.env.FIRESTORE_DATABASE_ID;
const FIRESTORE_DATABASE_RULES = process.env.FIRESTORE_DATABASE_RULES;
const VERTEX_AI_MODEL = process.env.VERTEX_AI_MODEL ?? 'gemini-2.5-flash';
const API_KEY = process.env.API_KEY;

const hasGcp = !!PROJECT_ID;
if (!hasGcp) {
  console.warn('Missing GOOGLE_CLOUD_PROJECT — /health works, /analyze-meal and /meals will return 503');
}

const vertexAI = hasGcp
  ? createVertexAIClient({ projectId: PROJECT_ID, location: LOCATION, model: VERTEX_AI_MODEL })
  : null;
const repos = hasGcp
  ? createFirestoreRepositories({
      projectId: PROJECT_ID,
      ...(FIRESTORE_DATABASE_MEALS && { mealsDatabaseId: FIRESTORE_DATABASE_MEALS }),
      ...(FIRESTORE_DATABASE_RULES && { rulesDatabaseId: FIRESTORE_DATABASE_RULES }),
    })
  : null;
const mealRepo = repos?.mealRepo ?? {
  save: async () => {},
  listByUser: async () => [],
  getDailyKcal: async () => 0,
  deleteAllByUser: async () => 0,
};
const dietRulesRepo = repos?.dietRulesRepo ?? {
  getByUser: async () => [],
  saveRules: async () => {},
};
const tasksRepo = repos?.tasksRepo ?? {
  listByUser: async () => [],
  add: async (userId, task, due) => ({ id: '', userId, task, due, done: false }),
  toggleDone: async () => {},
};
const ttsClient = hasGcp ? createGoogleTTSClient({ projectId: PROJECT_ID }) : null;

const app = createApp({
  vertexAI,
  mealRepo,
  dietRulesRepo,
  tasksRepo,
  ttsClient,
  apiKey: API_KEY,
  projectId: PROJECT_ID || undefined,
  location: LOCATION,
});

const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`HappyDiet backend listening on port ${PORT} (0.0.0.0)`);
});

if (PROJECT_ID && vertexAI) {
  attachLiveProxy(server, {
    projectId: PROJECT_ID,
    location: LOCATION,
    vertexAI,
    mealRepo,
    dietRulesRepo,
  });
  console.log('Live API WebSocket proxy at ws://host/live');
} else {
  const wssFallback = new WebSocket.Server({ server, path: '/live' });
  wssFallback.on('connection', (ws) => {
    ws.send(JSON.stringify({ type: 'error', message: 'Live coach requires GOOGLE_CLOUD_PROJECT. Add it to backend/.env and restart the server.' }));
    ws.close();
  });
  console.log('Live API: /live returns error (set GOOGLE_CLOUD_PROJECT for full coach)');
}
