/**
 * Google Cloud Text-to-Speech for dev playground TTS
 * Uses same ADC as Vertex AI (gcloud auth application-default login)
 */

import { TextToSpeechClient } from '@google-cloud/text-to-speech';

export interface GoogleTTSClient {
  synthesize(text: string): Promise<Buffer>;
}

export function createGoogleTTSClient(config: {
  projectId?: string;
}): GoogleTTSClient {
  const client = new TextToSpeechClient(
    config.projectId ? { projectId: config.projectId } : {}
  );

  return {
    async synthesize(text: string): Promise<Buffer> {
      const [response] = await client.synthesizeSpeech({
        input: { text },
        voice: {
          languageCode: 'en-US',
          name: 'en-US-Neural2-C', // Natural female voice
        },
        audioConfig: {
          audioEncoding: 'MP3',
          speakingRate: 0.95,
        },
      });

      if (!response.audioContent) {
        throw new Error('TTS: no audio returned');
      }
      return Buffer.isBuffer(response.audioContent)
        ? response.audioContent
        : Buffer.from(response.audioContent as Uint8Array);
    },
  };
}
