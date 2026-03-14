/**
 * UAT: API contract — response shape for UX consumers
 * Ensures iOS app and Live API can rely on stable response structure.
 */

import { describe, it, expect, beforeEach } from 'vitest';
import request from 'supertest';
import { createApp } from '../../src/app.js';
import {
  createInMemoryMealRepo,
  createInMemoryDietRulesRepo,
  mockVertexAI,
  CUSTOM_RULES_FORBID_SODA,
} from './uat-helpers.js';

describe('UAT: API contract (UX response shape)', () => {
  const app = createApp({
    vertexAI: mockVertexAI as any,
    mealRepo: createInMemoryMealRepo() as any,
    dietRulesRepo: createInMemoryDietRulesRepo(CUSTOM_RULES_FORBID_SODA),
  });

  it('POST /analyze-meal response has all required fields for UX', async () => {
    const res = await request(app)
      .post('/analyze-meal')
      .send({ image_base64: 'x', user_id: 'demo' });

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('score');
    expect(res.body).toHaveProperty('compliantItems');
    expect(res.body).toHaveProperty('nonCompliantItems');
    expect(res.body).toHaveProperty('suggestions');
    expect(res.body).toHaveProperty('message');
    expect(res.body).toHaveProperty('ingredients');

    expect(typeof res.body.score).toBe('number');
    expect(Array.isArray(res.body.compliantItems)).toBe(true);
    expect(Array.isArray(res.body.nonCompliantItems)).toBe(true);
    expect(Array.isArray(res.body.suggestions)).toBe(true);
    expect(typeof res.body.message).toBe('string');
    expect(Array.isArray(res.body.ingredients)).toBe(true);
  });

  it('GET /meals response has meals array', async () => {
    const res = await request(app).get('/meals?user_id=demo');

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('meals');
    expect(Array.isArray(res.body.meals)).toBe(true);
  });

  it('meal record in GET /meals has fields for dashboard display', async () => {
    await request(app)
      .post('/analyze-meal')
      .send({ image_base64: 'x', user_id: 'contract-user' });

    const res = await request(app).get('/meals?user_id=contract-user');
    const meal = res.body.meals[0];

    expect(meal).toHaveProperty('id');
    expect(meal).toHaveProperty('userId');
    expect(meal).toHaveProperty('ingredients');
    expect(meal).toHaveProperty('complianceScore');
    expect(meal).toHaveProperty('compliantItems');
    expect(meal).toHaveProperty('nonCompliantItems');
    expect(meal).toHaveProperty('suggestions');
  });
});
