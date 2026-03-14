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
  getDailyKcal(userId: string): Promise<number>;
  deleteAllByUser(userId: string): Promise<number>;
}

export interface DietRulesRepository {
  getByUser(userId: string): Promise<DietRule[]>;
  saveRules(userId: string, rules: DietRule[], name?: string): Promise<void>;
}

export interface TaskRecord {
  id?: string;
  userId: string;
  task: string;
  due: string;
  done: boolean;
  createdAt?: Date;
}

export interface TasksRepository {
  listByUser(userId: string): Promise<TaskRecord[]>;
  add(userId: string, task: string, due: string): Promise<TaskRecord>;
  toggleDone(userId: string, taskId: string): Promise<void>;
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

    async getDailyKcal(userId) {
      const now = new Date();
      const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const snapshot = await mealsDb
        .collection('meals')
        .where('userId', '==', userId)
        .where('timestamp', '>=', startOfDay)
        .get();

      return snapshot.docs.reduce((sum, doc) => {
        const kcal = doc.data().estimatedKcal;
        return sum + (typeof kcal === 'number' ? kcal : 0);
      }, 0);
    },

    async deleteAllByUser(userId: string) {
      const snapshot = await mealsDb.collection('meals').where('userId', '==', userId).get();
      const batch = mealsDb.batch();
      for (const doc of snapshot.docs) {
        batch.delete(doc.ref);
      }
      await batch.commit();
      const count = snapshot.docs.length;
      if (count > 0) {
        console.info('[persistence] meals.deleteAllByUser', { userId, count });
      }
      return count;
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

  const tasksDb = new Firestore({
    projectId: config.projectId,
    ...(config.mealsDatabaseId && { databaseId: config.mealsDatabaseId }),
  });

  const tasksRepo: TasksRepository = {
    async listByUser(userId) {
      const snapshot = await tasksDb
        .collection('tasks')
        .where('userId', '==', userId)
        .limit(100)
        .get();

      const docs = snapshot.docs
        .sort((a, b) => (b.data().createdAt?.toMillis?.() ?? 0) - (a.data().createdAt?.toMillis?.() ?? 0))
        .map((doc) => {
        const d = doc.data();
        return {
          id: doc.id,
          userId: d.userId,
          task: d.task ?? '',
          due: d.due ?? '',
          done: d.done ?? false,
          createdAt: d.createdAt?.toDate?.() ?? d.createdAt,
        } as TaskRecord;
      });
      return docs;
    },
    async add(userId, task, due) {
      const ref = await tasksDb.collection('tasks').add({
        userId,
        task: task.trim(),
        due: (due ?? '').trim(),
        done: false,
        createdAt: new Date(),
      });
      const doc = await ref.get();
      const d = doc.data()!;
      return {
        id: ref.id,
        userId: d.userId,
        task: d.task,
        due: d.due,
        done: d.done,
        createdAt: d.createdAt?.toDate?.(),
      } as TaskRecord;
    },
    async toggleDone(userId, taskId) {
      const ref = tasksDb.collection('tasks').doc(taskId);
      const doc = await ref.get();
      if (!doc.exists || doc.data()?.userId !== userId) return;
      const current = doc.data()?.done ?? false;
      await ref.update({ done: !current });
    },
  };

  return { mealRepo, dietRulesRepo, tasksRepo };
}
