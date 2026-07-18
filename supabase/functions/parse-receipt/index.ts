import { createClient } from "npm:@supabase/supabase-js@2";

import {
  extractGeminiText,
  isRecord,
  localeFromReceiptBody,
  ReceiptFunctionError,
  type ReceiptErrorCode,
  receiptErrorMessage,
  RECEIPT_RESPONSE_VERSION,
  sanitizeReceiptOutput,
  type ValidatedReceiptRequest,
  validateReceiptRequest,
} from "../_shared/receipt_parser.ts";

const DEFAULT_MODEL = "gemini-3.1-flash-lite";
const GEMINI_TIMEOUT_MS = 30_000;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const receiptResponseSchema = {
  type: "object",
  additionalProperties: false,
  required: [
    "merchantName",
    "receiptDate",
    "currency",
    "items",
    "totalAmount",
    "warnings",
  ],
  properties: {
    merchantName: { type: "string", nullable: true },
    receiptDate: {
      type: "string",
      nullable: true,
      description: "ISO local date YYYY-MM-DD when visible, otherwise null.",
    },
    currency: { type: "string" },
    items: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["name", "amount", "categoryKey", "confidence", "warning"],
        properties: {
          name: { type: "string" },
          amount: { type: "integer", minimum: 1 },
          categoryKey: { type: "string", nullable: true },
          confidence: { type: "number", minimum: 0, maximum: 1 },
          warning: { type: "string", nullable: true },
        },
      },
    },
    totalAmount: { type: "integer", minimum: 0 },
    warnings: { type: "array", items: { type: "string" } },
  },
};

const baseInstruction = `You are FinFlow's receipt line-item parser.
Return only the JSON object required by the supplied JSON Schema. Never return markdown or prose.

LANGUAGE
- Receipts may contain Vietnamese, English, or both languages.
- Preserve product and service names as they appear on the receipt.
- Understand Vietnamese diacritics and Vietnamese without diacritics.

RECEIPT EXTRACTION
- Extract purchased food, products, and services as separate items.
- Do not create items for subtotal, total, VAT, tax, service charge, discount, payment method, change, invoice number, phone number, or address.
- If a line has quantity and unit price, return the line total as amount.
- Normalize VND values to positive integers. Examples: 50k, 50.000đ, 50,000 VND -> 50000.
- Do not invent a missing amount. Add a warning when an item or total is unclear.
- Use the visible receipt total as totalAmount rather than silently changing item amounts.

CATEGORY
- categoryKey must exactly match one of the supplied category keys.
- Prefer Food for meals and drinks, Service for services such as massage, haircut, repair, or delivery service, and Other only when no supplied category fits.
- Never invent or translate category keys.

OUTPUT
- Keep merchantName and receiptDate null when they are not visible.
- currency should be VND for Vietnamese receipts and the visible currency code for another currency.
- confidence is between 0 and 1 for each item.
- warnings must be short and written in the requested locale.`;

Deno.serve(async (request) => {
  const requestId = crypto.randomUUID();
  const startedAt = performance.now();
  let locale = localeFromReceiptBody(null);

  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  try {
    if (request.method !== "POST") {
      throw new ReceiptFunctionError("INVALID_REQUEST", 405, locale);
    }

    await requireAuthenticatedUser(request, locale);

    let body: unknown;
    try {
      body = await request.json();
    } catch {
      throw new ReceiptFunctionError("INVALID_REQUEST", 400, locale);
    }

    locale = localeFromReceiptBody(body);
    const input = validateReceiptRequest(body, locale);
    const providerStartedAt = performance.now();
    const rawOutput = await callGemini(input);
    const providerLatencyMs = Math.round(performance.now() - providerStartedAt);
    const data = sanitizeReceiptOutput(rawOutput, input.categories, locale);

    logMetadata({
      requestId,
      imageBytes: input.imageBytes,
      itemCount: data.items.length,
      providerLatencyMs,
      status: 200,
      success: true,
      totalLatencyMs: Math.round(performance.now() - startedAt),
    });

    return jsonResponse(
      { success: true, version: RECEIPT_RESPONSE_VERSION, data },
      200,
    );
  } catch (error) {
    const safeError = error instanceof ReceiptFunctionError
      ? error
      : new ReceiptFunctionError("INTERNAL_ERROR", 500, locale);

    logMetadata({
      requestId,
      status: safeError.status,
      errorCode: safeError.code,
      success: false,
      totalLatencyMs: Math.round(performance.now() - startedAt),
    });

    return errorResponse(safeError.code, safeError.status, safeError.locale);
  }
});

async function callGemini(input: ValidatedReceiptRequest): Promise<unknown> {
  const apiKey = Deno.env.get("GEMINI_API_KEY")?.trim();
  if (!apiKey) {
    throw new ReceiptFunctionError("INTERNAL_ERROR", 500, input.locale);
  }

  const model = Deno.env.get("GEMINI_MODEL")?.trim() || DEFAULT_MODEL;
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`;
  const prompt = `${baseInstruction}\n\nREQUESTED LOCALE: ${input.locale}\n\nAVAILABLE CATEGORIES:\n${JSON.stringify(input.categories)}\n\nAnalyze the receipt image now.`;
  const body = JSON.stringify({
    systemInstruction: { parts: [{ text: prompt }] },
    contents: [{
      role: "user",
      parts: [
        { text: "Extract the receipt data from the following image." },
        { inlineData: { mimeType: input.mimeType, data: input.imageBase64 } },
      ],
    }],
    generationConfig: {
      temperature: 0,
      maxOutputTokens: 2048,
      thinkingConfig: { thinkingLevel: "minimal" },
      responseMimeType: "application/json",
      responseJsonSchema: receiptResponseSchema,
    },
  });

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), GEMINI_TIMEOUT_MS);
  let response: Response;
  try {
    response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": apiKey,
      },
      body,
      signal: controller.signal,
    });
  } catch {
    throw new ReceiptFunctionError(
      controller.signal.aborted ? "GEMINI_TIMEOUT" : "GEMINI_UNAVAILABLE",
      controller.signal.aborted ? 504 : 503,
      input.locale,
    );
  } finally {
    clearTimeout(timeout);
  }

  if (response.status === 429) {
    throw new ReceiptFunctionError("GEMINI_RATE_LIMITED", 429, input.locale);
  }
  if (!response.ok) {
    await response.text().catch(() => "");
    throw new ReceiptFunctionError("GEMINI_UNAVAILABLE", 503, input.locale);
  }

  let providerBody: unknown;
  try {
    providerBody = await response.json();
  } catch {
    throw new ReceiptFunctionError("INVALID_MODEL_OUTPUT", 502, input.locale);
  }

  const text = extractGeminiText(providerBody);
  try {
    return JSON.parse(text);
  } catch {
    throw new ReceiptFunctionError("INVALID_MODEL_OUTPUT", 502, input.locale);
  }
}

async function requireAuthenticatedUser(
  request: Request,
  locale: ValidatedReceiptRequest["locale"],
): Promise<void> {
  const authorization = request.headers.get("Authorization")?.trim() ?? "";
  if (!/^Bearer\s+\S+$/i.test(authorization)) {
    throw new ReceiptFunctionError("UNAUTHORIZED", 401, locale);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseKey = getSupabasePublishableKey();
  if (!supabaseUrl || !supabaseKey) {
    throw new ReceiptFunctionError("INTERNAL_ERROR", 500, locale);
  }

  const client = createClient(supabaseUrl, supabaseKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const token = authorization.replace(/^Bearer\s+/i, "");
  const { data, error } = await client.auth.getUser(token);
  if (error || !data.user) {
    throw new ReceiptFunctionError("UNAUTHORIZED", 401, locale);
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

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" },
  });
}

function errorResponse(
  code: ReceiptErrorCode,
  status: number,
  locale: ValidatedReceiptRequest["locale"],
): Response {
  return jsonResponse(
    {
      success: false,
      version: RECEIPT_RESPONSE_VERSION,
      error: { code, message: receiptErrorMessage(code, locale) },
    },
    status,
  );
}

function logMetadata(metadata: Record<string, unknown>): void {
  console.info(JSON.stringify(metadata));
}
