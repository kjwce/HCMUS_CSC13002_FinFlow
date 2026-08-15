import { createClient } from "npm:@supabase/supabase-js@2";

const VERSION = 1;
const MAX_TEXT_LENGTH = 500;
const DEFAULT_LOCALE = "vi-VN";
const DEFAULT_MODEL = "gemini-3.1-flash-lite";
const GEMINI_TIMEOUT_MS = 12_000;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type Locale = "vi-VN" | "en-US";
type ErrorCode =
  | "UNAUTHORIZED"
  | "INVALID_REQUEST"
  | "EMPTY_TEXT"
  | "TEXT_TOO_LONG"
  | "GEMINI_RATE_LIMITED"
  | "GEMINI_TIMEOUT"
  | "GEMINI_UNAVAILABLE"
  | "INVALID_MODEL_OUTPUT"
  | "INTERNAL_ERROR";

type CategoryInput = {
  key: string;
  label: string;
};

type WalletInput = {
  id: string;
  name: string;
  type: "cash" | "transfer";
  isActive: boolean;
};

type ValidatedRequest = {
  text: string;
  currentDate: string | null;
  currentDateTime: string | null;
  timezone: string | null;
  locale: Locale;
  categories: CategoryInput[];
  wallets: WalletInput[];
};

type ParserData = {
  type: "income" | "expense" | null;
  amount: number | null;
  name: string | null;
  categoryKey: string | null;
  walletName: string | null;
  date: string | null;
  confidence: number;
  warnings: string[];
};

class FunctionError extends Error {
  constructor(
    readonly code: ErrorCode,
    readonly status: number,
    readonly locale: Locale,
  ) {
    super(code);
  }
}

const errorMessages: Record<Locale, Record<ErrorCode, string>> = {
  "vi-VN": {
    UNAUTHORIZED: "Phiên đăng nhập không hợp lệ.",
    INVALID_REQUEST: "Dữ liệu yêu cầu không hợp lệ.",
    EMPTY_TEXT: "Nội dung giao dịch không được để trống.",
    TEXT_TOO_LONG: "Nội dung giao dịch không được vượt quá 500 ký tự.",
    GEMINI_RATE_LIMITED: "Dịch vụ phân tích đang quá tải. Vui lòng thử lại sau.",
    GEMINI_TIMEOUT: "Dịch vụ phân tích phản hồi quá chậm. Vui lòng thử lại.",
    GEMINI_UNAVAILABLE: "Dịch vụ phân tích hiện không khả dụng.",
    INVALID_MODEL_OUTPUT: "Kết quả phân tích không hợp lệ.",
    INTERNAL_ERROR: "Đã xảy ra lỗi nội bộ.",
  },
  "en-US": {
    UNAUTHORIZED: "The authenticated session is invalid.",
    INVALID_REQUEST: "Invalid request data.",
    EMPTY_TEXT: "Transaction text must not be empty.",
    TEXT_TOO_LONG: "Transaction text must not exceed 500 characters.",
    GEMINI_RATE_LIMITED: "The parsing service is busy. Please try again later.",
    GEMINI_TIMEOUT: "The parsing service took too long. Please try again.",
    GEMINI_UNAVAILABLE: "The parsing service is currently unavailable.",
    INVALID_MODEL_OUTPUT: "The parser returned an invalid result.",
    INTERNAL_ERROR: "An internal error occurred.",
  },
};

const warningMessages = {
  "vi-VN": {
    missingAmount: "Không xác định được số tiền giao dịch.",
    missingName: "Không xác định được tên giao dịch.",
    missingType: "Không xác định được đây là khoản thu hay chi.",
    invalidCategoryWithFallback:
      "Không xác định được danh mục phù hợp. Đã sử dụng Other.",
    invalidCategoryWithoutFallback:
      "Không xác định được danh mục phù hợp.",
  },
  "en-US": {
    missingAmount: "The transaction amount could not be determined.",
    missingName: "The transaction name could not be determined.",
    missingType: "The transaction could not be classified as income or expense.",
    invalidCategoryWithFallback:
      "No suitable category was found. Other was used.",
    invalidCategoryWithoutFallback: "No suitable category was found.",
  },
} satisfies Record<Locale, Record<string, string>>;

const allowedDataKeys = new Set([
  "type",
  "amount",
  "name",
  "categoryKey",
  "walletName",
  "date",
  "confidence",
  "warnings",
]);

const geminiResponseSchema = {
  type: "object",
  additionalProperties: false,
  required: [
    "type",
    "amount",
    "name",
    "categoryKey",
    "walletName",
    "date",
    "confidence",
    "warnings",
  ],
  properties: {
    type: {
      type: "string",
      enum: ["income", "expense"],
      nullable: true,
      description: "Either income, expense, or null when ambiguous.",
    },
    amount: {
      type: "integer",
      nullable: true,
      minimum: 1,
      description: "Absolute VND amount. Never signed.",
    },
    name: { type: "string", nullable: true },
    categoryKey: { type: "string", nullable: true },
    walletName: { type: "string", nullable: true },
    date: {
      type: "string",
      nullable: true,
      description: "ISO-8601 local date-time without a timezone, or null.",
    },
    confidence: { type: "number", minimum: 0, maximum: 1 },
    warnings: { type: "array", items: { type: "string" } },
  },
};

const systemInstruction = `You are FinFlow's transaction text parser.
Return only the JSON object required by the supplied JSON Schema. Never return markdown or prose.

LANGUAGE
- Vietnamese is the primary supported language.
- English transaction sentences are supported.
- Mixed Vietnamese-English transaction sentences are supported.
- Understand Vietnamese without diacritics when possible.
- Use the requested locale for every warning: vi-VN for Vietnamese, en-US for English.

AMOUNT AND TYPE
- Return type separately as income, expense, or null.
- Return amount as a positive absolute VND integer or null. Never return a signed amount.
- Understand monetary expressions including 45k, 50 nghìn, 50 ngan, 1 triệu, 1 trieu, 1 triệu 2, and 2 củ when clearly monetary.
- Never invent an amount. Do not mistake dates, phone numbers, account numbers, invoice numbers, or wallet IDs for an amount.
- If amount is unsafe or unclear, return null, lower confidence, and add a localized warning.
- A transfer between the user's own sources such as "Chuyển 500k từ A sang B" is unsupported: return type null and a localized warning.
- "Chuyển khoản" used as a payment method is not an account-to-account transfer; resolve it as walletName Transfer.

DATE
- Resolve relative dates only from currentDate, currentDateTime, and timezone.
- Support hôm nay/hom nay/today, hôm qua/hom qua/yesterday, and hôm kia/hom kia/the day before yesterday.
- Return a full ISO-8601 local date-time such as 2026-07-10T12:00:00.
- Preserve an explicit time when possible. If a date is given without a time, use 12:00:00.
- If no date is mentioned, return null. Never invent a date from server time.
- If a date is invalid or ambiguous, return null and add a localized warning.

NAME AND CATEGORY
- Name describes what the user did; categoryKey classifies it. Keep name short and remove redundant amount, date, and wallet wording when practical.
- Do not replace a meaningful transaction name with a category name or Other.
- categoryKey must exactly match a key supplied in categories. Keys are case-sensitive. Never translate, lowercase, rename, normalize, or invent category keys.
- If no supplied category confidently matches, return Other only when the exact key Other is supplied; otherwise return null. Add a localized warning.

WALLET
- walletName is only a concise hint explicitly mentioned by the user. Never return walletId.
- Do not claim a wallet match, select a default wallet, or return a wallet that was not mentioned.
- The only wallet names are Cash and Transfer.
- Normalize tien mat/cash/tiền mặt to Cash. Normalize bank, ngân hàng, ví điện tử, e-wallet, chuyển khoản, and transfer to Transfer.
- If no wallet is mentioned, return null.

OUTPUT
- Return exactly: type, amount, name, categoryKey, walletName, date, confidence, warnings.
- Do not return id, userId, walletId, categoryId, signedAmount, note, source, TransactionModel, or database fields.`;

Deno.serve(async (request) => {
  const requestId = crypto.randomUUID();
  const startedAt = performance.now();
  let locale: Locale = DEFAULT_LOCALE;
  let textLength = 0;

  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  try {
    if (request.method !== "POST") {
      throw new FunctionError("INVALID_REQUEST", 405, locale);
    }

    await requireAuthenticatedUser(request, locale);

    let body: unknown;
    try {
      body = await request.json();
    } catch {
      throw new FunctionError("INVALID_REQUEST", 400, locale);
    }

    locale = localeFromBody(body);
    const validated = validateRequest(body, locale);
    textLength = validated.text.length;

    const providerStartedAt = performance.now();
    const rawOutput = await callGemini(validated);
    const providerLatencyMs = Math.round(performance.now() - providerStartedAt);
    const data = validateAndSanitizeOutput(rawOutput, validated);

    logMetadata({
      requestId,
      textLength,
      status: 200,
      providerLatencyMs,
      success: true,
      totalLatencyMs: Math.round(performance.now() - startedAt),
    });

    return jsonResponse({ success: true, version: VERSION, data }, 200);
  } catch (error) {
    const safeError = error instanceof FunctionError
      ? error
      : new FunctionError("INTERNAL_ERROR", 500, locale);

    logMetadata({
      requestId,
      textLength,
      status: safeError.status,
      errorCode: safeError.code,
      success: false,
      totalLatencyMs: Math.round(performance.now() - startedAt),
    });

    return errorResponse(safeError.code, safeError.status, safeError.locale);
  }
});

async function requireAuthenticatedUser(
  request: Request,
  locale: Locale,
): Promise<void> {
  const authorization = request.headers.get("Authorization")?.trim() ?? "";
  if (!/^Bearer\s+\S+$/i.test(authorization)) {
    throw new FunctionError("UNAUTHORIZED", 401, locale);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseKey = getSupabasePublishableKey();
  if (!supabaseUrl || !supabaseKey) {
    throw new FunctionError("INTERNAL_ERROR", 500, locale);
  }

  const client = createClient(supabaseUrl, supabaseKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const token = authorization.replace(/^Bearer\s+/i, "");
  const { data, error } = await client.auth.getUser(token);
  if (error || !data.user) {
    throw new FunctionError("UNAUTHORIZED", 401, locale);
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

function localeFromBody(body: unknown): Locale {
  if (!isRecord(body)) return DEFAULT_LOCALE;
  return body.locale === "en-US" ? "en-US" : DEFAULT_LOCALE;
}

function validateRequest(body: unknown, locale: Locale): ValidatedRequest {
  if (!isRecord(body) || Object.hasOwn(body, "userId")) {
    throw new FunctionError("INVALID_REQUEST", 400, locale);
  }

  if (typeof body.text !== "string") {
    throw new FunctionError("INVALID_REQUEST", 400, locale);
  }
  const text = body.text.trim();
  if (!text) throw new FunctionError("EMPTY_TEXT", 400, locale);
  if (text.length > MAX_TEXT_LENGTH) {
    throw new FunctionError("TEXT_TOO_LONG", 400, locale);
  }

  const currentDate = optionalString(body.currentDate, locale);
  if (currentDate !== null && !isValidIsoDate(currentDate)) {
    throw new FunctionError("INVALID_REQUEST", 400, locale);
  }

  const currentDateTime = optionalString(body.currentDateTime, locale);
  if (
    currentDateTime !== null &&
    Number.isNaN(Date.parse(currentDateTime))
  ) {
    throw new FunctionError("INVALID_REQUEST", 400, locale);
  }

  const timezone = optionalString(body.timezone, locale);
  if (timezone !== null && !isValidTimezone(timezone)) {
    throw new FunctionError("INVALID_REQUEST", 400, locale);
  }

  const categories = validateCategories(body.categories, locale);
  const wallets = validateWallets(body.wallets, locale);

  return {
    text,
    currentDate,
    currentDateTime,
    timezone,
    locale,
    categories,
    wallets,
  };
}

function validateCategories(value: unknown, locale: Locale): CategoryInput[] {
  if (!Array.isArray(value)) {
    throw new FunctionError("INVALID_REQUEST", 400, locale);
  }
  const seen = new Set<string>();
  return value.map((item) => {
    if (!isRecord(item)) {
      throw new FunctionError("INVALID_REQUEST", 400, locale);
    }
    const key = requiredNonEmptyString(item.key, locale);
    const label = requiredNonEmptyString(item.label, locale);
    if (seen.has(key)) {
      throw new FunctionError("INVALID_REQUEST", 400, locale);
    }
    seen.add(key);
    return { key, label };
  });
}

function validateWallets(value: unknown, locale: Locale): WalletInput[] {
  if (!Array.isArray(value)) {
    throw new FunctionError("INVALID_REQUEST", 400, locale);
  }
  const seen = new Set<string>();
  return value.map((item) => {
    if (!isRecord(item)) {
      throw new FunctionError("INVALID_REQUEST", 400, locale);
    }
    const id = requiredNonEmptyString(item.id, locale);
    const name = requiredNonEmptyString(item.name, locale);
    if (item.type !== "cash" && item.type !== "transfer") {
      throw new FunctionError("INVALID_REQUEST", 400, locale);
    }
    if (typeof item.isActive !== "boolean" || seen.has(id)) {
      throw new FunctionError("INVALID_REQUEST", 400, locale);
    }
    seen.add(id);
    return { id, name, type: item.type, isActive: item.isActive };
  });
}

async function callGemini(input: ValidatedRequest): Promise<unknown> {
  const apiKey = Deno.env.get("GEMINI_API_KEY")?.trim();
  if (!apiKey) {
    throw new FunctionError("INTERNAL_ERROR", 500, input.locale);
  }

  const model = Deno.env.get("GEMINI_MODEL")?.trim() || DEFAULT_MODEL;
  return callGeminiModel(input, apiKey, model);
}

async function callGeminiModel(
  input: ValidatedRequest,
  apiKey: string,
  model: string,
): Promise<unknown> {
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`;
  const body = JSON.stringify({
    systemInstruction: { parts: [{ text: systemInstruction }] },
    contents: [
      {
        role: "user",
        parts: [
          {
            text: JSON.stringify({
              task: "Parse this transaction text using only the supplied context.",
              ...input,
            }),
          },
        ],
      },
    ],
    generationConfig: {
      temperature: 0,
      maxOutputTokens: 1024,
      thinkingConfig: { thinkingLevel: "minimal" },
      responseMimeType: "application/json",
      responseJsonSchema: geminiResponseSchema,
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
    const timedOut = controller.signal.aborted;
    throw new FunctionError(
      timedOut ? "GEMINI_TIMEOUT" : "GEMINI_UNAVAILABLE",
      timedOut ? 504 : 503,
      input.locale,
    );
  } finally {
    clearTimeout(timeout);
  }

  if (!response.ok) {
    const providerErrorBody = await response.text();

    // TEMPORARY GEMINI PROVIDER ERROR DEBUG
    // REMOVE AFTER TESTING
    console.info(
      JSON.stringify({
        event: "gemini_provider_error",
        status: response.status,
        model,
        bodyPreview: providerErrorBody.slice(0, 500),
        bodyLength: providerErrorBody.length,
      }),
    );
  }

  if (response.status === 429) {
    throw new FunctionError("GEMINI_RATE_LIMITED", 429, input.locale);
  }
  if (!response.ok) {
    throw new FunctionError("GEMINI_UNAVAILABLE", 503, input.locale);
  }

  let providerBody: unknown;
  try {
    providerBody = await response.json();
  } catch {
    throw new FunctionError("INVALID_MODEL_OUTPUT", 502, input.locale);
  }

  let text: string;
  try {
    text = extractGeminiText(providerBody);
  } catch {
    throw new FunctionError("INVALID_MODEL_OUTPUT", 502, input.locale);
  }
  try {
    return JSON.parse(text);
  } catch {
    throw new FunctionError("INVALID_MODEL_OUTPUT", 502, input.locale);
  }
}

function extractGeminiText(body: unknown): string {
  if (!isRecord(body) || !Array.isArray(body.candidates)) {
    throw new Error("Missing candidates");
  }
  const candidate = body.candidates[0];
  if (!isRecord(candidate) || !isRecord(candidate.content)) {
    throw new Error("Missing content");
  }
  const parts = candidate.content.parts;
  if (!Array.isArray(parts)) throw new Error("Missing parts");
  const texts = parts
    .filter(isRecord)
    .map((part) => part.text)
    .filter((value): value is string => typeof value === "string");
  if (texts.length === 0) throw new Error("Missing text");
  return texts.join("");
}

function validateAndSanitizeOutput(
  value: unknown,
  request: ValidatedRequest,
): ParserData {
  const invalid = () =>
    new FunctionError("INVALID_MODEL_OUTPUT", 502, request.locale);
  if (!isRecord(value)) throw invalid();
  const keys = Object.keys(value);
  if (
    keys.length !== allowedDataKeys.size ||
    keys.some((key) => !allowedDataKeys.has(key)) ||
    [...allowedDataKeys].some((key) => !Object.hasOwn(value, key))
  ) {
    throw invalid();
  }

  if (
    value.type !== null && value.type !== "income" && value.type !== "expense"
  ) {
    throw invalid();
  }
  if (
    value.amount !== null &&
    (typeof value.amount !== "number" ||
      !Number.isSafeInteger(value.amount) ||
      value.amount <= 0)
  ) throw invalid();
  const amount = value.amount as number | null;

  const name = nullableTrimmedString(value.name, invalid);
  const walletName = nullableTrimmedString(value.walletName, invalid);
  const date = nullableTrimmedString(value.date, invalid);
  if (date !== null && !isValidIsoLocalDateTime(date)) throw invalid();
  if (
    typeof value.confidence !== "number" ||
    !Number.isFinite(value.confidence) ||
    value.confidence < 0 ||
    value.confidence > 1
  ) {
    throw invalid();
  }
  if (
    !Array.isArray(value.warnings) ||
    value.warnings.some((warning) => typeof warning !== "string")
  ) {
    throw invalid();
  }

  const warnings = value.warnings.map((warning) => warning.trim()).filter(
    Boolean,
  );
  if (value.type === null) {
    addWarning(warnings, warningMessages[request.locale].missingType);
  }
  if (amount === null) {
    addWarning(warnings, warningMessages[request.locale].missingAmount);
  }
  if (name === null) {
    addWarning(warnings, warningMessages[request.locale].missingName);
  }
  const allowedCategories = new Set(request.categories.map((item) => item.key));
  let categoryKey = nullableTrimmedString(value.categoryKey, invalid);
  if (categoryKey === null || !allowedCategories.has(categoryKey)) {
    if (allowedCategories.has("Other")) {
      categoryKey = "Other";
      addWarning(
        warnings,
        warningMessages[request.locale].invalidCategoryWithFallback,
      );
    } else {
      categoryKey = null;
      addWarning(
        warnings,
        warningMessages[request.locale].invalidCategoryWithoutFallback,
      );
    }
  }

  return {
    type: value.type,
    amount,
    name,
    categoryKey,
    walletName,
    date,
    confidence: value.confidence,
    warnings,
  };
}

function nullableTrimmedString(
  value: unknown,
  invalid: () => FunctionError,
): string | null {
  if (value === null) return null;
  if (typeof value !== "string" || !value.trim()) throw invalid();
  return value.trim();
}

function addWarning(warnings: string[], warning: string): void {
  if (!warnings.includes(warning)) warnings.push(warning);
}

function optionalString(value: unknown, locale: Locale): string | null {
  if (value === undefined || value === null) return null;
  if (typeof value !== "string" || !value.trim()) {
    throw new FunctionError("INVALID_REQUEST", 400, locale);
  }
  return value.trim();
}

function requiredNonEmptyString(value: unknown, locale: Locale): string {
  if (typeof value !== "string" || !value.trim()) {
    throw new FunctionError("INVALID_REQUEST", 400, locale);
  }
  return value.trim();
}

function isValidIsoDate(value: string): boolean {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) return false;
  const [, year, month, day] = match.map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  return date.getUTCFullYear() === year && date.getUTCMonth() === month - 1 &&
    date.getUTCDate() === day;
}

function isValidIsoLocalDateTime(value: string): boolean {
  const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?$/.exec(
    value,
  );
  if (!match) return false;
  const [, year, month, day, hour, minute, second] = match.map(Number);
  const date = new Date(Date.UTC(year, month - 1, day, hour, minute, second));
  return date.getUTCFullYear() === year && date.getUTCMonth() === month - 1 &&
    date.getUTCDate() === day && date.getUTCHours() === hour &&
    date.getUTCMinutes() === minute && date.getUTCSeconds() === second;
}

function isValidTimezone(value: string): boolean {
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: value }).format();
    return true;
  } catch {
    return false;
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" },
  });
}

function errorResponse(code: ErrorCode, status: number, locale: Locale): Response {
  return jsonResponse(
    {
      success: false,
      version: VERSION,
      error: { code, message: errorMessages[locale][code] },
    },
    status,
  );
}

function logMetadata(metadata: Record<string, unknown>): void {
  console.info(JSON.stringify(metadata));
}
