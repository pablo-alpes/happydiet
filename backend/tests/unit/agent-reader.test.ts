/**
 * Unit tests: Agent 1 — Reader
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { readerAgent } from '../../src/application/agent-reader.js';

const mockVisionResult = {
  ingredients: ['chicken', 'rice', 'salad'],
  estimatedKcal: 500,
};

const mockVertexAI = {
  analyzeImage: vi.fn().mockResolvedValue(mockVisionResult),
};

describe('readerAgent', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockVertexAI.analyzeImage.mockResolvedValue(mockVisionResult);
  });

  it('calls vertexAI.analyzeImage with imageBase64', async () => {
    const result = await readerAgent(
      { imageBase64: 'base64-data', userId: 'demo' },
      { vertexAI: mockVertexAI as any }
    );

    expect(mockVertexAI.analyzeImage).toHaveBeenCalledWith('base64-data');
    expect(result.ingredients).toEqual(['chicken', 'rice', 'salad']);
    expect(result.estimatedKcal).toBe(500);
  });

  it('returns ingredients and estimatedKcal from vision', async () => {
    const result = await readerAgent(
      { imageBase64: 'x', userId: 'user1' },
      { vertexAI: mockVertexAI as any }
    );

    expect(result.ingredients).toEqual(mockVisionResult.ingredients);
    expect(result.estimatedKcal).toBe(mockVisionResult.estimatedKcal);
  });

  it('handles vision result without estimatedKcal', async () => {
    mockVertexAI.analyzeImage.mockResolvedValueOnce({
      ingredients: ['apple'],
      estimatedKcal: undefined,
    });

    const result = await readerAgent(
      { imageBase64: 'x', userId: 'demo' },
      { vertexAI: mockVertexAI as any }
    );

    expect(result.ingredients).toEqual(['apple']);
    expect(result.estimatedKcal).toBeUndefined();
  });
});
