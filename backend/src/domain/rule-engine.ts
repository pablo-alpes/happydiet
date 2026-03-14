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

export function evaluateCompliance(
  ingredients: string[],
  rules: DietRule[]
): ComplianceResult {
  const compliantItems: string[] = [];
  const nonCompliantItems: string[] = [];
  const uncertainItems: string[] = [];
  const suggestions: string[] = [];
  const hasRules = rules.length > 0;

  for (const ingredient of ingredients) {
    if (!ingredient) continue;
    const inForbidden = itemMatchesAnyRule(ingredient, rules, 'forbidden');
    if (inForbidden) {
      nonCompliantItems.push(ingredient);
      const fr = rules.find((r): r is ForbiddenRule => r.type === 'forbidden' && itemMatchesRule(ingredient, r.items)) as ForbiddenRule | undefined;
      if (fr?.reason) suggestions.push(`${ingredient}: ${fr.reason}`);
      continue;
    }
    const inAllowed = hasRules && itemMatchesAnyRule(ingredient, rules, 'allowed');
    if (inAllowed) {
      compliantItems.push(ingredient);
    } else if (hasRules) {
      uncertainItems.push(ingredient);
    } else {
      compliantItems.push(ingredient);
    }
  }

  const total = ingredients.length;
  const compliantCount = compliantItems.length + uncertainItems.length;
  const score = total === 0 ? 100 : Math.round((compliantCount / total) * 100);

  return {
    score,
    compliantItems,
    nonCompliantItems,
    uncertainItems: uncertainItems.length > 0 ? uncertainItems : undefined,
    suggestions: suggestions.length > 0 ? suggestions : ['Keep up the good choices!'],
    detalle: nonCompliantItems.length > 0
      ? `Off plan: ${nonCompliantItems.join(', ')}`
      : 'All items compliant',
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
