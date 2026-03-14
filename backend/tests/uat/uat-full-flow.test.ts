/**
 * UAT: Full end-to-end flow
 * Simulates: image input → parsing (Vision) → processing (rules) → persistence → advice → UX data
 * Uses in-memory stores to verify persistence and full flow.
 */

import { describe, it, expect, beforeEach } from 'vitest';
import request from 'supertest';
import { createApp } from '../../src/app.js';
import {
  createInMemoryMealRepo,
  createInMemoryDietRulesRepo,
  mockVertexAI,
  MOCK_INGREDIENTS,
  CUSTOM_RULES_FORBID_SODA,
} from './uat-helpers.js';

describe('UAT: Full flow (image → parse → process → persist → advice → UX)', () => {
  let mealRepo: ReturnType<typeof createInMemoryMealRepo>;
  let dietRulesRepo: ReturnType<typeof createInMemoryDietRulesRepo>;
  let app: ReturnType<typeof createApp>;

  beforeEach(() => {
    mealRepo = createInMemoryMealRepo();
    dietRulesRepo = createInMemoryDietRulesRepo(CUSTOM_RULES_FORBID_SODA);
    app = createApp({
      vertexAI: mockVertexAI as any,
      mealRepo: mealRepo as any,
      dietRulesRepo: dietRulesRepo as any,
    });
  });

  it('1. POST image → parsing (Vision) returns ingredients', async () => {
    const res = await request(app)
      .post('/analyze-meal')
      .send({ image_base64: 'fake-meal-image', user_id: 'uat-user' });

    expect(res.status).toBe(200);
    expect(res.body.ingredients).toEqual(MOCK_INGREDIENTS);
    expect(res.body.estimatedKcal).toBe(550);
  });

  it('2. Processing applies rules → soda non-compliant, others compliant', async () => {
    const res = await request(app)
      .post('/analyze-meal')
      .send({ image_base64: 'x', user_id: 'uat-user' });

    expect(res.status).toBe(200);
    expect(res.body.compliantItems).toContain('chicken');
    expect(res.body.compliantItems).toContain('rice');
    expect(res.body.compliantItems).toContain('salad');
    expect(res.body.nonCompliantItems).toContain('soda');
    expect(res.body.score).toBeLessThan(100);
    expect(res.body.suggestions.length).toBeGreaterThan(0);
  });

  it('3. Reporter builds advice message for user', async () => {
    const res = await request(app)
      .post('/analyze-meal')
      .send({ image_base64: 'x', user_id: 'uat-user' });

    expect(res.status).toBe(200);
    expect(res.body.message).toBeDefined();
    expect(typeof res.body.message).toBe('string');
    expect(res.body.message.length).toBeGreaterThan(0);
    expect(res.body.message).toMatch(/compliant|Watch out|soda|Good choices/i);
  });

  it('4. Persistence: meal saved to store', async () => {
    await request(app)
      .post('/analyze-meal')
      .send({ image_base64: 'x', user_id: 'uat-user' });

    const all = mealRepo._getAll();
    expect(all).toHaveLength(1);
    expect(all[0].userId).toBe('uat-user');
    expect(all[0].ingredients).toEqual(MOCK_INGREDIENTS);
    expect(all[0].complianceScore).toBeDefined();
    expect(all[0].compliantItems).toContain('chicken');
    expect(all[0].nonCompliantItems).toContain('soda');
  });

  it('5. GET /meals populates UX (dashboard) with persisted data', async () => {
    await request(app)
      .post('/analyze-meal')
      .send({ image_base64: 'x', user_id: 'uat-user' });

    const res = await request(app).get('/meals?user_id=uat-user');

    expect(res.status).toBe(200);
    expect(res.body.meals).toHaveLength(1);
    const meal = res.body.meals[0];
    expect(meal.userId).toBe('uat-user');
    expect(meal.ingredients).toEqual(MOCK_INGREDIENTS);
    expect(meal.complianceScore).toBeDefined();
    expect(meal.compliantItems).toBeInstanceOf(Array);
    expect(meal.nonCompliantItems).toContain('soda');
  });

  it('6. Full flow: multiple meals persist and list by user', async () => {
    await request(app)
      .post('/analyze-meal')
      .send({ image_base64: 'meal1', user_id: 'user-a' });
    await request(app)
      .post('/analyze-meal')
      .send({ image_base64: 'meal2', user_id: 'user-a' });
    await request(app)
      .post('/analyze-meal')
      .send({ image_base64: 'meal3', user_id: 'user-b' });

    const resA = await request(app).get('/meals?user_id=user-a');
    const resB = await request(app).get('/meals?user_id=user-b');

    expect(resA.body.meals).toHaveLength(2);
    expect(resB.body.meals).toHaveLength(1);
  });

  it('7. Response shape matches UX expectations (score, message, items)', async () => {
    const res = await request(app)
      .post('/analyze-meal')
      .send({ image_base64: 'x', user_id: 'demo' });

    expect(res.body).toMatchObject({
      score: expect.any(Number),
      compliantItems: expect.any(Array),
      nonCompliantItems: expect.any(Array),
      suggestions: expect.any(Array),
      message: expect.any(String),
      ingredients: expect.any(Array),
    });
    if (res.body.estimatedKcal != null) {
      expect(typeof res.body.estimatedKcal).toBe('number');
    }
  });
});
