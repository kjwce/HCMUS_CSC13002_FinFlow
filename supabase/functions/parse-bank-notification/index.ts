import { createClient } from "npm:@supabase/supabase-js@2";

const VERSION = 1;
const DEFAULT_MODEL = "gemini-3.1-flash-lite";
const TIMEOUT_MS = 12_000;
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const schema = {
  type: "object",
  additionalProperties: false,
  required: [
    "isTransaction",
    "type",
    "amount",
    "name",
    "categoryKey",
    "date",
    "confidence",
    "warnings",
  ],
  properties: {
    isTransaction: { type: "boolean" },
    type: {
      type: "string",
      enum: ["income", "expense"],
      nullable: true,
    },
    amount: { type: "integer", minimum: 1, nullable: true },
    name: { type: "string", nullable: true },
    categoryKey: { type: "string", nullable: true },
    date: { type: "string", nullable: true },
    confidence: { type: "number", minimum: 0, maximum: 1 },
    warnings: { type: "array", items: { type: "string" } },
  },
};

const instruction = `You parse Android notifications from Vietnamese banks and
e-wallets for the FinFlow personal-finance app. Return only schema-valid JSON.

SECURITY
- OTP, verification codes, login alerts, password changes, device registration,
fraud/security warnings, promotions, rewards, reminders, and generic balance
messages are not transactions. Set isTransaction false.
- Never infer a transaction from the package or title alone.
- Never treat account/card numbers, timestamps, reference IDs, OTPs, or balances
as the transaction amount.

TRANSACTION
- A real debit, payment, purchase, withdrawal, transfer out, or balance decrease
is expense. A real credit, incoming transfer, refund, salary, or balance increase
is income.
- amount is the positive absolute VND integer for this transaction, never signed.
- If the notification does not explicitly provide a reliable amount or direction,
set the missing value null and lower confidence.
- name is a short useful description without account numbers or transaction IDs.
- categoryKey must exactly equal one supplied category. Use Other when uncertain
and available. Do not invent a category.
- date is an ISO-8601 local datetime derived from the notification; otherwise use
postedAt. Do not use server time.
- confidence measures extraction certainty, not whether the bank is trusted.
- Keep warnings short and in Vietnamese.

OUTPUT
- Set isTransaction true only for an actual completed/accounting transaction.
- Return exactly isTransaction, type, amount, name, categoryKey, date,
confidence, warnings.`;

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  try {
    if (request.method !== "POST") return failure("INVALID_REQUEST", 405);
    await requireUser(request);
    const body = await request.json();
    const input = validate(body);
    const apiKey = Deno.env.get("GEMINI_API_KEY")?.trim();
    if (!apiKey) return failure("GEMINI_UNAVAILABLE", 503);
    const model = Deno.env.get("GEMINI_MODEL")?.trim() || DEFAULT_MODEL;

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), TIMEOUT_MS);
    let response: Response;
    try {
      response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
        {
          method: "POST",
          signal: controller.signal,
          headers: {
            "Content-Type": "application/json",
            "x-goog-api-key": apiKey,
          },
          body: JSON.stringify({
            systemInstruction: { parts: [{ text: instruction }] },
            contents: [{
              role: "user",
              parts: [{
                text: JSON.stringify(input),
              }],
            }],
            generationConfig: {
              temperature: 0,
              responseMimeType: "application/json",
              responseJsonSchema: schema,
            },
          }),
        },
      );
    } finally {
      clearTimeout(timeout);
    }
    if (response.status === 429) return failure("GEMINI_RATE_LIMITED", 429);
    if (!response.ok) return failure("GEMINI_UNAVAILABLE", 503);

    const raw = await response.json();
    const text = raw?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (typeof text !== "string") return failure("INVALID_MODEL_OUTPUT", 502);
    let data: unknown;
    try {
      data = JSON.parse(text);
    } catch {
      return failure("INVALID_MODEL_OUTPUT", 502);
    }
    if (!validOutput(data, input.categories)) {
      return failure("INVALID_MODEL_OUTPUT", 502);
    }
    return json({ success: true, version: VERSION, data });
  } catch (error) {
    if (error instanceof DOMException && error.name === "AbortError") {
      return failure("GEMINI_TIMEOUT", 504);
    }
    const code = error instanceof Error ? error.message : "INTERNAL_ERROR";
    if (code === "UNAUTHORIZED") return failure(code, 401);
    if (code === "INVALID_REQUEST") return failure(code, 400);
    return failure("INTERNAL_ERROR", 500);
  }
});

async function requireUser(request: Request) {
  const authorization = request.headers.get("Authorization")?.trim() ?? "";
  const token = authorization.replace(/^Bearer\s+/i, "");
  if (!token) throw new Error("UNAUTHORIZED");
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !key) throw new Error("INTERNAL_ERROR");
  const client = createClient(url, key, {
    global: { headers: { Authorization: authorization } },
  });
  const { data, error } = await client.auth.getUser(token);
  if (error || !data.user) throw new Error("UNAUTHORIZED");
}

function validate(body: unknown) {
  if (!body || typeof body !== "object") throw new Error("INVALID_REQUEST");
  const value = body as Record<string, unknown>;
  const packageName = string(value.packageName, 200);
  const title = string(value.title, 300, true);
  const text = string(value.text, 1500, true);
  const postedAt = string(value.postedAt, 80);
  const currentDateTime = string(value.currentDateTime, 80);
  if (!title && !text) throw new Error("INVALID_REQUEST");
  if (Number.isNaN(Date.parse(postedAt)) ||
    Number.isNaN(Date.parse(currentDateTime))) {
    throw new Error("INVALID_REQUEST");
  }
  if (!Array.isArray(value.categories)) throw new Error("INVALID_REQUEST");
  const categories = value.categories
    .filter((item): item is string =>
      typeof item === "string" && item.length > 0 && item.length <= 80
    )
    .slice(0, 50);
  if (categories.length === 0) throw new Error("INVALID_REQUEST");
  return { packageName, title, text, postedAt, currentDateTime, categories };
}

function string(value: unknown, max: number, empty = false): string {
  if (typeof value !== "string" || value.length > max || (!empty && !value)) {
    throw new Error("INVALID_REQUEST");
  }
  return value;
}

function validOutput(value: unknown, categories: string[]): boolean {
  if (!value || typeof value !== "object" || Array.isArray(value)) return false;
  const data = value as Record<string, unknown>;
  const keys = Object.keys(data);
  const expected = [
    "isTransaction", "type", "amount", "name", "categoryKey", "date",
    "confidence", "warnings",
  ];
  if (keys.length !== expected.length || !expected.every((key) => key in data)) {
    return false;
  }
  if (typeof data.isTransaction !== "boolean") return false;
  if (data.type !== null && data.type !== "income" && data.type !== "expense") {
    return false;
  }
  if (data.amount !== null &&
    (!Number.isInteger(data.amount as number) ||
      (data.amount as number) <= 0)) return false;
  if (data.name !== null && (typeof data.name !== "string" || !data.name.trim())) {
    return false;
  }
  if (data.categoryKey !== null &&
    (typeof data.categoryKey !== "string" ||
      !categories.includes(data.categoryKey))) return false;
  if (data.date !== null &&
    (typeof data.date !== "string" ||
      Number.isNaN(Date.parse(data.date)))) return false;
  if (typeof data.confidence !== "number" || data.confidence < 0 ||
    data.confidence > 1) return false;
  return Array.isArray(data.warnings) &&
    data.warnings.every((item) => typeof item === "string");
}

function failure(code: string, status: number) {
  return json({ success: false, error: { code } }, status);
}

function json(value: unknown, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
