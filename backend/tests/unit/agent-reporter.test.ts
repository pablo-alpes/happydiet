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
});
