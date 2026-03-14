/**
 * Agent 3 — Reporter: Build compliance message; dashboard data
 */

export interface ReporterInput {
  score: number;
  compliantItems: string[];
  nonCompliantItems: string[];
  uncertainItems?: string[];
  suggestions: string[];
  detalle?: string;
  ingredients?: string[];
  estimatedKcal?: number;
  calorieWarning?: string;
  mealKcal?: number;
  dailyKcalTotal?: number;
  kcalTarget?: number;
}

export interface ReporterOutput {
  score: number;
  compliantItems: string[];
  nonCompliantItems: string[];
  suggestions: string[];
  detalle?: string;
  message: string;
  calorieWarning?: string;
  mealKcal?: number;
  dailyKcalTotal?: number;
  kcalTarget?: number;
}

export function reporterAgent(input: ReporterInput): ReporterOutput {
  const score = Math.round(input.score);
  const parts: string[] = [];

  if (score >= 80) {
    parts.push(`Great job! ${score}% compliant.`);
  } else if (score >= 50) {
    parts.push(`Moderate compliance (${score}%).`);
  } else {
    parts.push(`Off plan (${score}%).`);
  }

  if (input.calorieWarning) {
    parts.push(input.calorieWarning);
  } else if (input.estimatedKcal != null && input.estimatedKcal > 0 && input.estimatedKcal <= 800) {
    parts.push(`Estimated ${input.estimatedKcal} kcal — reasonable portion.`);
  }

  if (input.compliantItems.length > 0 && score >= 80) {
    const items = input.compliantItems.slice(0, 3).join(', ');
    parts.push(`Good choices: ${items}.`);
  }

  if (input.nonCompliantItems.length > 0) {
    const items = input.nonCompliantItems.slice(0, 4).join(', ');
    const extra = input.nonCompliantItems.length > 4 ? ` (+${input.nonCompliantItems.length - 4} more)` : '';
    parts.push(`Watch out: ${items}${extra} — these don't fit your plan.`);
  }

  const usefulSuggestions = input.suggestions.filter((s) => s && s !== 'Keep up the good choices!');
  if (usefulSuggestions.length > 0) {
    parts.push(usefulSuggestions[0]);
  } else if (input.nonCompliantItems.length > 0 && input.compliantItems.length > 0) {
    parts.push(`The rest looks good — swap the off-plan items next time for a stronger meal.`);
  } else if (score >= 80 && !input.calorieWarning) {
    parts.push(`Keep it up.`);
  }

  const message = parts.join(' ');

  return {
    score: input.score,
    compliantItems: input.compliantItems,
    nonCompliantItems: input.nonCompliantItems,
    suggestions: input.suggestions,
    detalle: input.detalle,
    message,
    calorieWarning: input.calorieWarning,
    mealKcal: input.mealKcal,
    dailyKcalTotal: input.dailyKcalTotal,
    kcalTarget: input.kcalTarget,
  };
}
