import { createClient } from "npm:@supabase/supabase-js@2";

const VERSION = 1;
const MAX_AUDIO_BYTES = 5 * 1024 * 1024;
const DEEPGRAM_TIMEOUT_MS = 30_000;
const DEEPGRAM_MODEL = "nova-3";
const DEEPGRAM_LANGUAGE = "vi";
const supportedAudioTypes = new Set([
  "audio/mp4",
  "audio/mpeg",
  "audio/wav",
  "audio/x-wav",
  "audio/aac",
  "audio/ogg",
  "audio/webm",
  "audio/flac",
]);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type ErrorCode =
  | "UNAUTHORIZED"
  | "INVALID_REQUEST"
  | "INVALID_CONTENT_TYPE"
  | "EMPTY_AUDIO"
  | "AUDIO_TOO_LARGE"
  | "UNSUPPORTED_AUDIO"
  | "EMPTY_TRANSCRIPT"
  | "DEEPGRAM_RATE_LIMITED"
  | "DEEPGRAM_UNAVAILABLE"
  | "INTERNAL_ERROR";

class FunctionError extends Error {
  constructor(
    readonly code: ErrorCode,
    readonly status: number,
  ) {
    super(code);
  }
}

const errorMessages: Record<ErrorCode, string> = {
  UNAUTHORIZED: "Phiên đăng nhập không hợp lệ.",
  INVALID_REQUEST: "Yêu cầu chuyển giọng nói không hợp lệ.",
  INVALID_CONTENT_TYPE: "Định dạng âm thanh không được hỗ trợ.",
  EMPTY_AUDIO: "Không tìm thấy dữ liệu âm thanh.",
  AUDIO_TOO_LARGE: "Đoạn ghi âm quá lớn.",
  UNSUPPORTED_AUDIO: "Không thể xử lý định dạng âm thanh này.",
  EMPTY_TRANSCRIPT: "Không nhận diện được nội dung giọng nói.",
  DEEPGRAM_RATE_LIMITED: "Dịch vụ nhận diện đang quá tải. Vui lòng thử lại sau.",
  DEEPGRAM_UNAVAILABLE: "Dịch vụ nhận diện giọng nói hiện không khả dụng.",
  INTERNAL_ERROR: "Đã xảy ra lỗi nội bộ.",
};

Deno.serve(async (request) => {
  const requestId = crypto.randomUUID();
  const startedAt = performance.now();
  let audioBytes = 0;

  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  try {
    if (request.method !== "POST") {
      throw new FunctionError("INVALID_REQUEST", 405);
    }

    await requireAuthenticatedUser(request);
    const audioContentType = validateContentType(
      request.headers.get("Content-Type"),
    );
    validateDeclaredSize(request.headers.get("Content-Length"));

    let audio: Uint8Array;
    try {
      audio = new Uint8Array(await request.arrayBuffer());
    } catch {
      throw new FunctionError("INVALID_REQUEST", 400);
    }
    audioBytes = audio.byteLength;
    if (audioBytes === 0) throw new FunctionError("EMPTY_AUDIO", 400);
    if (audioBytes > MAX_AUDIO_BYTES) {
      throw new FunctionError("AUDIO_TOO_LARGE", 413);
    }

    // DEBUG: inspect the first bytes to verify WAV content
    if (audioContentType.startsWith("audio/wav") || audioContentType.startsWith("audio/x-wav")) {
      const inspection = inspectWavAudio(audio);
      console.info(
        JSON.stringify({
          event: "deepgram_wav_debug",
          totalBytes: audio.byteLength,
          ...inspection,
        }),
      );
    }

    const providerStartedAt = performance.now();
    const transcript = await transcribeWithDeepgram(audio, audioContentType);
    const providerLatencyMs = Math.round(
      performance.now() - providerStartedAt,
    );

    logMetadata({
      requestId,
      audioBytes,
      status: 200,
      providerLatencyMs,
      success: true,
      totalLatencyMs: Math.round(performance.now() - startedAt),
    });

    return jsonResponse(
      { success: true, version: VERSION, data: { transcript } },
      200,
    );
  } catch (error) {
    const safeError = error instanceof FunctionError
      ? error
      : new FunctionError("INTERNAL_ERROR", 500);

    logMetadata({
      requestId,
      audioBytes,
      status: safeError.status,
      errorCode: safeError.code,
      success: false,
      totalLatencyMs: Math.round(performance.now() - startedAt),
    });

    return errorResponse(safeError.code, safeError.status);
  }
});

function validateContentType(value: string | null): string {
  const mimeType = value?.split(";", 1)[0].trim().toLowerCase();
  if (!mimeType || !supportedAudioTypes.has(mimeType)) {
    throw new FunctionError("INVALID_CONTENT_TYPE", 415);
  }
  return mimeType;
}

function validateDeclaredSize(value: string | null): void {
  if (value === null) return;
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed < 0) {
    throw new FunctionError("INVALID_REQUEST", 400);
  }
  if (parsed > MAX_AUDIO_BYTES) {
    throw new FunctionError("AUDIO_TOO_LARGE", 413);
  }
}

async function transcribeWithDeepgram(
  audio: Uint8Array,
  contentType: string,
): Promise<string> {
  const apiKey = Deno.env.get("DEEPGRAM_API_KEY")?.trim();
  if (!apiKey) throw new FunctionError("INTERNAL_ERROR", 500);

  const url = new URL("https://api.deepgram.com/v1/listen");
  url.searchParams.set("model", DEEPGRAM_MODEL);
  url.searchParams.set("language", DEEPGRAM_LANGUAGE);
  url.searchParams.set("punctuate", "true");
  url.searchParams.set("smart_format", "true");

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), DEEPGRAM_TIMEOUT_MS);
  let response: Response;
  try {
    response = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Token ${apiKey}`,
        "Content-Type": contentType,
      },
      body: audio,
      signal: controller.signal,
    });
  } catch {
    throw new FunctionError("DEEPGRAM_UNAVAILABLE", 503);
  } finally {
    clearTimeout(timeout);
  }

  // DEBUG: Deepgram HTTP status
  console.info(
    JSON.stringify({
      event: "deepgram_http_status",
      status: response.status,
      statusText: response.statusText,
      contentType: contentType,
      audioBytes: audio.byteLength,
    }),
  );

  if (response.status === 429) {
    throw new FunctionError("DEEPGRAM_RATE_LIMITED", 429);
  }
  if (response.status === 400 || response.status === 415 || response.status === 422) {
    // DEBUG: read error body before throwing
    const errorBody = await response.text().catch(() => "no-body");
    console.info(
      JSON.stringify({
        event: "deepgram_http_error",
        status: response.status,
        errorBody: errorBody.slice(0, 2000),
      }),
    );
    throw new FunctionError("UNSUPPORTED_AUDIO", 422);
  }
  if (!response.ok) {
    throw new FunctionError("DEEPGRAM_UNAVAILABLE", 503);
  }

  let providerBody: unknown;
  try {
    providerBody = await response.json();
  } catch {
    // DEBUG: show what we actually received
    const rawText = await response.text().catch(() => "no-body");
    console.info(
      JSON.stringify({
        event: "deepgram_json_parse_failed",
        bodyPreview: rawText.slice(0, 2000),
      }),
    );
    throw new FunctionError("DEEPGRAM_UNAVAILABLE", 503);
  }

  // DEBUG: full Deepgram JSON structure (no audio, no API keys)
  const safeSummary = extractDeepgramSummary(providerBody);
  console.info(
    JSON.stringify({
      event: "deepgram_response_summary",
      ...safeSummary,
    }),
  );

  const transcript = extractTranscript(providerBody).trim();
  // DEBUG: extracted transcript
  console.info(
    JSON.stringify({
      event: "deepgram_transcript_extracted",
      length: transcript.length,
      isEmpty: transcript.length === 0,
      preview: transcript.length > 0 ? transcript.slice(0, 200) : null,
    }),
  );

  if (!transcript) throw new FunctionError("EMPTY_TRANSCRIPT", 422);
  return transcript;
}

/** Extract a safe summary of the Deepgram response (no audio data, no raw JSON). */
function extractDeepgramSummary(value: unknown): Record<string, unknown> {
  const summary: Record<string, unknown> = {
    hasResults: false,
    channelCount: null,
    alternativeCount: null,
    hasTranscript: false,
    transcriptLength: null,
    transcriptPreview: null,
    duration: null,
    isFinal: null,
  };

  if (!isRecord(value)) return { ...summary, parseError: "value is not a record" };
  if (!isRecord(value.results)) return { ...summary, parseError: "results is not a record" };

  summary.hasResults = true;

  const results = value.results as Record<string, unknown>;
  if (typeof results.duration === "number") summary.duration = results.duration;

  const channels = results.channels;
  if (!Array.isArray(channels) || channels.length === 0) {
    summary.channelCount = 0;
    return summary;
  }
  summary.channelCount = channels.length;

  const channel = channels[0];
  if (!isRecord(channel)) return { ...summary, parseError: "channels[0] is not a record" };

  if (typeof (channel as Record<string, unknown>).isFinal === "boolean") {
    summary.isFinal = (channel as Record<string, unknown>).isFinal;
  }

  const alternatives = (channel as Record<string, unknown>).alternatives;
  if (!Array.isArray(alternatives) || alternatives.length === 0) {
    summary.alternativeCount = 0;
    return summary;
  }
  summary.alternativeCount = alternatives.length;

  const alternative = alternatives[0];
  if (!isRecord(alternative)) return { ...summary, parseError: "alternatives[0] is not a record" };

  const alt = alternative as Record<string, unknown>;

  // Transcript
  if (typeof alt.transcript === "string") {
    summary.hasTranscript = true;
    summary.transcriptLength = alt.transcript.length;
    summary.transcriptPreview = alt.transcript.length > 0
      ? alt.transcript.slice(0, 200)
      : "(empty string)";
  } else {
    summary.hasTranscript = false;
    summary.transcriptType = typeof alt.transcript;
  }

  // Confidence (safe)
  if (typeof alt.confidence === "number") {
    summary.confidence = alt.confidence;
  }

  // Words count (safe metadata)
  if (Array.isArray(alt.words)) {
    summary.wordCount = alt.words.length;
  }

  return summary;
}

/** Inspect raw WAV payload to determine if it contains silence. */
function inspectWavAudio(audio: Uint8Array): Record<string, unknown> {
  const MIN_WAV_HEADER = 44;
  if (audio.byteLength < MIN_WAV_HEADER) {
    return { error: "too small for WAV header" };
  }

  // Read WAV header fields (little-endian)
  const view = new DataView(audio.buffer, audio.byteOffset, audio.byteLength);

  const riff = String.fromCharCode(audio[0], audio[1], audio[2], audio[3]);
  const wave = String.fromCharCode(audio[8], audio[9], audio[10], audio[11]);
  const audioFormat = view.getUint16(20, true);
  const numChannels = view.getUint16(22, true);
  const sampleRate = view.getUint32(24, true);
  const byteRate = view.getUint32(28, true);
  const blockAlign = view.getUint16(32, true);
  const bitsPerSample = view.getUint16(34, true);
  const dataChunkId = String.fromCharCode(
    audio[36], audio[37], audio[38], audio[39],
  );
  const dataSize = view.getUint32(40, true);

  // Sample PCM data starting at offset 44, up to 50000 samples max
  const dataStart = 44;
  const dataEnd = Math.min(
    dataStart + Math.min(dataSize, 100_000),
    audio.byteLength,
  );
  const sampleCount = Math.floor((dataEnd - dataStart) / (bitsPerSample / 8));

  if (sampleCount === 0) {
    return {
      headerOk: riff === "RIFF" && wave === "WAVE",
      format: audioFormat,
      numChannels,
      sampleRate,
      byteRate,
      blockAlign,
      bitsPerSample,
      dataChunkOk: dataChunkId === "data",
      dataSize,
      error: "zero samples to inspect",
    };
  }

  // Compute RMS (root mean square) to estimate audio level
  let sumSq = 0;
  let peak = 0;
  let zeroCrossings = 0;

  if (bitsPerSample === 16) {
    let prevSample = view.getInt16(dataStart, true);
    for (let i = 0; i < sampleCount; i++) {
      const offset = dataStart + i * 2;
      if (offset + 1 >= audio.byteLength) break;
      const sample = view.getInt16(offset, true);
      const abs = Math.abs(sample);
      sumSq += sample * sample;
      peak = Math.max(peak, abs);
      if ((prevSample >= 0 && sample < 0) || (prevSample < 0 && sample >= 0)) {
        zeroCrossings++;
      }
      prevSample = sample;
    }
  } else if (bitsPerSample === 8) {
    for (let i = 0; i < sampleCount; i++) {
      const offset = dataStart + i;
      if (offset >= audio.byteLength) break;
      const unsigned = view.getUint8(offset);
      const signed = unsigned - 128;
      const abs = Math.abs(signed);
      sumSq += signed * signed;
      peak = Math.max(peak, abs);
    }
  }

  const rms = Math.sqrt(sumSq / sampleCount);
  // Normalise RMS to 0..1 for 16-bit signed
  const normalizedRms = bitsPerSample === 16 ? rms / 32768 : rms / 128;
  // dBFS: 0 dBFS = max possible level
  const dbfs = normalizedRms > 0 ? 20 * Math.log10(normalizedRms) : -200;

  return {
    headerOk: riff === "RIFF" && wave === "WAVE",
    format: audioFormat,
    numChannels,
    sampleRate,
    byteRate,
    blockAlign,
    bitsPerSample,
    dataChunkOk: dataChunkId === "data",
    dataSize,
    inspectedSamples: sampleCount,
    peak,
    rms: Math.round(rms),
    dbfs: Math.round(dbfs * 10) / 10,
    zeroCrossings,
  };
}

function extractTranscript(value: unknown): string {
  if (!isRecord(value) || !isRecord(value.results)) return "";
  const channels = value.results.channels;
  if (!Array.isArray(channels) || channels.length === 0) return "";
  const channel = channels[0];
  if (!isRecord(channel) || !Array.isArray(channel.alternatives)) return "";
  const alternative = channel.alternatives[0];
  if (!isRecord(alternative) || typeof alternative.transcript !== "string") {
    return "";
  }
  return alternative.transcript;
}

async function requireAuthenticatedUser(request: Request): Promise<void> {
  const authorization = request.headers.get("Authorization")?.trim() ?? "";
  if (!/^Bearer\s+\S+$/i.test(authorization)) {
    throw new FunctionError("UNAUTHORIZED", 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseKey = getSupabasePublishableKey();
  if (!supabaseUrl || !supabaseKey) {
    throw new FunctionError("INTERNAL_ERROR", 500);
  }

  const client = createClient(supabaseUrl, supabaseKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const token = authorization.replace(/^Bearer\s+/i, "");
  const { data, error } = await client.auth.getUser(token);
  if (error || !data.user) {
    throw new FunctionError("UNAUTHORIZED", 401);
  }
}

function getSupabasePublishableKey(): string | undefined {
  const legacy = Deno.env.get("SUPABASE_ANON_KEY") ??
    Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
  if (legacy?.trim()) return legacy.trim();

  const namedKeys = Deno.env.get("SUPABASE_PUBLISHABLE_KEYS");
  if (!namedKeys) return undefined;
  try {
    const parsed: unknown = JSON.parse(namedKeys);
    if (!isRecord(parsed)) return undefined;
    const defaultKey = parsed.default;
    return typeof defaultKey === "string" && defaultKey.trim()
      ? defaultKey.trim()
      : undefined;
  } catch {
    return undefined;
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
    },
  });
}

function errorResponse(code: ErrorCode, status: number): Response {
  return jsonResponse(
    {
      success: false,
      version: VERSION,
      error: { code, message: errorMessages[code] },
    },
    status,
  );
}

function logMetadata(metadata: Record<string, unknown>): void {
  console.info(JSON.stringify(metadata));
}
