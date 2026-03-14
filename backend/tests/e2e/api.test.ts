/**
 * E2E tests: HTTP API (health, analyze-meal, meals)
 * Uses supertest - no server listen required
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';
import { createApp } from '../../src/app.js';

const mockVertexAI = {
  analyzeImage: vi.fn().mockResolvedValue({
    ingredients: ['chicken', 'rice'],
    estimatedKcal: 400,
  }),
  parseDietText: vi.fn().mockResolvedValue([
    { type: 'forbidden' as const, items: ['soda'], reason: 'Avoid' },
  ]),
  parseDietImage: vi.fn().mockResolvedValue([
    { type: 'forbidden' as const, items: ['soda', 'bread'], reason: 'From image' },
  ]),
  checkComplianceSemantic: vi.fn().mockResolvedValue([]),
};

const mockMealRepo = {
  save: vi.fn().mockResolvedValue(undefined),
  listByUser: vi.fn().mockResolvedValue([]),
};

const mockDietRulesRepo = {
  getByUser: vi.fn().mockResolvedValue([]),
  saveRules: vi.fn().mockResolvedValue(undefined),
};

describe('E2E API', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('GET /health', () => {
    it('returns 200 and status ok', async () => {
      const app = createApp({
        vertexAI: null,
        mealRepo: mockMealRepo as any,
        dietRulesRepo: mockDietRulesRepo as any,
      });

      const res = await request(app).get('/health');

      expect(res.status).toBe(200);
      expect(res.body).toEqual({ status: 'ok', service: 'happydiet-backend' });
    });
  });

  describe('POST /analyze-meal', () => {
    it('returns 503 when vertexAI not configured', async () => {
      const app = createApp({
        vertexAI: null,
        mealRepo: mockMealRepo as any,
        dietRulesRepo: mockDietRulesRepo as any,
      });

      const res = await request(app)
        .post('/analyze-meal')
        .send({ image_base64: 'fake', user_id: 'demo' });

      expect(res.status).toBe(503);
      expect(res.body.error).toContain('not configured');
    });

    it('returns 400 when image_base64 missing', async () => {
      const app = createApp({
        vertexAI: mockVertexAI as any,
        mealRepo: mockMealRepo as any,
        dietRulesRepo: mockDietRulesRepo as any,
      });

      const res = await request(app)
        .post('/analyze-meal')
        .send({ user_id: 'demo' });

      expect(res.status).toBe(400);
      expect(res.body.error).toContain('image_base64');
    });

    it('returns 200 with compliance when image provided', async () => {
      const app = createApp({
        vertexAI: mockVertexAI as any,
        mealRepo: mockMealRepo as any,
        dietRulesRepo: mockDietRulesRepo as any,
      });

      const res = await request(app)
        .post('/analyze-meal')
        .send({ image_base64: 'fake-base64', user_id: 'demo' });

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('score');
      expect(res.body).toHaveProperty('compliantItems');
      expect(res.body).toHaveProperty('nonCompliantItems');
      expect(res.body).toHaveProperty('suggestions');
      expect(mockMealRepo.save).toHaveBeenCalled();
    });
  });

  describe('GET /meals', () => {
    it('returns 200 with meals array', async () => {
      mockMealRepo.listByUser.mockResolvedValueOnce([
        { id: '1', userId: 'demo', complianceScore: 100, ingredients: ['salad'] },
      ]);

      const app = createApp({
        vertexAI: null,
        mealRepo: mockMealRepo as any,
        dietRulesRepo: mockDietRulesRepo as any,
      });

      const res = await request(app).get('/meals?user_id=demo');

      expect(res.status).toBe(200);
      expect(res.body.meals).toHaveLength(1);
      expect(res.body.meals[0].complianceScore).toBe(100);
    });

    it('uses userId from query when provided', async () => {
      mockMealRepo.listByUser.mockResolvedValueOnce([]);

      const app = createApp({
        vertexAI: null,
        mealRepo: mockMealRepo as any,
        dietRulesRepo: mockDietRulesRepo as any,
      });

      await request(app).get('/meals?userId=user123');

      expect(mockMealRepo.listByUser).toHaveBeenCalledWith('user123');
    });

    it('returns 500 when mealRepo throws', async () => {
      mockMealRepo.listByUser.mockRejectedValueOnce(new Error('DB error'));

      const app = createApp({
        vertexAI: null,
        mealRepo: mockMealRepo as any,
        dietRulesRepo: mockDietRulesRepo as any,
      });

      const res = await request(app).get('/meals?user_id=user123');

      expect(res.status).toBe(500);
      expect(res.body.error).toContain('Failed to fetch');
    });
  });

  describe('GET /rules', () => {
    it('returns 200 with rules from dietRulesRepo', async () => {
      const rules = [{ type: 'forbidden' as const, items: ['sugar', 'soda'] }];
      mockDietRulesRepo.getByUser.mockResolvedValue(rules);

      const app = createApp({
        vertexAI: null,
        mealRepo: mockMealRepo as any,
        dietRulesRepo: mockDietRulesRepo as any,
      });

      const res = await request(app).get('/rules?user_id=demo');

      expect(res.status).toBe(200);
      expect(res.body.rules).toEqual(rules);
      expect(mockDietRulesRepo.getByUser).toHaveBeenCalledWith('demo');
    });

    it('returns empty array when no rules', async () => {
      mockDietRulesRepo.getByUser.mockResolvedValue([]);

      const app = createApp({
        vertexAI: null,
        mealRepo: mockMealRepo as any,
        dietRulesRepo: mockDietRulesRepo as any,
      });

      const res = await request(app).get('/rules');

      expect(res.status).toBe(200);
      expect(res.body.rules).toEqual([]);
    });
  });

  describe('POST /parse-diet', () => {
    it('returns 503 when vertexAI not configured', async () => {
      const app = createApp({
        vertexAI: null,
        mealRepo: mockMealRepo as any,
        dietRulesRepo: mockDietRulesRepo as any,
      });

      const res = await request(app)
        .post('/parse-diet')
        .send({ diet_text: 'No sugar, no soda' });

      expect(res.status).toBe(503);
    });

    it('returns 400 when diet_text missing', async () => {
      const app = createApp({
        vertexAI: mockVertexAI as any,
        mealRepo: mockMealRepo as any,
        dietRulesRepo: mockDietRulesRepo as any,
      });

      const res = await request(app).post('/parse-diet').send({});

      expect(res.status).toBe(400);
      expect(res.body.error).toContain('diet_text');
    });

    it('returns 200 with parsed rules', async () => {
      const app = createApp({
        vertexAI: mockVertexAI as any,
        mealRepo: mockMealRepo as any,
        dietRulesRepo: mockDietRulesRepo as any,
      });

      const res = await request(app)
        .post('/parse-diet')
        .send({ diet_text: 'No sugar, no soda' });

      expect(res.status).toBe(200);
      expect(res.body.rules).toBeInstanceOf(Array);
      expect(res.body.rules.length).toBeGreaterThan(0);
      expect(res.body.rules[0].type).toBe('forbidden');
    });

    it('saves rules when save=true', async () => {
      const app = createApp({
        vertexAI: mockVertexAI as any,
        mealRepo: mockMealRepo as any,
        dietRulesRepo: mockDietRulesRepo as any,
      });

      const res = await request(app)
        .post('/parse-diet')
        .send({ diet_text: 'No soda', save: true, user_id: 'demo' });

      expect(res.status).toBe(200);
      expect(res.body.saved).toBe(true);
      expect(mockDietRulesRepo.saveRules).toHaveBeenCalledWith('demo', expect.any(Array), 'Parsed diet');
    });

    it('parses diet from image when image_base64 provided', async () => {
      const app = createApp({
        vertexAI: mockVertexAI as any,
        mealRepo: mockMealRepo as any,
        dietRulesRepo: mockDietRulesRepo as any,
      });

      const res = await request(app)
        .post('/parse-diet')
        .send({ image_base64: 'fake-base64-image' });

      expect(res.status).toBe(200);
      expect(res.body.rules).toBeInstanceOf(Array);
      expect(mockVertexAI.parseDietImage).toHaveBeenCalledWith('fake-base64-image');
      expect(mockVertexAI.parseDietText).not.toHaveBeenCalled();
    });
  });

  describe('POST /analyze-meal with diet rules', () => {
    it('returns <100% compliance when diet_rules forbid ingredients', async () => {
      const app = createApp({
        vertexAI: mockVertexAI as any,
        mealRepo: mockMealRepo as any,
        dietRulesRepo: mockDietRulesRepo as any,
      });

      const res = await request(app)
        .post('/analyze-meal')
        .send({
          image_base64: 'fake',
          user_id: 'demo',
          diet_rules: [{ type: 'forbidden', items: ['rice'], reason: 'Avoid' }],
        });

      expect(res.status).toBe(200);
      expect(res.body.score).toBeLessThan(100);
      expect(res.body.nonCompliantItems).toContain('rice');
    });
  });

  describe('POST /analyze-meal body variants', () => {
    it('accepts imageBase64 (camelCase)', async () => {
      const app = createApp({
        vertexAI: mockVertexAI as any,
        mealRepo: mockMealRepo as any,
        dietRulesRepo: mockDietRulesRepo as any,
      });

      const res = await request(app)
        .post('/analyze-meal')
        .send({ imageBase64: 'fake', userId: 'demo' });

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('score');
    });

    it('returns message in response', async () => {
      const app = createApp({
        vertexAI: mockVertexAI as any,
        mealRepo: mockMealRepo as any,
        dietRulesRepo: mockDietRulesRepo as any,
      });

      const res = await request(app)
        .post('/analyze-meal')
        .send({ image_base64: 'fake', user_id: 'demo' });

      expect(res.status).toBe(200);
      expect(res.body.message).toBeDefined();
      expect(typeof res.body.message).toBe('string');
    });
  });

  describe('API key auth', () => {
    it('returns 401 when API key required and missing', async () => {
      const app = createApp({
        vertexAI: mockVertexAI as any,
        mealRepo: mockMealRepo as any,
        dietRulesRepo: mockDietRulesRepo as any,
        apiKey: 'secret-key',
      });

      const res = await request(app)
        .post('/analyze-meal')
        .send({ image_base64: 'fake', user_id: 'demo' });

      expect(res.status).toBe(401);
      expect(res.body.error).toContain('API key');
    });

    it('returns 401 when API key wrong', async () => {
      const app = createApp({
        vertexAI: mockVertexAI as any,
        mealRepo: mockMealRepo as any,
        dietRulesRepo: mockDietRulesRepo as any,
        apiKey: 'secret-key',
      });

      const res = await request(app)
        .post('/analyze-meal')
        .set('X-API-Key', 'wrong-key')
        .send({ image_base64: 'fake', user_id: 'demo' });

      expect(res.status).toBe(401);
    });

    it('returns 200 when API key correct', async () => {
      const app = createApp({
        vertexAI: mockVertexAI as any,
        mealRepo: mockMealRepo as any,
        dietRulesRepo: mockDietRulesRepo as any,
        apiKey: 'secret-key',
      });

      const res = await request(app)
        .post('/analyze-meal')
        .set('X-API-Key', 'secret-key')
        .send({ image_base64: 'fake', user_id: 'demo' });

      expect(res.status).toBe(200);
    });
  });
});
