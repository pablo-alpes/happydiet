/**
 * Demo handlers — mock data for showcase when backend has no real data
 */

import type { Request, Response } from 'express';

const MOCK_RULES = [
  { type: 'forbidden', items: ['sugar', 'soda', 'white bread', 'pastries', 'fried food'], reason: 'Avoid for weight management' },
  { type: 'allowed', items: ['vegetables', 'lean protein', 'whole grains', 'fruits'], maxPortion: 'moderate' },
  { type: 'limit', items: ['coffee'], maxPerDay: 2, unit: 'cups' },
  { type: 'note', text: 'Drink 2L water daily. Prefer grilled over fried.' },
];

/** Build demo meals with one meal per day for the last 14 days. Uses local midnight to avoid timezone mismatches. */
function buildDemoMeals(): Array<Record<string, unknown>> {
  const now = new Date();
  const meals: Array<Record<string, unknown>> = [];
  const dayMeals: Array<{ ingredients: string[]; score: number }> = [
    { ingredients: ['greek yogurt', 'berries', 'honey'], score: 78 },
    { ingredients: ['eggs', 'avocado', 'whole grain toast'], score: 90 },
    { ingredients: ['oatmeal', 'banana', 'almonds'], score: 92 },
    { ingredients: ['smoothie', 'spinach', 'banana'], score: 95 },
    { ingredients: ['grilled fish', 'asparagus', 'sweet potato'], score: 96 },
    { ingredients: ['oatmeal', 'blueberries', 'walnuts'], score: 94 },
    { ingredients: ['chicken salad', 'quinoa', 'olive oil'], score: 88 },
    { ingredients: ['grilled fish', 'spinach', 'sweet potato'], score: 98 },
    { ingredients: ['turkey wrap', 'hummus', 'carrots'], score: 85 },
    { ingredients: ['pizza', 'soda'], score: 35 },
    { ingredients: ['smoothie', 'spinach', 'banana', 'protein powder'], score: 95 },
    { ingredients: ['chicken stir-fry', 'vegetables', 'brown rice'], score: 92 },
    { ingredients: ['grilled chicken', 'salad', 'quinoa'], score: 95 },
    { ingredients: ['salmon', 'broccoli', 'rice'], score: 88 },
  ];
  for (let i = 0; i < 14; i++) {
    const d = new Date(now.getFullYear(), now.getMonth(), now.getDate() - i, 10, 0, 0);
    const m = dayMeals[i % dayMeals.length];
    meals.push({
      id: `m${i + 1}`,
      userId: 'demo',
      timestamp: d.toISOString(),
      mealMoment: i % 3 === 0 ? 'breakfast' : i % 3 === 1 ? 'lunch' : 'dinner',
      ingredients: m.ingredients,
      estimatedKcal: 350 + (i * 20) % 400,
      complianceScore: m.score,
      compliantItems: m.score >= 50 ? m.ingredients : [],
      nonCompliantItems: m.score < 50 ? m.ingredients : [],
      suggestions: [],
    });
  }
  return meals.sort((a, b) => new Date((b.timestamp as string)).getTime() - new Date((a.timestamp as string)).getTime());
}

export function getDemoMeals(): Array<Record<string, unknown>> {
  return buildDemoMeals();
}

export function createDemoMealsHandler() {
  return (_req: Request, res: Response) => {
    res.json({ meals: getDemoMeals() });
  };
}

export function createDemoRulesHandler() {
  return (_req: Request, res: Response) => {
    res.json({ rules: MOCK_RULES });
  };
}
