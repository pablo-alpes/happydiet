/**
 * Unit tests: Rule engine
 */

import { describe, it, expect } from 'vitest';
import { evaluateCompliance, DEFAULT_RULES } from '../../src/domain/rule-engine.js';

describe('rule-engine', () => {
  it('returns 100% score when all items compliant', () => {
    const result = evaluateCompliance(['chicken', 'salad', 'rice'], DEFAULT_RULES);
    expect(result.score).toBe(100);
    expect(result.compliantItems).toContain('chicken');
    expect(result.nonCompliantItems).toHaveLength(0);
  });

  it('returns lower score when forbidden items present', () => {
    const result = evaluateCompliance(['chicken', 'soda', 'salad'], DEFAULT_RULES);
    expect(result.score).toBeLessThan(100);
    expect(result.nonCompliantItems).toContain('soda');
    expect(result.suggestions.length).toBeGreaterThan(0);
  });

  it('handles empty ingredients', () => {
    const result = evaluateCompliance([], DEFAULT_RULES);
    expect(result.score).toBe(100);
    expect(result.compliantItems).toHaveLength(0);
  });

  it('handles custom rules', () => {
    const rules = [
      { type: 'forbidden' as const, items: ['pizza'], reason: 'Too many calories' },
    ];
    const result = evaluateCompliance(['pizza', 'salad'], rules);
    expect(result.nonCompliantItems).toContain('pizza');
    expect(result.compliantItems).toContain('salad');
  });

  it('returns less than 100% when diet rules forbid some ingredients', () => {
    const rules = [
      { type: 'forbidden' as const, items: ['soda', 'bread'], reason: 'Avoid' },
    ];
    const result = evaluateCompliance(['chicken', 'soda', 'salad', 'bread'], rules);
    expect(result.score).toBe(50);
    expect(result.nonCompliantItems).toContain('soda');
    expect(result.nonCompliantItems).toContain('bread');
    expect(result.compliantItems).toContain('chicken');
    expect(result.compliantItems).toContain('salad');
  });
});
