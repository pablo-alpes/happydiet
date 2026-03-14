/**
 * Unit tests for live-api-proxy: URL, image extraction, setup builder.
 */

import { describe, it, expect } from 'vitest';
import {
  getLiveWsUrl,
  extractImageBase64,
  buildSetupWithTools,
} from '../../src/infrastructure/live-api-proxy.js';

describe('live-api-proxy', () => {
  describe('getLiveWsUrl', () => {
    it('builds correct Vertex AI WebSocket URL', () => {
      const url = getLiveWsUrl('my-project', 'us-central1');
      expect(url).toBe(
        'wss://us-central1-aiplatform.googleapis.com/ws/google.cloud.aiplatform.v1.LlmBidiService/BidiGenerateContent'
      );
    });

    it('uses location in host', () => {
      const url = getLiveWsUrl('proj', 'europe-west1');
      expect(url).toContain('europe-west1-aiplatform');
    });
  });

  describe('extractImageBase64', () => {
    it('extracts image_base64 from args', () => {
      const args = { image_base64: 'abc123', user_id: 'demo' };
      expect(extractImageBase64(args)).toBe('abc123');
    });

    it('extracts from inline_data.data', () => {
      const args = { inline_data: { data: 'xyz789', mime_type: 'image/jpeg' } };
      expect(extractImageBase64(args)).toBe('xyz789');
    });

    it('returns null when no image', () => {
      expect(extractImageBase64({})).toBeNull();
      expect(extractImageBase64({ user_id: 'demo' })).toBeNull();
    });

    it('returns null for invalid args', () => {
      expect(extractImageBase64({ inline_data: {} })).toBeNull();
      expect(extractImageBase64({ inline_data: { data: 123 } })).toBeNull();
    });
  });

  describe('buildSetupWithTools', () => {
    it('includes model and tools', () => {
      const out = buildSetupWithTools('proj', 'us-central1');
      expect(out.setup).toBeDefined();
      expect(out.setup.model).toContain('proj');
      expect(out.setup.model).toContain('us-central1');
      expect(out.setup.tools).toBeDefined();
      const decls = out.setup.tools[0].function_declarations;
      expect(decls).toHaveLength(2);
      expect(decls.map((d: { name: string }) => d.name)).toContain('analyze_meal');
      expect(decls.map((d: { name: string }) => d.name)).toContain('give_task');
    });

    it('includes context in system instruction when provided', () => {
      const out = buildSetupWithTools('p', 'us', {
        rules: 'No sugar',
        profile: 'I slip on weekends',
      });
      const parts = out.setup.system_instruction.parts;
      expect(parts[0].text).toContain('No sugar');
      expect(parts[0].text).toContain('I slip on weekends');
    });

    it('omits context section when empty', () => {
      const out = buildSetupWithTools('p', 'us');
      const text = out.setup.system_instruction.parts[0].text;
      expect(text).not.toContain("You have this user's data");
    });

    it('uses snake_case for Vertex API compatibility (audio only)', () => {
      const out = buildSetupWithTools('proj', 'us-central1');
      expect(out.setup.generation_config).toBeDefined();
      expect(out.setup.generation_config.response_modalities).toEqual(['audio']);
      expect(out.setup.generation_config.speech_config).toBeDefined();
      expect(out.setup.generation_config.speech_config.voice_config.prebuilt_voice_config.voice_name).toBe('Puck');
    });
  });
});
