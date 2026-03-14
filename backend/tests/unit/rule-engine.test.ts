/**
 * Unit tests: Rule engine
 */

import { describe, it, expect } from 'vitest';
import { evaluateCompliance, extractKcalTarget, DEFAULT_RULES } from '../../src/domain/rule-engine.js';
import type { DietRule } from '../../src/domain/diet-rules.js';

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

  describe('calorie-aware scoring', () => {
    it('applies no calorie penalty for meals under 800 kcal', () => {
      const result = evaluateCompliance(['chicken', 'salad', 'rice'], DEFAULT_RULES, {
        mealKcal: 500,
        dailyKcalSoFar: 0,
      });
      expect(result.score).toBe(100);
      expect(result.calorieWarning).toBeUndefined();
      expect(result.mealKcal).toBe(500);
      expect(result.dailyKcalTotal).toBe(500);
      expect(result.kcalTarget).toBe(2000);
    });

    it('applies mild penalty for meals 800-1200 kcal', () => {
      const result = evaluateCompliance(['chicken', 'salad', 'rice'], DEFAULT_RULES, {
        mealKcal: 1000,
        dailyKcalSoFar: 0,
      });
      expect(result.score).toBe(92);
      expect(result.calorieWarning).toContain('a bit heavy');
    });

    it('applies moderate penalty for meals 1200-1800 kcal', () => {
      const result = evaluateCompliance(['chicken', 'salad', 'rice'], DEFAULT_RULES, {
        mealKcal: 1500,
        dailyKcalSoFar: 0,
      });
      expect(result.score).toBe(82);
      expect(result.calorieWarning).toContain('above target');
    });

    it('applies severe penalty for meals 1800-3000 kcal', () => {
      const result = evaluateCompliance(['chicken', 'salad', 'rice'], DEFAULT_RULES, {
        mealKcal: 2500,
        dailyKcalSoFar: 0,
      });
      expect(result.score).toBeLessThanOrEqual(70);
      expect(result.calorieWarning).toContain('extremely high');
    });

    it('applies extreme penalty for meals over 3000 kcal (calorie bomb)', () => {
      const result = evaluateCompliance(['grilled steak', 'sausage', 'ribs'], DEFAULT_RULES, {
        mealKcal: 4000,
        dailyKcalSoFar: 0,
      });
      expect(result.score).toBeLessThanOrEqual(35);
      expect(result.calorieWarning).toContain('calorie bomb');
      expect(result.suggestions.some((s) => s.includes('Extreme calorie intake'))).toBe(true);
    });

    it('adds daily overshoot penalty when daily total exceeds target', () => {
      const result = evaluateCompliance(['chicken', 'salad'], DEFAULT_RULES, {
        mealKcal: 800,
        dailyKcalSoFar: 1500,
      });
      expect(result.dailyKcalTotal).toBe(2300);
      expect(result.calorieWarning).toContain('Daily total');
      expect(result.calorieWarning).toContain('over your daily limit');
      expect(result.score).toBeLessThan(100);
    });

    it('stacks meal penalty and daily overshoot penalty', () => {
      const result = evaluateCompliance(['grilled steak', 'sausage', 'ribs'], DEFAULT_RULES, {
        mealKcal: 4000,
        dailyKcalSoFar: 1000,
      });
      expect(result.score).toBeLessThanOrEqual(35);
      expect(result.dailyKcalTotal).toBe(5000);
      expect(result.calorieWarning).toContain('calorie bomb');
      expect(result.calorieWarning).toContain('Daily total');
    });

    it('uses kcal target from note rules when available', () => {
      const rules: DietRule[] = [
        { type: 'allowed', items: ['salad', 'chicken'] },
        { type: 'note', text: 'Stay under 1500 kcal per day' },
      ];
      const result = evaluateCompliance(['salad', 'chicken'], rules, {
        mealKcal: 600,
        dailyKcalSoFar: 1000,
      });
      expect(result.kcalTarget).toBe(1500);
      expect(result.dailyKcalTotal).toBe(1600);
      expect(result.calorieWarning).toContain('Daily total');
    });

    it('does not include calorie fields when no kcal provided', () => {
      const result = evaluateCompliance(['chicken', 'salad'], DEFAULT_RULES);
      expect(result.calorieWarning).toBeUndefined();
      expect(result.mealKcal).toBeUndefined();
      expect(result.dailyKcalTotal).toBeUndefined();
      expect(result.kcalTarget).toBeUndefined();
    });

    it('does not penalize when mealKcal is 0', () => {
      const result = evaluateCompliance(['chicken', 'salad'], DEFAULT_RULES, {
        mealKcal: 0,
        dailyKcalSoFar: 0,
      });
      expect(result.score).toBe(100);
      expect(result.calorieWarning).toBeUndefined();
    });

    it('handles daily overshoot under 20%', () => {
      const result = evaluateCompliance(['chicken', 'salad'], DEFAULT_RULES, {
        mealKcal: 500,
        dailyKcalSoFar: 1600,
      });
      expect(result.dailyKcalTotal).toBe(2100);
      expect(result.score).toBe(97);
    });

    it('handles daily overshoot between 20-50%', () => {
      const result = evaluateCompliance(['chicken', 'salad'], DEFAULT_RULES, {
        mealKcal: 500,
        dailyKcalSoFar: 2000,
      });
      expect(result.dailyKcalTotal).toBe(2500);
      expect(result.score).toBe(92);
    });

    it('handles empty ingredient list with calorie context', () => {
      const result = evaluateCompliance([], DEFAULT_RULES, {
        mealKcal: 4000,
        dailyKcalSoFar: 0,
      });
      expect(result.score).toBeLessThanOrEqual(35);
      expect(result.calorieWarning).toContain('calorie bomb');
    });

    it('treats non-forbidden items as compliant when only forbidden rules exist', () => {
      const rules: DietRule[] = [
        { type: 'forbidden', items: ['soda'] },
      ];
      const result = evaluateCompliance(['chicken', 'salad'], rules);
      expect(result.compliantItems).toContain('chicken');
      expect(result.compliantItems).toContain('salad');
      expect(result.score).toBe(100);
    });

    it('puts items in uncertain when allowed rules exist but item not in them', () => {
      const rules: DietRule[] = [
        { type: 'allowed', items: ['chicken'] },
      ];
      const result = evaluateCompliance(['chicken', 'steak'], rules);
      expect(result.compliantItems).toContain('chicken');
      expect(result.uncertainItems).toContain('steak');
    });
  });

  describe('extractKcalTarget', () => {
    it('extracts kcal from note rule text', () => {
      const rules: DietRule[] = [
        { type: 'note', text: 'Stay under 1800 kcal per day' },
      ];
      expect(extractKcalTarget(rules)).toBe(1800);
    });

    it('extracts calories from note rule text', () => {
      const rules: DietRule[] = [
        { type: 'note', text: 'Maximum 2000 calories daily' },
      ];
      expect(extractKcalTarget(rules)).toBe(2000);
    });

    it('returns undefined when no kcal note exists', () => {
      const rules: DietRule[] = [
        { type: 'forbidden', items: ['sugar'] },
      ];
      expect(extractKcalTarget(rules)).toBeUndefined();
    });
  });
});
