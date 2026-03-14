/**
 * UAT: Error and edge scenarios
 * Regression protection for failure paths and boundary conditions.
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';
import { createApp } from '../../src/app.js';
import {
  createInMemoryMealRepo,
  createInMemoryDietRulesRepo,
  mockVertexAI,
  CUSTOM_RULES_FORBID_SODA,
} from './uat-helpers.js';

describe('UAT: Error and edge scenarios', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('returns 503 when Vertex AI not configured', async () => {
    const app = createApp({
      vertexAI: null,
      mealRepo: createInMemoryMealRepo() as any,
      dietRulesRepo: createInMemoryDietRulesRepo() as any,
    });

    const res = await request(app)
      .post('/analyze-meal')
      .send({ image_base64: 'x', user_id: 'demo' });

    expect(res.status).toBe(503);
    expect(res.body.error).toContain('not configured');
  });

  it('returns 400 when image_base64 missing', async () => {
    const app = createApp({
      vertexAI: mockVertexAI as any,
      mealRepo: createInMemoryMealRepo() as any,
      dietRulesRepo: createInMemoryDietRulesRepo() as any,
    });

    const res = await request(app)
      .post('/analyze-meal')
      .send({ user_id: 'demo' });

    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/image_base64|imageBase64/);
  });

  it('returns 400 when image_base64 is empty string', async () => {
    const app = createApp({
      vertexAI: mockVertexAI as any,
      mealRepo: createInMemoryMealRepo() as any,
      dietRulesRepo: createInMemoryDietRulesRepo() as any,
    });

    const res = await request(app)
      .post('/analyze-meal')
      .send({ image_base64: '', user_id: 'demo' });

    expect(res.status).toBe(400);
  });

  it('uses default rules when diet_rules empty → all compliant', async () => {
    const mockVision = { analyzeImage: vi.fn().mockResolvedValue({ ingredients: ['chicken', 'salad'], estimatedKcal: 300 }), checkComplianceSemantic: vi.fn().mockResolvedValue([]) };
    const app = createApp({
      vertexAI: mockVision as any,
      mealRepo: createInMemoryMealRepo() as any,
      dietRulesRepo: createInMemoryDietRulesRepo([]),
    });

    const res = await request(app)
      .post('/analyze-meal')
      .send({ image_base64: 'x', user_id: 'demo' });

    expect(res.status).toBe(200);
    expect(res.body.score).toBe(100);
    expect(res.body.nonCompliantItems).toHaveLength(0);
  });

  it('returns 500 when Vision throws', async () => {
    const failingVision = { analyzeImage: vi.fn().mockRejectedValue(new Error('Vision API error')), checkComplianceSemantic: vi.fn().mockResolvedValue([]) };
    const app = createApp({
      vertexAI: failingVision as any,
      mealRepo: createInMemoryMealRepo() as any,
      dietRulesRepo: createInMemoryDietRulesRepo(CUSTOM_RULES_FORBID_SODA),
    });

    const res = await request(app)
      .post('/analyze-meal')
      .send({ image_base64: 'x', user_id: 'demo' });

    expect(res.status).toBe(500);
    expect(res.body.error).toBeDefined();
  });

  it('GET /meals returns empty array when no meals', async () => {
    const app = createApp({
      vertexAI: null,
      mealRepo: createInMemoryMealRepo() as any,
      dietRulesRepo: createInMemoryDietRulesRepo() as any,
    });

    const res = await request(app).get('/meals?user_id=new-user');

    expect(res.status).toBe(200);
    expect(res.body.meals).toEqual([]);
  });
});
