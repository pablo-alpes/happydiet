/**
 * Agent 1 — Reader: Image → Vision → structured text
 * For meal: returns ingredients. For rules: parses and persists to diet_rules.
 */

import type { VertexAIClient } from '../infrastructure/vertex-ai-client.js';

export interface ReaderInput {
  imageBase64: string;
  userId: string;
}

export interface ReaderOutput {
  ingredients: string[];
  estimatedKcal?: number;
}

export async function readerAgent(
  input: ReaderInput,
  deps: { vertexAI: VertexAIClient }
): Promise<ReaderOutput> {
  const visionResult = await deps.vertexAI.analyzeImage(input.imageBase64);
  return {
    ingredients: visionResult.ingredients,
    estimatedKcal: visionResult.estimatedKcal,
  };
}
