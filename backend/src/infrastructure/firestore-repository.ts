/**
 * Infrastructure: Firestore adapters for meals and diet rules
 * Includes retry with exponential backoff and structured logging.
 */

import { Firestore } from '@google-cloud/firestore';
import type { MealRecord } from '../domain/meal.js';
import type { DietRule } from '../domain/diet-rules.js';

/** Recursively remove undefined values; Firestore rejects undefined. */
function stripUndefined<T>(obj: T): T {
  if (obj === null || obj === undefined) return obj;
  if (Array.isArray(obj)) return obj.map(stripUndefined) as T;
  if (typeof obj === 'object') {
    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(obj)) {
      if (v !== undefined) out[k] = stripUndefined(v);
    }
    return out as T;
  }
  return obj;
}

const MAX_RETRIES = 3;
const INITIAL_DELAY_MS = 100;

async function withRetry<T>(fn: () => Promise<T>, context: string): Promise<T> {
  let lastErr: unknown;
  for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
    try {
      return await fn();
    } catch (err) {
      lastErr = err;
      if (attempt < MAX_RETRIES - 1) {
        const delay = INITIAL_DELAY_MS * Math.pow(2, attempt);
        console.warn(`[persistence] ${context} attempt ${attempt + 1} failed, retrying in ${delay}ms`, err);
        await new Promise((r) => setTimeout(r, delay));
      }
    }
  }
  console.error(`[persistence] ${context} failed after ${MAX_RETRIES} attempts`, lastErr);
  throw lastErr;
}

export interface MealRepository {
  save(meal: Omit<MealRecord, 'id'>): Promise<void>;
  listByUser(userId: string): Promise<MealRecord[]>;
}

export interface DietRulesRepository {
  getByUser(userId: string): Promise<DietRule[]>;
  saveRules(userId: string, rules: DietRule[], name?: string): Promise<void>;
}

export function createFirestoreRepositories(config: {
  projectId: string;
  /** Database for meals (default: "(default)") */
  mealsDatabaseId?: string;
  /** Database for diet rules (default: "(default)") */
  rulesDatabaseId?: string;
}) {
  const mealsDb = new Firestore({
    projectId: config.projectId,
    ...(config.mealsDatabaseId && { databaseId: config.mealsDatabaseId }),
  });
  const rulesDb = new Firestore({
    projectId: config.projectId,
    ...(config.rulesDatabaseId && { databaseId: config.rulesDatabaseId }),
  });

  const mealRepo: MealRepository = {
    async save(meal) {
      const doc = {
        ...meal,
        timestamp: meal.timestamp instanceof Date ? meal.timestamp : new Date(meal.timestamp),
      };
      await withRetry(
        async () => {
          const ref = await mealsDb.collection('meals').add(doc);
          console.info('[persistence] meals.write', { docId: ref.id, userId: meal.userId });
        },
        'meals.save'
      );
    },
    async listByUser(userId) {
      const snapshot = await mealsDb
        .collection('meals')
        .where('userId', '==', userId)
        .limit(50)
        .get();

      const docs = snapshot.docs.sort(
        (a, b) => (b.data().timestamp?.toMillis?.() ?? 0) - (a.data().timestamp?.toMillis?.() ?? 0)
      );

      return docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
        timestamp: doc.data().timestamp?.toDate?.() ?? doc.data().timestamp,
      })) as MealRecord[];
    },
  };

  const dietRulesRepo: DietRulesRepository = {
    async getByUser(userId) {
      const snapshot = await rulesDb
        .collection('diet_rules')
        .where('userId', '==', userId)
        .limit(10)
        .get();

      const sorted = snapshot.docs.sort(
        (a, b) => (b.data().version ?? 0) - (a.data().version ?? 0)
      );
      const doc = sorted[0];
      if (!doc) return [];
      const data = doc.data();
      return data.rules ?? [];
    },
    async saveRules(userId, rules, name = 'My diet') {
      const sanitized = stripUndefined(rules);
      await withRetry(
        async () => {
          const ref = await rulesDb.collection('diet_rules').add({
            userId,
            version: Date.now(),
            name,
            rules: sanitized,
            createdAt: new Date(),
          });
          console.info('[persistence] diet_rules.write', { docId: ref.id, userId, rulesCount: rules.length });
        },
        'diet_rules.save'
      );
    },
  };

  return { mealRepo, dietRulesRepo };
}
