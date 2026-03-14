/**
 * UAT helpers: in-memory stores and mocks shared across UAT tests
 */

import type { MealRecord } from '../../src/domain/meal.js';
import type { DietRule } from '../../src/domain/diet-rules.js';

export function createInMemoryMealRepo() {
  const meals: MealRecord[] = [];
  return {
    async save(meal: Omit<MealRecord, 'id'>) {
      meals.push({ ...meal, id: `meal-${meals.length + 1}` });
    },
    async listByUser(userId: string) {
      return meals
        .filter((m) => m.userId === userId)
        .sort((a, b) => (b.timestamp as Date).getTime() - (a.timestamp as Date).getTime());
    },
    _getAll: () => [...meals],
  };
}

export function createInMemoryDietRulesRepo(rules: DietRule[] = []) {
  let stored = [...rules];
  return {
    async getByUser() {
      return stored;
    },
    async saveRules(_userId: string, newRules: DietRule[]) {
      stored = newRules;
    },
  };
}

export const MOCK_INGREDIENTS = ['chicken', 'rice', 'salad', 'soda'];

export const mockVertexAI = {
  analyzeImage: async () => ({
    ingredients: MOCK_INGREDIENTS,
    estimatedKcal: 550,
  }),
  parseDietText: async () => [] as DietRule[],
  parseDietImage: async () => [] as DietRule[],
  checkComplianceSemantic: async () => [] as string[],
};

export const CUSTOM_RULES_FORBID_SODA: DietRule[] = [
  { type: 'forbidden' as const, items: ['soda'], reason: 'Avoid sugary drinks' },
];
