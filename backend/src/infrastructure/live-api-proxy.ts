/**
 * WebSocket proxy for Gemini Live API (Vertex AI).
 * Clients connect to /live; we proxy to Vertex AI with GCP auth.
 * Tool calls (analyze_meal) are intercepted and executed by our backend.
 */

import WebSocket from 'ws';
import { GoogleAuth } from 'google-auth-library';
import type { Server } from 'http';
import type { VertexAIClient } from './vertex-ai-client.js';
import type { MealRepository, DietRulesRepository } from './firestore-repository.js';
import { analyzeMeal } from '../application/analyze-meal.js';

const LIVE_MODEL = 'gemini-live-2.5-flash-native-audio';

function getLiveWsUrl(projectId: string, location: string): string {
  return `wss://${location}-aiplatform.googleapis.com/ws/google.cloud.aiplatform.v1.LlmBidiService/BidiGenerateContent`;
}

interface UserContext {
  rules?: string;
  weight?: string;
  meals?: string;
  trend?: string;
  feedback?: string;
  checkins?: string;
  tasks?: string;
  targets?: string;
  profile?: string;
}

function buildSetupWithTools(projectId: string, location: string, context?: UserContext | null) {
  const model = `projects/${projectId}/locations/${location}/publishers/google/models/${LIVE_MODEL}`;
  let systemText = `You are HappyDiet, a warm, fluent diet coach. Talk naturally — like a supportive friend who happens to know nutrition. Be interactive: ask follow-ups, suggest next steps, give tasks to keep the user engaged.

- Be natural and flowing. Use contractions, short sentences when it fits, and a friendly tone.
- When they share a meal photo, call the analyze_meal tool with the image. You receive structured data (score, compliant, non-compliant, uncertain items). Speak in your own voice — don't read the data verbatim. Always state clearly if the meal is good or off plan. For uncertain items (not in their diet rules), use your nutrition knowledge and mention if something might be a concern. Be encouraging but honest.
- Answer any question about their diet, food, progress, weight, or self-perception. Ask about weight and how they feel when relevant — e.g. "How's your weight today?" or "How do you feel after that meal?"
- Give tasks to keep them engaged. Call give_task when you assign a challenge: "Log your weight tomorrow morning", "Try a compliant breakfast 5 days this week", "Share your next meal photo". Be specific and encouraging.
- Ask follow-up questions. Don't just answer — invite them to share more. "What was difficult about that?" "How did you feel after?"
- Keep responses concise but not stiff. Avoid bullet points unless listing options. Sound human.`;
  if (context && (context.rules || context.weight || context.meals || context.trend || context.feedback || context.checkins || context.tasks || context.targets || context.profile)) {
    systemText += `\n\nYou have this user's data. Use it to ground your answers:\n\n`;
    if (context.profile) systemText += `DIET BEHAVIOUR PROFILE (use to guide and tailor advice):\n${context.profile}\n\n`;
    if (context.targets) systemText += `USER TARGETS:\n${context.targets}\n\n`;
    if (context.rules) systemText += `DIET RULES:\n${context.rules}\n\n`;
    if (context.weight) systemText += `WEIGHT LOG:\n${context.weight}\n\n`;
    if (context.checkins) systemText += `RECENT CHECK-INS (weight, energy, mood, hunger from meals):\n${context.checkins}\n\n`;
    if (context.meals) systemText += `RECENT MEALS:\n${context.meals}\n\n`;
    if (context.trend) systemText += `COMPLIANCE TREND (last 14 days):\n${context.trend}\n\n`;
    if (context.feedback) systemText += `COMPLIANCE FEEDBACK (what they find difficult):\n${context.feedback}\n\n`;
    if (context.tasks) systemText += `ACTIVE TASKS (you assigned these — ask about progress):\n${context.tasks}\n\n`;
    systemText += `When they ask about diet, weight, self-perception, progress, targets, or difficulties, use this data. Reference their profile to tailor advice — e.g. if they slip on weekends, suggest weekend strategies. Reference their targets to encourage them. Ask about weight and how they feel. Explain restrictions in plain language.`;
  }
  return {
    setup: {
      model,
      generationConfig: {
        responseModalities: ['audio'],
        speechConfig: {
          voiceConfig: { prebuiltVoiceConfig: { voiceName: 'Puck' } },
        },
      },
      outputAudioTranscription: {},
      inputAudioTranscription: {},
      realtimeInputConfig: {
        automaticActivityDetection: {
          disabled: false,
          silenceDurationMs: 2000,
          prefixPaddingMs: 500,
        },
      },
      systemInstruction: {
        parts: [{ text: systemText }],
      },
      tools: [
        {
          functionDeclarations: [
            {
              name: 'analyze_meal',
              description: 'Analyze a meal image for diet compliance. Returns score, verdict (good/moderate/off_plan), compliantItems, nonCompliantItems, uncertainItems (not in diet rules — use your judgment), suggestions. Speak in your own voice; always state if meal is good or off plan.',
              parameters: {
                type: 'object',
                properties: {
                  image_base64: { type: 'string', description: 'Base64-encoded JPEG image' },
                  user_id: { type: 'string', description: 'User ID (default: demo)' },
                },
                required: ['image_base64'],
              },
            },
            {
              name: 'give_task',
              description: 'Give the user a task to keep them engaged. Call when you want to assign a challenge, e.g. "Log your weight tomorrow", "Eat a compliant breakfast 5 days this week", "Share a meal photo tomorrow".',
              parameters: {
                type: 'object',
                properties: {
                  task: { type: 'string', description: 'The task text' },
                  due: { type: 'string', description: 'Optional due date or timeframe, e.g. "tomorrow", "this week"' },
                },
                required: ['task'],
              },
            },
          ],
        },
      ],
    },
  };
}

function extractImageBase64(args: Record<string, unknown>): string | null {
  if (typeof args?.image_base64 === 'string') return args.image_base64;
  const inline = args?.inline_data as { data?: string } | undefined;
  if (inline?.data && typeof inline.data === 'string') return inline.data;
  return null;
}

async function executeAnalyzeMeal(
  args: Record<string, unknown>,
  deps: { vertexAI: VertexAIClient; mealRepo: MealRepository; dietRulesRepo: DietRulesRepository }
) {
  const imageBase64 = extractImageBase64(args);
  const userId = (args?.user_id as string) ?? 'demo';
  if (!imageBase64) {
    return { error: 'Missing image_base64 or inline_data' };
  }
  const result = await analyzeMeal(
    { imageBase64, userId },
    {
      vertexAI: deps.vertexAI,
      mealRepo: deps.mealRepo,
      getRules: (uid) => deps.dietRulesRepo.getByUser(uid),
    }
  );
  return {
    score: result.score,
    verdict: result.score >= 80 ? 'good' : result.score >= 50 ? 'moderate' : 'off_plan',
    compliantItems: result.compliantItems,
    nonCompliantItems: result.nonCompliantItems,
    uncertainItems: result.uncertainItems ?? [],
    suggestions: result.suggestions,
    ingredients: result.ingredients,
    estimatedKcal: result.estimatedKcal,
    agentInstructions: 'Speak naturally. State overall compliance (good/moderate/off plan). Mention watch-outs for non-compliant items. For uncertain items (not in diet rules), use your judgment — flag potential concerns. Be encouraging.',
  };
}

export interface LiveProxyDeps {
  projectId: string;
  location: string;
  vertexAI: VertexAIClient | null;
  mealRepo: MealRepository;
  dietRulesRepo: DietRulesRepository;
}

export function attachLiveProxy(server: Server, deps: LiveProxyDeps): void {
  const { projectId, location, vertexAI, mealRepo, dietRulesRepo } = deps;
  const wsUrl = getLiveWsUrl(projectId, location);
  const auth = new GoogleAuth({ scopes: ['https://www.googleapis.com/auth/cloud-platform'] });

  const wss = new WebSocket.Server({ server, path: '/live' });

  wss.on('connection', async (clientWs) => {
    if (!vertexAI) {
      try {
        clientWs.send(JSON.stringify({ type: 'error', message: 'Backend not configured. Set GOOGLE_CLOUD_PROJECT and run with GCP.' }));
      } catch (_) {}
      clientWs.close(1011, 'Backend not configured');
      return;
    }
    let serverWs: WebSocket | null = null;
    let pendingMessage: WebSocket.Data | null = null;

    const connectToVertex = async (context: UserContext | null) => {
      try {
        const token = await auth.getAccessToken();
        if (!token) {
          try {
            clientWs.send(JSON.stringify({ type: 'error', message: 'Failed to get GCP token. Run: gcloud auth application-default login' }));
          } catch (_) {}
          clientWs.close(1011, 'Failed to get GCP token');
          return;
        }
        serverWs = new WebSocket(wsUrl, {
          headers: { Authorization: `Bearer ${token}` },
        });
        await new Promise<void>((resolve, reject) => {
          serverWs!.on('open', resolve);
          serverWs!.on('error', reject);
        });
        const setupMsg = buildSetupWithTools(projectId, location, context);
        serverWs.send(JSON.stringify(setupMsg));
        if (pendingMessage) {
          const str = typeof pendingMessage === 'string' ? pendingMessage : pendingMessage.toString();
          let parsed: Record<string, unknown>;
          try {
            parsed = JSON.parse(str);
          } catch {
            parsed = {};
          }
          if (!parsed.setup && parsed.type !== 'context') {
            serverWs!.send(str);
          }
          pendingMessage = null;
        }
        serverWs.on('message', async (data: WebSocket.Data) => {
          const str = typeof data === 'string' ? data : data.toString();
          let msg: Record<string, unknown>;
          try {
            msg = JSON.parse(str);
          } catch {
            clientWs.send(str);
            return;
          }
          const m = msg as Record<string, unknown>;
          const tc = (m.toolCall ?? m.tool_call) as { functionCalls?: unknown[]; function_calls?: unknown[] } | undefined;
          const sc = (m.serverContent ?? m.server_content) as { toolCall?: { functionCalls?: unknown[] }; tool_call?: { function_calls?: unknown[] } } | undefined;
          const fc = tc?.functionCalls ?? tc?.function_calls ?? sc?.toolCall?.functionCalls ?? sc?.tool_call?.function_calls;
          const toolCall = (Array.isArray(fc) ? fc[0] : undefined) as { name?: string; args?: Record<string, unknown> } | undefined;
          if (toolCall?.name === 'analyze_meal') {
            const args = toolCall.args ?? {};
            const result = await executeAnalyzeMeal(args, { vertexAI, mealRepo, dietRulesRepo });
            serverWs?.send(JSON.stringify({
              toolResponse: {
                functionResponses: [{ name: 'analyze_meal', response: result }],
              },
            }));
            return;
          }
          if (toolCall?.name === 'give_task') {
            const args = toolCall.args ?? {};
            const task = (args.task as string) || '';
            const due = (args.due as string) || '';
            if (task) {
              clientWs.send(JSON.stringify({ type: 'task', task, due }));
            }
            serverWs?.send(JSON.stringify({
              toolResponse: {
                functionResponses: [{ name: 'give_task', response: { success: true } }],
              },
            }));
            return;
          }
          clientWs.send(str);
        });
        serverWs.on('close', (code, reason) => {
          const msg = reason?.toString() || `Vertex closed (${code})`;
          console.error('[live-proxy] Vertex closed:', code, msg);
          try {
            clientWs.send(JSON.stringify({ type: 'error', message: msg }));
          } catch (_) {}
          clientWs.close(1011, msg);
        });
        serverWs.on('error', (err) => {
          const msg = (err as Error)?.message || 'Upstream error';
          console.error('[live-proxy] Vertex error:', err);
          try {
            clientWs.send(JSON.stringify({ type: 'error', message: msg }));
          } catch (_) {}
          clientWs.close(1011, msg);
        });
        clientWs.on('close', () => serverWs?.close());
      } catch (err) {
        const msg = (err as Error)?.message || 'Proxy failed';
        console.error('[live-proxy]', err);
        try {
          clientWs.send(JSON.stringify({ type: 'error', message: msg }));
        } catch (_) {}
        clientWs.close(1011, msg);
      }
    };

    const handleFirstMessage = (data: WebSocket.Data) => {
      const str = typeof data === 'string' ? data : data.toString();
      let parsed: Record<string, unknown>;
      try {
        parsed = JSON.parse(str);
      } catch {
        pendingMessage = data;
        void connectToVertex(null);
        return;
      }
      if (parsed.type === 'context' && parsed.payload && typeof parsed.payload === 'object') {
        const ctx = parsed.payload as UserContext;
        void connectToVertex(ctx);
      } else {
        pendingMessage = data;
        void connectToVertex(null);
      }
    };

    let firstMessage = true;
    clientWs.on('message', (data: WebSocket.Data) => {
      if (firstMessage) {
        firstMessage = false;
        handleFirstMessage(data);
        return;
      }
      if (serverWs?.readyState === WebSocket.OPEN) {
        const str = typeof data === 'string' ? data : data.toString();
        let parsed: Record<string, unknown>;
        try {
          parsed = JSON.parse(str);
        } catch {
          serverWs.send(str);
          return;
        }
        if (parsed.setup) return;
        if (parsed.realtimeInput) {
          const ri = parsed.realtimeInput as Record<string, unknown>;
          const vertexRi: Record<string, unknown> = {};
          if (ri.audioStreamEnd !== undefined) vertexRi.audio_stream_end = ri.audioStreamEnd;
          if (ri.audio) {
            const a = ri.audio as Record<string, unknown>;
            vertexRi.audio = { data: a.data, mime_type: a.mimeType ?? a.mime_type };
          }
          if (ri.mediaChunks) {
            vertexRi.media_chunks = (ri.mediaChunks as Array<Record<string, unknown>>).map((c) => ({
              data: c.data,
              mime_type: c.mimeType ?? c.mime_type,
            }));
          }
          serverWs!.send(JSON.stringify({ realtime_input: vertexRi }));
        } else {
          serverWs!.send(str);
        }
      } else {
        pendingMessage = data;
      }
    });
  });
}
