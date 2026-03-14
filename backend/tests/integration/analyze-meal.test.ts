/**
 * Integration tests: POST /analyze-meal (mocked Vertex AI, Firestore)
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { analyzeMeal } from '../../src/application/analyze-meal.js';

const mockVisionResult = {
  ingredients: ['chicken', 'rice', 'salad'],
  estimatedKcal: 450,
};

const mockVertexAI = {
  analyzeImage: vi.fn().mockResolvedValue(mockVisionResult),
  parseDietText: vi.fn().mockResolvedValue([
    { type: 'forbidden' as const, items: ['soda'], reason: 'Avoid' },
  ]),
  parseDietImage: vi.fn().mockResolvedValue([]),
  checkComplianceSemantic: vi.fn().mockResolvedValue([]),
};

const mockMealRepo = {
  save: vi.fn().mockResolvedValue(undefined),
};

const mockGetRules = vi.fn().mockResolvedValue([]);

describe('analyze-meal use case', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('returns compliance result from vision + rules', async () => {
    const result = await analyzeMeal(
      { imageBase64: 'fake-base64', userId: 'demo' },
      {
        vertexAI: mockVertexAI as any,
        mealRepo: mockMealRepo as any,
        getRules: mockGetRules,
      }
    );

    expect(mockVertexAI.analyzeImage).toHaveBeenCalledWith('fake-base64');
    expect(result.score).toBeGreaterThanOrEqual(0);
    expect(result.score).toBeLessThanOrEqual(100);
    expect(result.compliantItems).toBeInstanceOf(Array);
    expect(result.nonCompliantItems).toBeInstanceOf(Array);
    expect(result.suggestions).toBeInstanceOf(Array);
    expect(mockMealRepo.save).toHaveBeenCalled();
  });

    it('uses default rules when getRules returns empty', async () => {
      mockGetRules.mockResolvedValueOnce([]);
      const result = await analyzeMeal(
        { imageBase64: 'fake', userId: 'demo' },
        {
          vertexAI: mockVertexAI as any,
          mealRepo: mockMealRepo as any,
          getRules: mockGetRules,
        }
      );

      expect(result.ingredients).toEqual(['chicken', 'rice', 'salad']);
      expect(result.estimatedKcal).toBe(450);
    });

    it('uses custom rules when getRules returns non-empty', async () => {
      mockGetRules.mockResolvedValueOnce([
        { type: 'forbidden' as const, items: ['soda'], reason: 'Avoid' },
      ]);
      const result = await analyzeMeal(
        { imageBase64: 'fake', userId: 'demo' },
        {
          vertexAI: mockVertexAI as any,
          mealRepo: mockMealRepo as any,
          getRules: mockGetRules,
        }
      );

      expect(result.ingredients).toEqual(['chicken', 'rice', 'salad']);
      expect(mockGetRules).toHaveBeenCalledWith('demo');
    });

  it('uses dietRules override when provided', async () => {
    const result = await analyzeMeal(
      {
        imageBase64: 'fake',
        userId: 'demo',
        dietRules: [{ type: 'forbidden' as const, items: ['rice'], reason: 'Avoid' }],
      },
      {
        vertexAI: mockVertexAI as any,
        mealRepo: mockMealRepo as any,
        getRules: mockGetRules,
      }
    );

    expect(mockGetRules).not.toHaveBeenCalled();
    expect(result.nonCompliantItems).toContain('rice');
    expect(result.score).toBe(67);
  });

  it('uses dietText override when provided (parses via Vertex AI)', async () => {
    const result = await analyzeMeal(
      {
        imageBase64: 'fake',
        userId: 'demo',
        dietText: 'No soda',
      },
      {
        vertexAI: mockVertexAI as any,
        mealRepo: mockMealRepo as any,
        getRules: mockGetRules,
      }
    );

    expect(mockVertexAI.parseDietText).toHaveBeenCalledWith('No soda');
    expect(mockGetRules).not.toHaveBeenCalled();
    expect(result.ingredients).toEqual(['chicken', 'rice', 'salad']);
  });

  it('returns message from reporter', async () => {
    const result = await analyzeMeal(
      { imageBase64: 'fake', userId: 'demo' },
      {
        vertexAI: mockVertexAI as any,
        mealRepo: mockMealRepo as any,
        getRules: mockGetRules,
      }
    );

    expect(result.message).toBeDefined();
    expect(typeof result.message).toBe('string');
    expect(result.message!.length).toBeGreaterThan(0);
  });
});
