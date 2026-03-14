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

const MOCK_MEALS = [
  { id: 'm1', userId: 'demo', timestamp: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString(), mealMoment: 'breakfast', ingredients: ['oatmeal', 'banana', 'almonds'], estimatedKcal: 380, complianceScore: 92, compliantItems: ['oatmeal', 'banana', 'almonds'], nonCompliantItems: [], suggestions: ['Keep it up!'] },
  { id: 'm2', userId: 'demo', timestamp: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString(), mealMoment: 'lunch', ingredients: ['grilled chicken', 'salad', 'quinoa'], estimatedKcal: 520, complianceScore: 95, compliantItems: ['grilled chicken', 'salad', 'quinoa'], nonCompliantItems: [], suggestions: [] },
  { id: 'm3', userId: 'demo', timestamp: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString(), mealMoment: 'dinner', ingredients: ['salmon', 'broccoli', 'rice'], estimatedKcal: 580, complianceScore: 88, compliantItems: ['salmon', 'broccoli', 'rice'], nonCompliantItems: [], suggestions: [] },
  { id: 'm4', userId: 'demo', timestamp: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000).toISOString(), mealMoment: 'breakfast', ingredients: ['eggs', 'avocado', 'whole grain toast'], estimatedKcal: 420, complianceScore: 90, compliantItems: ['eggs', 'avocado', 'whole grain toast'], nonCompliantItems: [], suggestions: [] },
  { id: 'm5', userId: 'demo', timestamp: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000).toISOString(), mealMoment: 'lunch', ingredients: ['turkey wrap', 'hummus', 'carrots'], estimatedKcal: 450, complianceScore: 85, compliantItems: ['turkey wrap', 'hummus', 'carrots'], nonCompliantItems: [], suggestions: [] },
  { id: 'm6', userId: 'demo', timestamp: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000).toISOString(), mealMoment: 'dinner', ingredients: ['pizza', 'soda'], estimatedKcal: 720, complianceScore: 35, compliantItems: [], nonCompliantItems: ['pizza', 'soda'], suggestions: ['Try a cauliflower crust pizza and sparkling water'] },
  { id: 'm7', userId: 'demo', timestamp: new Date(Date.now() - 0).toISOString(), mealMoment: 'breakfast', ingredients: ['greek yogurt', 'berries', 'honey'], estimatedKcal: 280, complianceScore: 78, compliantItems: ['greek yogurt', 'berries'], nonCompliantItems: ['honey'], suggestions: ['Swap honey for stevia'] },
  { id: 'm8', userId: 'demo', timestamp: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString(), mealMoment: 'lunch', ingredients: ['grilled fish', 'spinach', 'sweet potato'], estimatedKcal: 480, complianceScore: 98, compliantItems: ['grilled fish', 'spinach', 'sweet potato'], nonCompliantItems: [], suggestions: [] },
  { id: 'm9', userId: 'demo', timestamp: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000).toISOString(), mealMoment: 'dinner', ingredients: ['chicken stir-fry', 'vegetables', 'brown rice'], estimatedKcal: 550, complianceScore: 92, compliantItems: ['chicken stir-fry', 'vegetables', 'brown rice'], nonCompliantItems: [], suggestions: [] },
  { id: 'm10', userId: 'demo', timestamp: new Date(Date.now() - 10 * 24 * 60 * 60 * 1000).toISOString(), mealMoment: 'breakfast', ingredients: ['smoothie', 'spinach', 'banana', 'protein powder'], estimatedKcal: 320, complianceScore: 95, compliantItems: ['smoothie', 'spinach', 'banana', 'protein powder'], nonCompliantItems: [], suggestions: [] },
].sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime());

export function createDemoMealsHandler() {
  return (_req: Request, res: Response) => {
    res.json({ meals: MOCK_MEALS });
  };
}

export function createDemoRulesHandler() {
  return (_req: Request, res: Response) => {
    res.json({ rules: MOCK_RULES });
  };
}
