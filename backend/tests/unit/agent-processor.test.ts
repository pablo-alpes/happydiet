/**
 * Unit tests: Agent 2 — Processor
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { processorAgent } from '../../src/application/agent-processor.js';

const mockMealRepo = {
  save: vi.fn().mockResolvedValue(undefined),
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
});
