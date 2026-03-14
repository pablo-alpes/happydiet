/**
 * Infrastructure: Vertex AI Gemini client for Vision
 * Uses Application Default Credentials (gcloud auth application-default login)
 * or GOOGLE_APPLICATION_CREDENTIALS for service account.
 */

import { VertexAI } from '@google-cloud/vertexai';

export interface VisionAnalysisResult {
  ingredients: string[];
  estimatedKcal?: number;
}

import type { DietRule } from '../domain/diet-rules.js';

export interface VertexAIClient {
  analyzeImage(imageBase64: string): Promise<VisionAnalysisResult>;
  parseDietText(text: string): Promise<DietRule[]>;
  parseDietImage(imageBase64: string): Promise<DietRule[]>;
  /** LLM semantic check: find ingredients that violate forbidden rules (e.g. bread contains gluten) */
  checkComplianceSemantic(ingredients: string[], forbiddenItems: string[]): Promise<string[]>;
  /** Generate explanation for a meal concept (prompt, why compliant, tips) */
  explainMealConcept(mealType: string, prompt: string, allowed: string[], forbidden: string[]): Promise<string>;
}

const DIET_PARSE_PROMPT = `Extract diet rules from this text. Return a JSON array. Each rule: {"type":"forbidden","items":["food1","food2"]} for not-allowed items.
Also use: {"type":"allowed","items":[...]} for allowed, {"type":"limit","items":[...],"maxPerDay":N,"unit":"servings"} for limits, {"type":"note","text":"..."} for notes.
Extract from: no X, evitar X, prohibido X, sin X, avoid X. Support any language. Return ONLY a valid JSON array, no markdown or extra text.`;

const DIET_IMAGE_PROMPT = `Extract diet rules from this image (handwritten, printed, or screenshot). Return a JSON array.
Rules: {"type":"forbidden","items":["food1","food2"]} for not-allowed, {"type":"allowed","items":[...]} for allowed, {"type":"limit","items":[...],"maxPerDay":N,"unit":"servings"}, {"type":"note","text":"..."}.
Support any language. Return ONLY a valid JSON array, no markdown or extra text.`;

/** Meal image → ingredients. Composite dishes (parrillada, paella) are broken into components for rule matching. */
const VISION_PROMPT = `Analyze this meal image. Return a JSON object with exactly:
{
  "ingredients": ["item1", "item2", ...],
  "estimatedKcal": number or null
}
List each food item separately. For composite dishes (parrillada, asado, mixed grill, stir-fry, paella, etc.), break them into their actual components so the rule engine can evaluate each: e.g. "parrillada" → ["grilled beef", "chorizo", "morcilla", "bell peppers", "onions"]; "paella" → ["rice", "shrimp", "chicken", "peas", "saffron"]. Be specific: "grilled chicken" not "chicken", "fried potatoes" not "potatoes". Estimate total kcal if possible. No other text.`;

function normalizeParsedRules(arr: unknown[]): DietRule[] {
  const result: DietRule[] = [];
  for (const r of arr) {
    if (r == null || typeof r !== 'object') continue;
    const o = r as Record<string, unknown>;
    if (o.type === 'note' && typeof o.text === 'string') {
      result.push({ type: 'note', text: o.text });
      continue;
    }
    if (!Array.isArray(o.items)) continue;
    const items = o.items.filter((x): x is string => typeof x === 'string');
    if (items.length === 0) continue;
    if (o.type === 'forbidden') {
      result.push({ type: 'forbidden', items, reason: typeof o.reason === 'string' ? o.reason : undefined });
    } else if (o.type === 'allowed') {
      result.push({ type: 'allowed', items, maxPortion: typeof o.maxPortion === 'string' ? o.maxPortion : undefined });
    } else if (o.type === 'limit' && typeof o.maxPerDay === 'number' && typeof o.unit === 'string') {
      result.push({ type: 'limit', items, maxPerDay: o.maxPerDay, unit: o.unit });
    } else {
      result.push({ type: 'forbidden', items, reason: typeof o.reason === 'string' ? o.reason : undefined });
    }
  }
  return result;
}

/** Extract JSON array from model output - handles markdown, extra text, malformed JSON */
function extractJsonArray(raw: string): unknown[] {
  let cleaned = raw.trim();
  const codeBlock = cleaned.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (codeBlock) cleaned = codeBlock[1].trim();
  const arrayMatch = cleaned.match(/\[[\s\S]*\]/);
  if (!arrayMatch) return [];
  try {
    const parsed = JSON.parse(arrayMatch[0]);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    try {
      const fixed = arrayMatch[0].replace(/,(\s*[}\]])/g, '$1').replace(/(['"])\s*:\s*(['"])/g, '$1:$2');
      const parsed = JSON.parse(fixed);
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  }
}

/** Fallback: parse plain text into forbidden rules when JSON fails */
function fallbackParseToForbidden(text: string): DietRule[] {
  const items: string[] = [];
  const combined = text.replace(/\n/g, ', ').replace(/\s+/g, ' ');
  for (const part of combined.split(/[,;]|(?:and|y|e)\s+/i)) {
    const cleaned = part
      .replace(/^(?:no|evitar|prohibido|sin|avoid|forbidden|not allowed|el|la|los|las)[:\s]+/i, '')
      .replace(/^[-*•]\s*/, '')
      .trim();
    if (cleaned.length >= 2 && cleaned.length <= 40 && !/^\d+$|^[\[\]{}"]+$/.test(cleaned)) {
      items.push(cleaned);
    }
  }
  const unique = [...new Set(items)].slice(0, 30);
  return unique.length > 0 ? [{ type: 'forbidden' as const, items: unique }] : [];
}

const VERTEX_AI_MAX_RETRIES = 3;
const VERTEX_AI_INITIAL_DELAY_MS = 500;

async function withRetry<T>(fn: () => Promise<T>, context: string): Promise<T> {
  let lastErr: unknown;
  for (let attempt = 0; attempt < VERTEX_AI_MAX_RETRIES; attempt++) {
    try {
      return await fn();
    } catch (err) {
      lastErr = err;
      const msg = err instanceof Error ? err.message : String(err);
      const isRetryable =
        msg.includes('429') ||
        msg.includes('503') ||
        msg.includes('RESOURCE_EXHAUSTED') ||
        msg.includes('UNAVAILABLE') ||
        msg.includes('DEADLINE_EXCEEDED');
      if (attempt < VERTEX_AI_MAX_RETRIES - 1 && isRetryable) {
        const delay = VERTEX_AI_INITIAL_DELAY_MS * Math.pow(2, attempt);
        console.warn(`[vertex-ai] ${context} attempt ${attempt + 1} failed, retrying in ${delay}ms`, msg);
        await new Promise((r) => setTimeout(r, delay));
      } else {
        break;
      }
    }
  }
  console.error(`[vertex-ai] ${context} failed after ${VERTEX_AI_MAX_RETRIES} attempts`, lastErr);
  throw lastErr;
}

export function createVertexAIClient(config: {
  projectId: string;
  location: string;
  model?: string;
}): VertexAIClient {
  const vertexAI = new VertexAI({
    project: config.projectId,
    location: config.location,
  });

  const modelId = config.model ?? 'gemini-2.5-flash';
  const model = vertexAI.getGenerativeModel({ model: modelId });
  const jsonModel = vertexAI.getGenerativeModel({
    model: modelId,
    generationConfig: { responseMimeType: 'application/json', maxOutputTokens: 4096 },
  });

  return {
    async analyzeImage(imageBase64: string): Promise<VisionAnalysisResult> {
      return withRetry(async () => {
        const imagePart = {
          inlineData: {
            data: imageBase64.replace(/^data:image\/\w+;base64,/, ''),
            mimeType: 'image/jpeg',
          },
        };

        const result = await model.generateContent({
          contents: [{ role: 'user', parts: [{ text: VISION_PROMPT }, imagePart] }],
        });

        const response = result.response;
        const text = response.candidates?.[0]?.content?.parts?.[0]?.text?.trim();

        if (!text) {
          throw new Error('Vision failed: no response from model');
        }

        const jsonMatch = text.match(/\{[\s\S]*\}/);
        const parsed = jsonMatch ? JSON.parse(jsonMatch[0]) : { ingredients: [], estimatedKcal: null };

        console.info('[vertex-ai] analyzeImage', {
          model: modelId,
          ingredientsCount: Array.isArray(parsed.ingredients) ? parsed.ingredients.length : 0,
        });

        return {
          ingredients: Array.isArray(parsed.ingredients) ? parsed.ingredients : [],
          estimatedKcal: typeof parsed.estimatedKcal === 'number' ? parsed.estimatedKcal : undefined,
        };
      }, 'analyzeImage');
    },
    async parseDietText(text: string): Promise<DietRule[]> {
      return withRetry(async () => {
        const result = await jsonModel.generateContent({
          contents: [{ role: 'user', parts: [{ text: `${DIET_PARSE_PROMPT}\n\nDiet: ${text}` }] }],
        });
        const response = result.response;
        const out = response.candidates?.[0]?.content?.parts?.[0]?.text?.trim();
        if (!out) throw new Error('Parse failed: no response');
        const arr = extractJsonArray(out);
        let rules = normalizeParsedRules(arr);
        if (rules.length === 0) {
          rules = fallbackParseToForbidden(out + '\n' + text);
          if (rules.length > 0) console.info('[vertex-ai] parseDietText fallback', { rulesCount: rules.length });
        }
        if (rules.length === 0) throw new Error('Parse failed: no rules extracted');
        console.info('[vertex-ai] parseDietText', { rulesCount: rules.length });
        return rules;
      }, 'parseDietText');
    },
    async parseDietImage(imageBase64: string): Promise<DietRule[]> {
      return withRetry(async () => {
        const imagePart = {
          inlineData: {
            data: imageBase64.replace(/^data:image\/\w+;base64,/, ''),
            mimeType: 'image/jpeg',
          },
        };
        const result = await jsonModel.generateContent({
          contents: [{ role: 'user', parts: [{ text: DIET_IMAGE_PROMPT }, imagePart] }],
        });
        const out = result.response.candidates?.[0]?.content?.parts?.[0]?.text?.trim();
        if (!out) throw new Error('Parse failed: no response');
        const arr = extractJsonArray(out);
        let rules = normalizeParsedRules(arr);
        if (rules.length === 0) {
          rules = fallbackParseToForbidden(out);
          if (rules.length > 0) console.info('[vertex-ai] parseDietImage fallback', { rulesCount: rules.length });
        }
        if (rules.length === 0) throw new Error('Parse failed: no rules extracted from image');
        console.info('[vertex-ai] parseDietImage', { rulesCount: rules.length });
        return rules;
      }, 'parseDietImage');
    },
    async explainMealConcept(mealType: string, prompt: string, allowed: string[], forbidden: string[]): Promise<string> {
      return withRetry(async () => {
        const text = `You are a diet coach. A user generated a ${mealType} meal image with this concept: "${prompt}".

Their diet: PREFER ${allowed.length ? allowed.join(', ') : 'vegetables, lean protein, whole grains'}. AVOID ${forbidden.length ? forbidden.join(', ') : 'sugar, fried food'}.

Write 2-3 short sentences: (1) What this meal includes and why it fits their plan. (2) One practical tip (e.g. prep ahead, portion size). Be warm and concise. No bullet points.`;
        const result = await model.generateContent({ contents: [{ role: 'user', parts: [{ text }] }] });
        const out = result.response.candidates?.[0]?.content?.parts?.[0]?.text?.trim();
        return out || 'This meal fits your plan. Enjoy!';
      }, 'explainMealConcept');
    },
    async checkComplianceSemantic(ingredients: string[], forbiddenItems: string[]): Promise<string[]> {
      if (ingredients.length === 0 || forbiddenItems.length === 0) return [];
      return withRetry(async () => {
        const prompt = `Given these meal ingredients: [${ingredients.join(', ')}]
And these FORBIDDEN diet items (not allowed): [${forbiddenItems.join(', ')}]

Which ingredients are non-compliant? Consider: (1) direct match, (2) ingredient contains or is made from a forbidden item (e.g. bread contains gluten, pasta contains wheat).
Return a JSON array of ONLY the non-compliant ingredient names. If all are compliant, return [].
Example: ["bread","pasta"] or []
No other text.`;
        const result = await model.generateContent({ contents: [{ role: 'user', parts: [{ text: prompt }] }] });
        const out = result.response.candidates?.[0]?.content?.parts?.[0]?.text?.trim();
        if (!out) return [];
        const jsonMatch = out.match(/\[[\s\S]*\]/);
        const arr = jsonMatch ? JSON.parse(jsonMatch[0]) : [];
        const nonCompliant = Array.isArray(arr) ? arr.filter((x): x is string => typeof x === 'string') : [];
        console.info('[vertex-ai] checkComplianceSemantic', { ingredientsCount: ingredients.length, nonCompliantCount: nonCompliant.length });
        return nonCompliant;
      }, 'checkComplianceSemantic');
    },
  };
}
