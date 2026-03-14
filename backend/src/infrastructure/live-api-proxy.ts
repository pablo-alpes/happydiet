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

export function getLiveWsUrl(projectId: string, location: string): string {
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

export function buildSetupWithTools(projectId: string, location: string, context?: UserContext | null) {
  const model = `projects/${projectId}/locations/${location}/publishers/google/models/${LIVE_MODEL}`;
  let systemText = `You are HappyDiet, a warm, fluent diet coach. Talk naturally — like a supportive friend who happens to know nutrition.

- Be natural and flowing. Use contractions, short sentences when it fits, and a friendly tone.
- When they share a meal photo, call the analyze_meal tool with the image. You receive structured data (score, compliant, non-compliant, uncertain items). Speak in your own voice — don't read the data verbatim. Always state clearly if the meal is good or off plan. For uncertain items (not in their diet rules), use your nutrition knowledge and mention if something might be a concern. Be encouraging but honest.
- Diet is the core. You may also suggest related habits that support behaviour change: sleep, exercise, stress management — when they clearly help diet success (e.g. sleep affects hunger, exercise supports metabolism). Keep diet primary.
- When the user shares a meal photo: give ONE focused response about the meal first. Don't add unrelated tangents in the same turn.
- Answer any question about their diet, food, progress, weight, or self-perception. Ask about weight and how they feel when relevant — e.g. "How's your weight today?" or "How do you feel after that meal?"
- Keep responses concise. One main point per turn. Avoid bullet points unless listing options. Sound human.
- When you call give_task: the task is added to the user's list automatically. Do NOT repeat or confirm the task in your spoken response — the user already sees it. Give one brief acknowledgment (e.g. "Done, I've added that") and move on. Never say the same thing twice.`;
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
      // Vertex Live API expects snake_case; camelCase is rejected
      generation_config: {
        response_modalities: ['audio'],
        speech_config: {
          voice_config: { prebuilt_voice_config: { voice_name: 'Puck' } },
        },
      },
      output_audio_transcription: {},
      input_audio_transcription: {},
      realtime_input_config: {
        automatic_activity_detection: {
          disabled: false,
          silence_duration_ms: 2000,
          prefix_padding_ms: 500,
        },
      },
      system_instruction: {
        parts: [{ text: systemText }],
      },
      tools: [
        {
          function_declarations: [
            {
              name: 'analyze_meal',
              description: 'Analyze the meal image the user just shared for diet compliance. Call this when the user sends a meal photo. The backend uses the image from the conversation — do NOT pass image_base64 in the call.',
              parameters: {
                type: 'object',
                properties: {
                  user_id: { type: 'string', description: 'User ID (default: demo)' },
                },
              },
            },
            {
              name: 'give_task',
              description: 'Add a task to the user\'s list. The task appears automatically — do not announce or repeat it in your speech. Diet tasks are primary; you may also suggest sleep, exercise, stress when they support diet. Examples: "Log your weight tomorrow", "Share your next meal photo", "30-minute walk today".',
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

export function extractImageBase64(args: Record<string, unknown>): string | null {
  if (typeof args?.image_base64 === 'string') return args.image_base64;
  const inline = args?.inline_data as { data?: string } | undefined;
  if (inline?.data && typeof inline.data === 'string') return inline.data;
  return null;
}

/** Placeholder strings the model may output when it cannot pass the image. */
const PLACEHOLDER_IMAGE_STRINGS = ['the_image_data', 'image_data', 'base64_image', '[image]'];

function isValidBase64Image(s: string | null): boolean {
  if (!s || typeof s !== 'string' || s.length < 100) return false;
  if (PLACEHOLDER_IMAGE_STRINGS.some((p) => s === p || s.startsWith(p))) return false;
  try {
    const decoded = Buffer.from(s.replace(/^data:image\/\w+;base64,/, ''), 'base64');
    return decoded.length > 0;
  } catch {
    return false;
  }
}

function extractImageFromClientMessage(parsed: Record<string, unknown>): string | null {
  const cc = parsed.clientContent as Record<string, unknown> | undefined;
  const turns = cc?.turns as Array<Record<string, unknown>> | undefined;
  for (const turn of turns ?? []) {
    for (const part of (turn.parts as Array<Record<string, unknown>>) ?? []) {
      const id = part.inlineData ?? part.inline_data;
      if (id && typeof (id as Record<string, unknown>).data === 'string') {
        return (id as Record<string, unknown>).data as string;
      }
    }
  }
  const ri = parsed.realtimeInput as Record<string, unknown> | undefined;
  const chunks = ri?.mediaChunks ?? ri?.media_chunks;
  const arr = Array.isArray(chunks) ? chunks : [];
  const first = arr[0] as Record<string, unknown> | undefined;
  if (first?.data && typeof first.data === 'string') return first.data as string;
  return null;
}

/** Extract image from clientContent turns; run analyze_meal and send summary to Vertex. Returns true if handled. */
async function processClientContentImage(
  parsed: Record<string, unknown>,
  serverWs: WebSocket,
  vertexAI: VertexAIClient,
  mealRepo: MealRepository,
  dietRulesRepo: DietRulesRepository
): Promise<boolean> {
  if (!parsed.clientContent) return false;
  const cc = parsed.clientContent as Record<string, unknown>;
  const turns = cc.turns as Array<Record<string, unknown>> | undefined;
  let imageBase64: string | null = null;
  for (const turn of turns ?? []) {
    for (const part of (turn.parts as Array<Record<string, unknown>>) ?? []) {
      const id = part.inlineData ?? part.inline_data;
      if (id && typeof (id as Record<string, unknown>).data === 'string') {
        imageBase64 = (id as Record<string, unknown>).data as string;
        break;
      }
    }
    if (imageBase64) break;
  }
  if (!imageBase64) return false;
  try {
    const result = await executeAnalyzeMeal(
      { image_base64: imageBase64, user_id: 'demo' },
      { vertexAI, mealRepo, dietRulesRepo }
    );
    const score = result.score ?? 0;
    const verdict = (result.verdict as string) ?? (score >= 80 ? 'good' : score >= 50 ? 'moderate' : 'off_plan');
    const compliant = (result.compliantItems as string[])?.join(', ') || 'none';
    const nonCompliant = (result.nonCompliantItems as string[])?.join(', ') || 'none';
    const suggestions = (result.suggestions as string[])?.join(', ') || 'none';
    const summary = `The user shared a meal photo. Analysis: Score ${score}/100, verdict: ${verdict}. Compliant items: ${compliant}. Non-compliant: ${nonCompliant}. Suggestions: ${suggestions}. Present this to the user in your voice — naturally, encouragingly, and clearly state if the meal is good or off plan.`;
    serverWs.send(JSON.stringify({
      client_content: {
        turns: [{ role: 'user', parts: [{ text: summary }] }],
        turn_complete: true,
      },
    }));
    return true;
  } catch (err) {
    console.error('[live-proxy] analyze_meal failed:', err);
    const fallback = `The user shared a meal photo but analysis failed. Apologize and ask them to try again or describe the meal.`;
    serverWs.send(JSON.stringify({
      client_content: {
        turns: [{ role: 'user', parts: [{ text: fallback }] }],
        turn_complete: true,
      },
    }));
    return true;
  }
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
    /** Last image from client (realtime or clientContent). Used when model calls analyze_meal without image. */
    let lastImageBase64: string | null = null;

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
            const img = extractImageFromClientMessage(parsed);
            if (img) lastImageBase64 = img;
            const handled = await processClientContentImage(parsed, serverWs!, vertexAI, mealRepo, dietRulesRepo);
            if (!handled) {
              serverWs!.send(str);
            }
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
            let imageBase64 = extractImageBase64(args);
            if (!isValidBase64Image(imageBase64) && lastImageBase64) {
              imageBase64 = lastImageBase64;
            }
            const result = await executeAnalyzeMeal(
              { ...args, image_base64: imageBase64 ?? undefined },
              { vertexAI, mealRepo, dietRulesRepo }
            );
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
          if (m.setup_complete || m.setupComplete) {
            clientWs.send(str);
            // Trigger spoken welcome: model greets user out loud on connect
            serverWs?.send(JSON.stringify({
              client_content: {
                turns: [{ role: 'user', parts: [{ text: '[Session started] Greet me briefly and welcome me to the session. Speak it out loud.' }] }],
                turn_complete: true,
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
    clientWs.on('message', async (data: WebSocket.Data) => {
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
            const chunks = ri.mediaChunks as Array<Record<string, unknown>>;
            const first = chunks[0];
            if (first?.data && typeof first.data === 'string') lastImageBase64 = first.data;
            vertexRi.media_chunks = chunks.map((c) => ({
              data: c.data,
              mime_type: c.mimeType ?? c.mime_type,
            }));
          }
          serverWs!.send(JSON.stringify({ realtime_input: vertexRi }));
        } else if (parsed.clientContent) {
          const img = extractImageFromClientMessage(parsed);
          if (img) lastImageBase64 = img;
          const handled = await processClientContentImage(parsed, serverWs!, vertexAI, mealRepo, dietRulesRepo);
          if (!handled) {
            const cc = parsed.clientContent as Record<string, unknown>;
            const vertexCc: Record<string, unknown> = {};
            if (cc.turnComplete !== undefined) vertexCc.turn_complete = cc.turnComplete;
            if (Array.isArray(cc.turns)) {
              vertexCc.turns = (cc.turns as Array<Record<string, unknown>>).map((turn) => {
                const t: Record<string, unknown> = { role: turn.role };
                if (Array.isArray(turn.parts)) {
                  t.parts = (turn.parts as Array<Record<string, unknown>>).map((p) => {
                    if (p.inlineData) {
                      const id = p.inlineData as Record<string, unknown>;
                      return { inline_data: { mime_type: id.mimeType ?? id.mime_type, data: id.data } };
                    }
                    return p;
                  });
                }
                return t;
              });
            }
            serverWs!.send(JSON.stringify({ client_content: vertexCc }));
          }
        } else {
          serverWs!.send(str);
        }
      } else {
        pendingMessage = data;
      }
    });
  });
}
