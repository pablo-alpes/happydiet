/**
 * Unit tests: Agent 2 — Processor
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { processorAgent } from '../../src/application/agent-processor.js';

const mockMealRepo = {
  save: vi.fn().mockResolvedValue(undefined),
  getDailyKcal: vi.fn().mockResolvedValue(0),
};

const mockGetRules = vi.fn().mockResolvedValue([]);

describe('processorAgent', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockGetRules.mockResolvedValue([]);
  });

  it('computes compliance and saves meal', async () => {
    const result = await processorAgent(
      { ingredients: ['chicken', 'rice', 'salad'], userId: 'demo' },
      { mealRepo: mockMealRepo as any, getRules: mockGetRules }
    );

    expect(result.score).toBeGreaterThanOrEqual(0);
    expect(result.score).toBeLessThanOrEqual(100);
    expect(result.compliantItems).toBeInstanceOf(Array);
    expect(result.nonCompliantItems).toBeInstanceOf(Array);
    expect(mockMealRepo.save).toHaveBeenCalled();
    expect(mockGetRules).toHaveBeenCalledWith('demo');
  });

  it('uses custom rules when getRules returns non-empty', async () => {
    mockGetRules.mockResolvedValueOnce([
      { type: 'forbidden' as const, items: ['soda'], reason: 'Avoid' },
    ]);

    const result = await processorAgent(
      { ingredients: ['chicken', 'soda'], userId: 'demo' },
      { mealRepo: mockMealRepo as any, getRules: mockGetRules }
    );

    expect(result.nonCompliantItems).toContain('soda');
    expect(result.compliantItems).toContain('chicken');
    expect(result.score).toBe(50);
  });

  it('passes mealMoment and estimatedKcal to save', async () => {
    await processorAgent(
      {
        ingredients: ['salad'],
        estimatedKcal: 300,
        userId: 'u1',
        mealMoment: 'lunch',
      },
      { mealRepo: mockMealRepo as any, getRules: mockGetRules }
    );

    const saved = mockMealRepo.save.mock.calls[0][0];
    expect(saved.mealMoment).toBe('lunch');
    expect(saved.estimatedKcal).toBe(300);
    expect(saved.userId).toBe('u1');
  });

  it('infers breakfast when hour is before 11', async () => {
    const hourSpy = vi.spyOn(Date.prototype, 'getHours').mockReturnValue(9);
    await processorAgent(
      { ingredients: ['eggs'], userId: 'demo' },
      { mealRepo: mockMealRepo as any, getRules: mockGetRules }
    );
    hourSpy.mockRestore();

    const saved = mockMealRepo.save.mock.calls.at(-1)?.[0];
    expect(saved.mealMoment).toBe('breakfast');
  });

  it('infers lunch when hour is between 11 and 16', async () => {
    const hourSpy = vi.spyOn(Date.prototype, 'getHours').mockReturnValue(13);
    await processorAgent(
      { ingredients: ['salad'], userId: 'demo' },
      { mealRepo: mockMealRepo as any, getRules: mockGetRules }
    );
    hourSpy.mockRestore();

    const saved = mockMealRepo.save.mock.calls.at(-1)?.[0];
    expect(saved.mealMoment).toBe('lunch');
  });

  it('applies calorie penalty for high kcal meals', async () => {
    mockMealRepo.getDailyKcal = vi.fn().mockResolvedValue(500);

    const result = await processorAgent(
      {
        ingredients: ['steak', 'sausage', 'ribs'],
        estimatedKcal: 4000,
        userId: 'demo',
      },
      { mealRepo: mockMealRepo as any, getRules: mockGetRules }
    );

    expect(result.score).toBeLessThanOrEqual(60);
    expect(result.calorieWarning).toBeDefined();
    expect(result.calorieWarning).toContain('calorie bomb');
    expect(result.mealKcal).toBe(4000);
    expect(result.dailyKcalTotal).toBe(4500);
  });

  it('returns calorie data in output when kcal provided', async () => {
    mockMealRepo.getDailyKcal = vi.fn().mockResolvedValue(0);

    const result = await processorAgent(
      {
        ingredients: ['salad', 'chicken'],
        estimatedKcal: 500,
        userId: 'demo',
      },
      { mealRepo: mockMealRepo as any, getRules: mockGetRules }
    );

    expect(result.mealKcal).toBe(500);
    expect(result.dailyKcalTotal).toBe(500);
    expect(result.kcalTarget).toBe(2000);
  });

  it('handles missing getDailyKcal gracefully', async () => {
    delete (mockMealRepo as any).getDailyKcal;

    const result = await processorAgent(
      {
        ingredients: ['salad'],
        estimatedKcal: 500,
        userId: 'demo',
      },
      { mealRepo: mockMealRepo as any, getRules: mockGetRules }
    );

    expect(result.score).toBeGreaterThanOrEqual(0);
    expect(result.mealKcal).toBe(500);
  });

  it('handles getDailyKcal throwing gracefully', async () => {
    mockMealRepo.getDailyKcal = vi.fn().mockRejectedValue(new Error('DB unavailable'));

    const result = await processorAgent(
      {
        ingredients: ['salad'],
        estimatedKcal: 500,
        userId: 'demo',
      },
      { mealRepo: mockMealRepo as any, getRules: mockGetRules }
    );

    expect(result.score).toBeGreaterThanOrEqual(0);
    expect(result.mealKcal).toBe(500);
    expect(result.dailyKcalTotal).toBe(500);
  });

  it('applies calorie penalty with semantic check and vertexAI', async () => {
    mockMealRepo.getDailyKcal = vi.fn().mockResolvedValue(0);
    mockGetRules.mockResolvedValueOnce([
      { type: 'forbidden' as const, items: ['sugar', 'soda'], reason: 'Avoid' },
      { type: 'allowed' as const, items: ['chicken', 'salad'] },
    ]);

    const mockVertexAI = {
      checkComplianceSemantic: vi.fn().mockResolvedValue(['soda']),
    };

    const result = await processorAgent(
      {
        ingredients: ['chicken', 'soda', 'salad'],
        estimatedKcal: 2000,
        userId: 'demo',
      },
      { mealRepo: mockMealRepo as any, getRules: mockGetRules, vertexAI: mockVertexAI as any }
    );

    expect(result.nonCompliantItems).toContain('soda');
    expect(result.score).toBeLessThan(67);
    expect(result.calorieWarning).toBeDefined();
  });

  it('handles semantic check failure gracefully with calorie context', async () => {
    mockMealRepo.getDailyKcal = vi.fn().mockResolvedValue(0);
    mockGetRules.mockResolvedValueOnce([
      { type: 'forbidden' as const, items: ['sugar'], reason: 'Avoid' },
    ]);

    const mockVertexAI = {
      checkComplianceSemantic: vi.fn().mockRejectedValue(new Error('API error')),
    };

    const result = await processorAgent(
      {
        ingredients: ['chicken', 'salad'],
        estimatedKcal: 1500,
        userId: 'demo',
      },
      { mealRepo: mockMealRepo as any, getRules: mockGetRules, vertexAI: mockVertexAI as any }
    );

    expect(result.score).toBeGreaterThanOrEqual(0);
    expect(result.calorieWarning).toBeDefined();
  });

  it('semantic check without kcal uses ingredient-only score', async () => {
    mockGetRules.mockResolvedValueOnce([
      { type: 'forbidden' as const, items: ['sugar'], reason: 'Avoid' },
    ]);
    const mockVertexAI = {
      checkComplianceSemantic: vi.fn().mockResolvedValue([]),
    };

    const result = await processorAgent(
      { ingredients: ['chicken', 'salad'], userId: 'demo' },
      { mealRepo: mockMealRepo as any, getRules: mockGetRules, vertexAI: mockVertexAI as any }
    );

    expect(result.score).toBe(100);
  });

  it('semantic check with empty ingredients returns 100', async () => {
    mockGetRules.mockResolvedValueOnce([
      { type: 'forbidden' as const, items: ['sugar'], reason: 'Avoid' },
    ]);
    const mockVertexAI = {
      checkComplianceSemantic: vi.fn().mockResolvedValue([]),
    };

    const result = await processorAgent(
      { ingredients: [], userId: 'demo' },
      { mealRepo: mockMealRepo as any, getRules: mockGetRules, vertexAI: mockVertexAI as any }
    );

    expect(result.score).toBe(100);
  });

  it('handles semantic check with no forbidden items and vertexAI', async () => {
    mockMealRepo.getDailyKcal = vi.fn().mockResolvedValue(0);
    mockGetRules.mockResolvedValueOnce([
      { type: 'allowed' as const, items: ['chicken', 'salad'] },
    ]);

    const mockVertexAI = {
      checkComplianceSemantic: vi.fn(),
    };

    const result = await processorAgent(
      {
        ingredients: ['chicken', 'salad'],
        estimatedKcal: 500,
        userId: 'demo',
      },
      { mealRepo: mockMealRepo as any, getRules: mockGetRules, vertexAI: mockVertexAI as any }
    );

    expect(mockVertexAI.checkComplianceSemantic).not.toHaveBeenCalled();
    expect(result.score).toBe(100);
  });
});
