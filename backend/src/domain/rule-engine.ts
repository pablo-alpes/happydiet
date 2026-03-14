/**
 * Domain: Rule engine - ingredient matching, score calculation
 * Pure logic, no framework deps. Uses precise + fuzzy matching.
 */

import type { DietRule, ForbiddenRule } from './diet-rules.js';
import type { ComplianceResult } from './meal.js';

function normalizeItem(item: string): string {
  return item.toLowerCase().trim().replace(/\s+/g, ' ');
}

/** Simple similarity: shared words or substring overlap */
function similarity(a: string, b: string): number {
  const na = normalizeItem(a);
  const nb = normalizeItem(b);
  if (na === nb) return 1;
  if (na.includes(nb) || nb.includes(na)) return 0.9;
  const wordsA = new Set(na.split(/\s+/).filter(Boolean));
  const wordsB = new Set(nb.split(/\s+/).filter(Boolean));
  let overlap = 0;
  for (const w of wordsA) {
    if (wordsB.has(w) || [...wordsB].some((bw) => bw.includes(w) || w.includes(bw))) overlap++;
  }
  if (wordsA.size === 0) return 0;
  return overlap / Math.max(wordsA.size, wordsB.size);
}

function itemMatchesRule(item: string, ruleItems: string[]): boolean {
  const normalized = normalizeItem(item);
  for (const r of ruleItems) {
    const rn = normalizeItem(r);
    if (normalized === rn) return true;
    if (normalized.includes(rn) || rn.includes(normalized)) return true;
    if (similarity(item, r) >= 0.6) return true;
  }
  return false;
}

function itemMatchesAnyRule(item: string, rules: DietRule[], type: 'forbidden' | 'allowed'): boolean {
  for (const rule of rules) {
    if (rule.type === type && 'items' in rule && itemMatchesRule(item, rule.items)) return true;
  }
  return false;
}

export interface CalorieContext {
  mealKcal?: number;
  dailyKcalSoFar?: number;
  dailyKcalTarget?: number;
}

const DEFAULT_DAILY_KCAL_TARGET = 2000;
const MEAL_KCAL_THRESHOLDS = [
  { max: 800, penalty: 0, level: 'ok' },
  { max: 1200, penalty: 8, level: 'high' },
  { max: 1800, penalty: 18, level: 'very_high' },
  { max: 3000, penalty: 32, level: 'extreme' },
  { max: Infinity, penalty: 45, level: 'bomb' },
] as const;

/** Extract a daily kcal target from note rules (e.g. "1800 kcal", "stay under 2000 calories") */
export function extractKcalTarget(rules: DietRule[]): number | undefined {
  for (const rule of rules) {
    if (rule.type !== 'note') continue;
    const match = rule.text.match(/(\d{3,5})\s*(?:kcal|calories?|cal)\b/i);
    if (match) return parseInt(match[1], 10);
  }
  return undefined;
}

export function evaluateCompliance(
  ingredients: string[],
  rules: DietRule[],
  calorieCtx?: CalorieContext
): ComplianceResult {
  const compliantItems: string[] = [];
  const nonCompliantItems: string[] = [];
  const uncertainItems: string[] = [];
  const suggestions: string[] = [];
  const hasRules = rules.length > 0;

  const hasAllowedRules = rules.some((r) => r.type === 'allowed');

  for (const ingredient of ingredients) {
    if (!ingredient) continue;
    const inForbidden = itemMatchesAnyRule(ingredient, rules, 'forbidden');
    if (inForbidden) {
      nonCompliantItems.push(ingredient);
      const fr = rules.find((r): r is ForbiddenRule => r.type === 'forbidden' && itemMatchesRule(ingredient, r.items)) as ForbiddenRule | undefined;
      if (fr?.reason) suggestions.push(`${ingredient}: ${fr.reason}`);
      continue;
    }
    if (!hasRules || !hasAllowedRules) {
      compliantItems.push(ingredient);
    } else {
      const inAllowed = itemMatchesAnyRule(ingredient, rules, 'allowed');
      if (inAllowed) {
        compliantItems.push(ingredient);
      } else {
        uncertainItems.push(ingredient);
      }
    }
  }

  const total = ingredients.length;
  const compliantCount = compliantItems.length + uncertainItems.length;
  let score = total === 0 ? 100 : Math.round((compliantCount / total) * 100);

  let calorieWarning: string | undefined;
  const kcalTarget = calorieCtx?.dailyKcalTarget ?? extractKcalTarget(rules) ?? DEFAULT_DAILY_KCAL_TARGET;
  const mealKcal = calorieCtx?.mealKcal;
  const dailyKcalSoFar = calorieCtx?.dailyKcalSoFar ?? 0;

  if (mealKcal != null && mealKcal > 0) {
    const threshold = MEAL_KCAL_THRESHOLDS.find((t) => mealKcal <= t.max)!;
    if (threshold.penalty > 0) {
      score = Math.max(0, score - threshold.penalty);
      if (threshold.level === 'bomb') {
        calorieWarning = `This meal is ~${mealKcal} kcal — that is a calorie bomb. This single meal exceeds a full day's intake. Please moderate portions significantly.`;
        suggestions.unshift(`Extreme calorie intake (~${mealKcal} kcal). Split into smaller meals or reduce portions drastically.`);
      } else if (threshold.level === 'extreme') {
        calorieWarning = `This meal is ~${mealKcal} kcal — extremely high. That is almost an entire day's calories in one sitting. Consider much smaller portions.`;
        suggestions.unshift(`Very high calorie meal (~${mealKcal} kcal). Aim for 500-800 kcal per meal.`);
      } else if (threshold.level === 'very_high') {
        calorieWarning = `This meal is ~${mealKcal} kcal — above target. Try reducing portion sizes.`;
        suggestions.unshift(`High calorie meal (~${mealKcal} kcal). Consider lighter portions.`);
      } else {
        calorieWarning = `This meal is ~${mealKcal} kcal — a bit heavy. Watch your portions for the rest of the day.`;
      }
    }

    const dailyTotal = dailyKcalSoFar + mealKcal;
    if (dailyTotal > kcalTarget) {
      const overPct = Math.round(((dailyTotal - kcalTarget) / kcalTarget) * 100);
      const dailyPenalty = overPct >= 100 ? 25 : overPct >= 50 ? 15 : overPct >= 20 ? 8 : 3;
      score = Math.max(0, score - dailyPenalty);
      const existing = calorieWarning ?? '';
      calorieWarning = `${existing} Daily total: ~${dailyTotal} kcal (target: ${kcalTarget}). You are ${overPct}% over your daily limit.`.trim();
      suggestions.unshift(`Daily calorie target exceeded (${dailyTotal}/${kcalTarget} kcal). Go lighter on remaining meals.`);
    }
  }

  return {
    score,
    compliantItems,
    nonCompliantItems,
    uncertainItems: uncertainItems.length > 0 ? uncertainItems : undefined,
    suggestions: suggestions.length > 0 ? suggestions : ['Keep up the good choices!'],
    detalle: nonCompliantItems.length > 0
      ? `Off plan: ${nonCompliantItems.join(', ')}`
      : 'All items compliant',
    calorieWarning,
    mealKcal,
    dailyKcalTotal: mealKcal != null ? dailyKcalSoFar + mealKcal : undefined,
    kcalTarget: mealKcal != null ? kcalTarget : undefined,
  };
}

/** Default rules when none provided (MVP fallback) */
export const DEFAULT_RULES: DietRule[] = [
  {
    type: 'forbidden',
    items: ['sugar', 'soda', 'candy', 'cake', 'pastry'],
    reason: 'Avoid for diet compliance',
  },
  {
    type: 'allowed',
    items: ['vegetables', 'salad', 'chicken', 'fish', 'rice', 'eggs'],
  },
];
