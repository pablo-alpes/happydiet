/**
 * Agent 2 — Processor: Rule matching; compute compliance; persist analysis
 * Uses rule-engine (precise + fuzzy) + optional LLM semantic check for custom diets.
 */

import { evaluateCompliance, extractKcalTarget, DEFAULT_RULES } from '../domain/rule-engine.js';
import type { CalorieContext } from '../domain/rule-engine.js';
import type { DietRule, ForbiddenRule } from '../domain/diet-rules.js';
import type { MealMoment } from '../domain/meal.js';
import type { MealRepository } from '../infrastructure/firestore-repository.js';
import type { VertexAIClient } from '../infrastructure/vertex-ai-client.js';

export interface ProcessorInput {
  ingredients: string[];
  estimatedKcal?: number;
  userId: string;
  mealMoment?: string;
}

export interface ProcessorOutput {
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

export async function processorAgent(
  input: ProcessorInput,
  deps: {
    mealRepo: MealRepository;
    getRules: (userId: string) => Promise<DietRule[]>;
    vertexAI?: VertexAIClient | null;
  }
): Promise<ProcessorOutput> {
  const rules = await deps.getRules(input.userId);
  const effectiveRules = rules.length > 0 ? rules : DEFAULT_RULES;

  let dailyKcalSoFar = 0;
  if (input.estimatedKcal != null && deps.mealRepo.getDailyKcal) {
    try {
      dailyKcalSoFar = await deps.mealRepo.getDailyKcal(input.userId);
    } catch (err) {
      console.warn('[processor] failed to fetch daily kcal, defaulting to 0', err);
    }
  }

  const calorieCtx: CalorieContext | undefined = input.estimatedKcal != null
    ? {
        mealKcal: input.estimatedKcal,
        dailyKcalSoFar,
        dailyKcalTarget: extractKcalTarget(effectiveRules),
      }
    : undefined;

  let compliance = evaluateCompliance(input.ingredients, effectiveRules, calorieCtx);

  if (deps.vertexAI && rules.length > 0) {
    const forbiddenItems = (effectiveRules.filter((r): r is ForbiddenRule => r.type === 'forbidden') as ForbiddenRule[])
      .flatMap((r) => r.items)
      .filter(Boolean);
    if (forbiddenItems.length > 0) {
      try {
        const semanticNonCompliant = await deps.vertexAI.checkComplianceSemantic(input.ingredients, forbiddenItems);
        const merged = new Set([...compliance.nonCompliantItems, ...semanticNonCompliant]);
        const uncertain = (compliance.uncertainItems ?? []).filter((i) => !merged.has(i));
        const ingredientScore = input.ingredients.length === 0
          ? 100
          : Math.round(((input.ingredients.length - merged.size) / input.ingredients.length) * 100);
        const caloriePenalty = compliance.score - (compliance.mealKcal != null
          ? evaluateCompliance(input.ingredients, effectiveRules).score
          : ingredientScore);
        compliance = {
          ...compliance,
          nonCompliantItems: [...merged],
          compliantItems: input.ingredients.filter((i) => !merged.has(i) && i),
          uncertainItems: uncertain.length > 0 ? uncertain : undefined,
          score: Math.max(0, ingredientScore + caloriePenalty),
          detalle: merged.size > 0 ? `Off plan: ${[...merged].join(', ')}` : 'All items compliant',
        };
      } catch (err) {
        console.warn('[processor] semantic check failed, using rule-engine only', err);
      }
    }
  }

  const now = new Date();
  const hour = now.getHours();
  const inferredMoment: MealMoment =
    input.mealMoment && ['breakfast', 'lunch', 'dinner', 'snack'].includes(input.mealMoment)
      ? (input.mealMoment as MealMoment)
      : hour < 11
        ? 'breakfast'
        : hour < 17
          ? 'lunch'
          : 'dinner';

  const mealRecord = {
    userId: input.userId,
    timestamp: now,
    mealMoment: inferredMoment,
    ingredients: input.ingredients,
    estimatedKcal: input.estimatedKcal,
    complianceScore: compliance.score,
    compliantItems: compliance.compliantItems,
    nonCompliantItems: compliance.nonCompliantItems,
    suggestions: compliance.suggestions,
  };

  await deps.mealRepo.save(mealRecord);

  return {
    score: compliance.score,
    compliantItems: compliance.compliantItems,
    nonCompliantItems: compliance.nonCompliantItems,
    uncertainItems: compliance.uncertainItems,
    suggestions: compliance.suggestions,
    detalle: compliance.detalle,
    calorieWarning: compliance.calorieWarning,
    mealKcal: compliance.mealKcal,
    dailyKcalTotal: compliance.dailyKcalTotal,
    kcalTarget: compliance.kcalTarget,
  };
}
