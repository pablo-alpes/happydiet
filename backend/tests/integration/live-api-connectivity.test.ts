/**
 * Integration test: Live API proxy.
 * Unit tests for live-api-proxy logic are in tests/unit/live-api-proxy.test.ts.
 * Full WebSocket connectivity is tested via npm run test:uat (scripts/uat-live.mjs).
 */

import { describe, it, expect } from 'vitest';
import { getLiveWsUrl } from '../../src/infrastructure/live-api-proxy.js';

describe('Live API connectivity', () => {
  it('getLiveWsUrl returns valid Vertex AI WebSocket URL', () => {
    const url = getLiveWsUrl('my-project', 'us-central1');
    expect(url).toContain('wss://');
    expect(url).toContain('us-central1-aiplatform');
    expect(url).toContain('BidiGenerateContent');
  });
});
