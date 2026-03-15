/**
 * Application: Analyze meal use case
 * Orchestrates Reader → Processor → Reporter
 */

import { readerAgent } from './agent-reader.js';
import { processorAgent } from './agent-processor.js';
import { reporterAgent } from './agent-reporter.js';
import type { VertexAIClient } from '../infrastructure/vertex-ai-client.js';
import type { MealRepository } from '../infrastructure/firestore-repository.js';
import type { DietRule } from '../domain/diet-rules.js';

export interface AnalyzeMealInput {
  imageBase64: string;
  userId: string;
  /** Override: use these rules instead of Firestore */
  dietRules?: DietRule[];
  /** Override: parse this text and use as rules */
  dietText?: string;
}

export interface AnalyzeMealOutput {
  score: number;
  compliantItems: string[];
  nonCompliantItems: string[];
  uncertainItems?: string[];
  suggestions: string[];
  detalle?: string;
  message?: string;
  ingredients?: string[];
  estimatedKcal?: number;
  calorieWarning?: string;
  dailyKcalTotal?: number;
  kcalTarget?: number;
}

export async function analyzeMeal(
  input: AnalyzeMealInput,
  deps: {
    vertexAI: VertexAIClient;
    mealRepo: MealRepository;
    getRules: (userId: string) => Promise<DietRule[]>;
  }
): Promise<AnalyzeMealOutput> {
  const t0 = Date.now();
  const { imageBase64, userId, dietRules: overrideRules, dietText } = input;

  let rulesOverride: DietRule[] | undefined;
  if (overrideRules && overrideRules.length > 0) {
    rulesOverride = overrideRules;
    console.info('[analyze-meal] stage=rules_override rulesCount=', overrideRules.length);
  } else if (dietText?.trim()) {
    const tParse = Date.now();
    rulesOverride = await deps.vertexAI.parseDietText(dietText.trim());
    console.info('[analyze-meal] stage=parse_diet_text done in', Date.now() - tParse, 'ms rulesCount=', rulesOverride?.length ?? 0);
  }

  const getRules = rulesOverride
    ? async () => rulesOverride!
    : deps.getRules;

  const tReader = Date.now();
  console.info('[analyze-meal] stage=reader start (Vertex Vision)');
  const readerOut = await readerAgent(
    { imageBase64, userId },
    { vertexAI: deps.vertexAI }
  );
  console.info('[analyze-meal] stage=reader done in', Date.now() - tReader, 'ms ingredients=', readerOut.ingredients?.length ?? 0);

  const tProcessor = Date.now();
  console.info('[analyze-meal] stage=processor start');
  const processorOut = await processorAgent(
    {
      ingredients: readerOut.ingredients,
      estimatedKcal: readerOut.estimatedKcal,
      userId,
    },
    { mealRepo: deps.mealRepo, getRules, vertexAI: deps.vertexAI }
  );
  console.info('[analyze-meal] stage=processor done in', Date.now() - tProcessor, 'ms score=', processorOut.score);

  const tReporter = Date.now();
  const reporterOut = reporterAgent({
    score: processorOut.score,
    compliantItems: processorOut.compliantItems,
    nonCompliantItems: processorOut.nonCompliantItems,
    uncertainItems: processorOut.uncertainItems,
    suggestions: processorOut.suggestions,
    detalle: processorOut.detalle,
    ingredients: readerOut.ingredients,
    estimatedKcal: readerOut.estimatedKcal,
    calorieWarning: processorOut.calorieWarning,
    mealKcal: processorOut.mealKcal,
    dailyKcalTotal: processorOut.dailyKcalTotal,
    kcalTarget: processorOut.kcalTarget,
  });
  console.info('[analyze-meal] stage=reporter done in', Date.now() - tReporter, 'ms total=', Date.now() - t0, 'ms');

  return {
    score: reporterOut.score,
    compliantItems: reporterOut.compliantItems,
    nonCompliantItems: reporterOut.nonCompliantItems,
    uncertainItems: processorOut.uncertainItems,
    suggestions: reporterOut.suggestions,
    detalle: reporterOut.detalle,
    message: reporterOut.message,
    ingredients: readerOut.ingredients,
    estimatedKcal: readerOut.estimatedKcal,
    calorieWarning: reporterOut.calorieWarning,
    dailyKcalTotal: reporterOut.dailyKcalTotal,
    kcalTarget: reporterOut.kcalTarget,
  };
}
