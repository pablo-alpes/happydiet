import { describe, it, expect } from 'vitest';
import { reporterAgent } from '../../src/application/agent-reporter.js';

describe('reporterAgent', () => {
  it('returns high compliance message when score >= 80', () => {
    const out = reporterAgent({
      score: 85,
      compliantItems: ['salad'],
      nonCompliantItems: [],
      suggestions: [],
    });
    expect(out.message).toContain('Great job!');
    expect(out.message).toContain('85% compliant');
  });

  it('returns moderate message when 50 <= score < 80', () => {
    const out = reporterAgent({
      score: 60,
      compliantItems: [],
      nonCompliantItems: ['cake'],
      suggestions: [],
    });
    expect(out.message).toContain('Moderate compliance');
    expect(out.message).toContain('60%');
  });

  it('returns off-plan message when score < 50', () => {
    const out = reporterAgent({
      score: 30,
      compliantItems: [],
      nonCompliantItems: ['pizza', 'soda'],
      suggestions: [],
    });
    expect(out.message).toContain('Off plan');
    expect(out.message).toContain('30%');
  });

  it('includes good choices when compliantItems present', () => {
    const out = reporterAgent({
      score: 90,
      compliantItems: ['chicken', 'rice'],
      nonCompliantItems: [],
      suggestions: [],
    });
    expect(out.message).toContain('Good choices: chicken, rice');
  });

  it('includes watch out when nonCompliantItems present', () => {
    const out = reporterAgent({
      score: 40,
      compliantItems: [],
      nonCompliantItems: ['ice cream'],
      suggestions: [],
    });
    expect(out.message).toContain('Watch out: ice cream');
  });

  it('shows +N more suffix when many non-compliant items exist', () => {
    const out = reporterAgent({
      score: 20,
      compliantItems: [],
      nonCompliantItems: ['a', 'b', 'c', 'd', 'e'],
      suggestions: [],
    });
    expect(out.message).toContain('(+1 more)');
  });

  it('includes suggestions when not default "Keep up the good choices!"', () => {
    const out = reporterAgent({
      score: 50,
      compliantItems: [],
      nonCompliantItems: ['sugar'],
      suggestions: ['Try reducing sugar intake.'],
    });
    expect(out.message).toContain('Try reducing sugar intake');
  });

  it('excludes suggestions when default "Keep up the good choices!"', () => {
    const out = reporterAgent({
      score: 100,
      compliantItems: ['salad', 'fish'],
      nonCompliantItems: [],
      suggestions: ['Keep up the good choices!'],
    });
    expect(out.message).not.toContain('Keep up the good choices!');
    expect(out.message).toContain('Great job!');
  });

  it('returns Off plan message when score 0 with empty items', () => {
    const out = reporterAgent({
      score: 0,
      compliantItems: [],
      nonCompliantItems: [],
      suggestions: [],
    });
    expect(out.message).toContain('Off plan');
    expect(out.message).toContain('0%');
  });

  it('includes calorie warning when present', () => {
    const out = reporterAgent({
      score: 40,
      compliantItems: ['steak', 'sausage'],
      nonCompliantItems: [],
      suggestions: ['Extreme calorie intake (~4000 kcal).'],
      calorieWarning: 'This meal is ~4000 kcal — that is a calorie bomb.',
      mealKcal: 4000,
      dailyKcalTotal: 5000,
      kcalTarget: 2000,
    });
    expect(out.message).toContain('calorie bomb');
    expect(out.calorieWarning).toContain('calorie bomb');
    expect(out.mealKcal).toBe(4000);
    expect(out.dailyKcalTotal).toBe(5000);
    expect(out.kcalTarget).toBe(2000);
  });

  it('shows reasonable portion for low calorie meals without warning', () => {
    const out = reporterAgent({
      score: 100,
      compliantItems: ['salad', 'chicken'],
      nonCompliantItems: [],
      suggestions: ['Keep up the good choices!'],
      estimatedKcal: 450,
    });
    expect(out.message).toContain('reasonable portion');
  });

  it('does not show Keep it up when calorie warning is present', () => {
    const out = reporterAgent({
      score: 82,
      compliantItems: ['chicken'],
      nonCompliantItems: [],
      suggestions: [],
      calorieWarning: 'This meal is ~1000 kcal — a bit heavy.',
    });
    expect(out.message).toContain('a bit heavy');
    expect(out.message).not.toContain('Keep it up');
  });

  it('does not show reasonable portion when estimatedKcal is 0', () => {
    const out = reporterAgent({
      score: 100,
      compliantItems: ['salad'],
      nonCompliantItems: [],
      suggestions: ['Keep up the good choices!'],
      estimatedKcal: 0,
    });
    expect(out.message).not.toContain('reasonable portion');
  });

  it('does not show reasonable portion when estimatedKcal exceeds 800', () => {
    const out = reporterAgent({
      score: 100,
      compliantItems: ['salad'],
      nonCompliantItems: [],
      suggestions: ['Keep up the good choices!'],
      estimatedKcal: 900,
    });
    expect(out.message).not.toContain('reasonable portion');
  });

  it('suggests swapping off-plan items when both compliant and non-compliant present', () => {
    const out = reporterAgent({
      score: 60,
      compliantItems: ['chicken'],
      nonCompliantItems: ['cake'],
      suggestions: [],
    });
    expect(out.message).toContain('swap the off-plan items');
  });
});
