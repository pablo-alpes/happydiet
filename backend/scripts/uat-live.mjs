#!/usr/bin/env node
/**
 * HappyDiet — Live UAT script
 * Starts server with in-memory stores + mock Vision, runs full flow, verifies.
 * No GCP required. Run: node scripts/uat-live.mjs
 */

import http from 'http';
import { createApp } from '../dist/src/app.js';

// Minimal valid JPEG base64 (1x1 pixel)
const MINIMAL_JPEG_BASE64 =
  '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAM';

const meals = [];
const mockVertexAI = {
  analyzeImage: async () => ({
    ingredients: ['chicken', 'rice', 'salad', 'soda'],
    estimatedKcal: 500,
  }),
  checkComplianceSemantic: async () => [],
};
const mealRepo = {
  async save(meal) {
    meals.push({ ...meal, id: `meal-${meals.length + 1}` });
  },
  async listByUser(userId) {
    return meals
      .filter((m) => m.userId === userId)
      .sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
  },
};
const dietRulesRepo = {
  async getByUser() {
    return [{ type: 'forbidden', items: ['soda'], reason: 'Avoid' }];
  },
};

const app = createApp({
  vertexAI: mockVertexAI,
  mealRepo,
  dietRulesRepo,
});

const server = http.createServer(app);

function fetch(path, opts = {}) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, 'http://localhost');
    const req = http.request(
      {
        hostname: 'localhost',
        port: server.address().port,
        path: url.pathname + url.search,
        method: opts.method || 'GET',
        headers: { 'Content-Type': 'application/json', ...opts.headers },
      },
      (res) => {
        let body = '';
        res.on('data', (c) => (body += c));
        res.on('end', () => resolve({ status: res.statusCode, body: JSON.parse(body || '{}') }));
      }
    );
    req.on('error', reject);
    if (opts.body) req.write(JSON.stringify(opts.body));
    req.end();
  });
}

async function run() {
  return new Promise((resolve, reject) => {
    server.listen(0, async () => {
      try {
        console.log('=== HappyDiet Live UAT ===\n');

        // 1. Health
        const health = await fetch('/health');
        if (health.status !== 200) throw new Error(`Health: ${health.status}`);
        console.log('1. GET /health: OK');

        // 2. Analyze meal (image → parse → process → advice)
        const analyze = await fetch('/analyze-meal', {
          method: 'POST',
          body: { image_base64: MINIMAL_JPEG_BASE64, user_id: 'uat-user' },
        });
        if (analyze.status !== 200) throw new Error(`Analyze: ${analyze.status} ${JSON.stringify(analyze.body)}`);
        const { score, message, ingredients, compliantItems, nonCompliantItems } = analyze.body;
        if (!message || !Array.isArray(ingredients)) throw new Error('Missing message or ingredients');
        console.log('2. POST /analyze-meal: OK');
        console.log(`   Ingredients: ${ingredients.join(', ')}`);
        console.log(`   Score: ${score}%`);
        console.log(`   Compliant: ${compliantItems.join(', ')}`);
        console.log(`   Non-compliant: ${nonCompliantItems.join(', ')}`);
        console.log(`   Message: ${message.substring(0, 60)}...`);

        // 3. Persistence
        if (meals.length === 0) throw new Error('Meal not persisted');
        console.log('3. Persistence: OK (1 meal saved)');

        // 4. Dashboard (GET /meals)
        const mealsRes = await fetch('/meals?user_id=uat-user');
        if (mealsRes.status !== 200) throw new Error(`Meals: ${mealsRes.status}`);
        if (mealsRes.body.meals.length === 0) throw new Error('Dashboard empty');
        console.log('4. GET /meals (UX): OK');
        console.log(`   Meals in dashboard: ${mealsRes.body.meals.length}`);

        console.log('\n=== UAT passed ===');
        resolve();
      } catch (err) {
        console.error('\nUAT failed:', err.message);
        reject(err);
      } finally {
        server.close();
      }
    });
  });
}

run().catch(() => process.exit(1));
