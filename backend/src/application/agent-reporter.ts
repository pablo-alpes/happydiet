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
}

export interface ReporterOutput {
  score: number;
  compliantItems: string[];
  nonCompliantItems: string[];
  suggestions: string[];
  detalle?: string;
  message: string;
}

export function reporterAgent(input: ReporterInput): ReporterOutput {
  const score = Math.round(input.score);
  const parts: string[] = [];

  // Overall compliance verdict
  if (score >= 90) {
    parts.push(`Strong compliance (${score}%).`);
  } else if (score >= 75) {
    parts.push(`Good overall (${score}%).`);
  } else if (score >= 50) {
    parts.push(`Moderate compliance (${score}%).`);
  } else {
    parts.push(`Off plan (${score}%).`);
  }

  // Watch outs — only the problematic items, actionable
  if (input.nonCompliantItems.length > 0) {
    const items = input.nonCompliantItems.slice(0, 4).join(', ');
    const extra = input.nonCompliantItems.length > 4 ? ` (+${input.nonCompliantItems.length - 4} more)` : '';
    parts.push(`Watch out: ${items}${extra} — these don't fit your plan.`);
  }

  // Smart suggestion (skip generic "Keep up the good choices")
  const usefulSuggestions = input.suggestions.filter((s) => s && s !== 'Keep up the good choices!');
  if (usefulSuggestions.length > 0) {
    parts.push(usefulSuggestions[0]);
  } else if (input.nonCompliantItems.length > 0 && input.compliantItems.length > 0) {
    parts.push(`The rest looks good — swap the off-plan items next time for a stronger meal.`);
  } else if (score >= 80) {
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
  };
}
