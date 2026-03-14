/**
 * Domain: Meal entities and value objects
 */

export interface Ingredients {
  items: string[];
  estimatedKcal?: number;
}

export type MealMoment = 'breakfast' | 'lunch' | 'dinner' | 'snack' | 'other';

export interface MealRecord {
  id?: string;
  userId: string;
  timestamp: Date;
  mealMoment: MealMoment;
  ingredients: string[];
  estimatedKcal?: number;
  complianceScore: number;
  compliantItems: string[];
  nonCompliantItems: string[];
  suggestions: string[];
  dietVersion?: string;
}

export interface ComplianceResult {
  score: number;
  compliantItems: string[];
  nonCompliantItems: string[];
  uncertainItems?: string[];
  suggestions: string[];
  detalle?: string;
  calorieWarning?: string;
  mealKcal?: number;
  dailyKcalTotal?: number;
  kcalTarget?: number;
}
