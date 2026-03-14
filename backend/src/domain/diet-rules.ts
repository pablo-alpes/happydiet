/**
 * Domain: Diet rules entities and value objects
 */

export interface ForbiddenRule {
  type: 'forbidden';
  items: string[];
  reason?: string;
}

export interface AllowedRule {
  type: 'allowed';
  items: string[];
  maxPortion?: string;
}

export interface LimitRule {
  type: 'limit';
  items: string[];
  maxPerDay: number;
  unit: string;
}

export interface NoteRule {
  type: 'note';
  text: string;
}

export type DietRule = ForbiddenRule | AllowedRule | LimitRule | NoteRule;

export interface DietRules {
  id?: string;
  userId: string;
  version: number;
  name: string;
  rules: DietRule[];
  kcalTarget?: number;
  createdAt?: Date;
  source?: string;
}
