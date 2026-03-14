/**
 * Dev server: runs backend with mock Vertex AI + in-memory stores
 * No GCP required. Full interactive simulation.
 * Run: npm run dev:demo
 */

import express from 'express';
import { createApp } from './app.js';

const meals: Array<Record<string, unknown>> = [];

const mockVertexAI = {
  analyzeImage: async () => ({
    ingredients: ['chicken', 'rice', 'salad', 'soda'],
    estimatedKcal: 520,
  }),
  parseDietText: async (text: string) => {
    const lower = text.toLowerCase();
    const forbidden: string[] = [];
    if (lower.includes('sugar') || lower.includes('soda')) forbidden.push('soda', 'sugar');
    if (lower.includes('bread')) forbidden.push('bread');
    if (lower.includes('pizza')) forbidden.push('pizza');
    if (forbidden.length === 0) forbidden.push('soda');
    return [{ type: 'forbidden' as const, items: forbidden, reason: 'From diet' }];
  },
  parseDietImage: async () => [
    { type: 'forbidden' as const, items: ['soda', 'sugar', 'bread'], reason: 'From diet image' },
  ],
};

const mealRepo = {
  async save(meal: Record<string, unknown>) {
    meals.push({ ...meal, id: `meal-${meals.length + 1}` });
  },
  async listByUser(userId: string) {
    return meals
      .filter((m) => m.userId === userId)
      .sort((a, b) => new Date(b.timestamp as string).getTime() - new Date(a.timestamp as string).getTime());
  },
};

const dietRulesRepo = {
  async getByUser() {
    return [{ type: 'forbidden' as const, items: ['soda'], reason: 'Avoid sugary drinks' }];
  },
  async saveRules() {},
};

const app = createApp({
  vertexAI: mockVertexAI as any,
  mealRepo: mealRepo as any,
  dietRulesRepo: dietRulesRepo as any,
});

const PORT = parseInt(process.env.PORT ?? '8081', 10);

app.listen(PORT, '0.0.0.0', () => {
  console.log(`HappyDiet dev server at http://localhost:${PORT}`);
  console.log(`  → Dev playground: http://localhost:${PORT}/dev.html`);
  console.log(`  → Test page:      http://localhost:${PORT}/test.html`);
  console.log('  (Mock Vision + in-memory store — no GCP required)');
});
