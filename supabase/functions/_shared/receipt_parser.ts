export const RECEIPT_RESPONSE_VERSION = 1;
export const MAX_RECEIPT_IMAGE_BYTES = 8 * 1024 * 1024;

const supportedImageTypes = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/heic",
  "image/heif",
]);

export type ReceiptLocale = "vi-VN" | "en-US";

export type ReceiptErrorCode =
  | "UNAUTHORIZED"
  | "INVALID_REQUEST"
  | "EMPTY_IMAGE"
  | "IMAGE_TOO_LARGE"
  | "UNSUPPORTED_IMAGE"
  | "NO_ITEMS_FOUND"
  | "GEMINI_RATE_LIMITED"
  | "GEMINI_TIMEOUT"
  | "GEMINI_UNAVAILABLE"
  | "INVALID_MODEL_OUTPUT"
  | "INTERNAL_ERROR";

export type ReceiptCategoryInput = {
  key: string;
  label: string;
};

export type ValidatedReceiptRequest = {
  imageBase64: string;
  mimeType: string;
  locale: ReceiptLocale;
  categories: ReceiptCategoryInput[];
  imageBytes: number;
};

export type ParsedReceiptItem = {
  name: string;
  amount: number;
  categoryKey: string | null;
  confidence: number;
  warning: string | null;
};

export type ParsedReceiptData = {
  merchantName: string | null;
  receiptDate: string | null;
  currency: string;
  items: ParsedReceiptItem[];
  totalAmount: number;
  warnings: string[];
};

export class ReceiptFunctionError extends Error {
  readonly code: ReceiptErrorCode;
  readonly status: number;
  readonly locale: ReceiptLocale;

  constructor(
    code: ReceiptErrorCode,
    status: number,
    locale: ReceiptLocale,
  ) {
    super(code);
    this.code = code;
    this.status = status;
    this.locale = locale;
  }
}

const errorMessages: Record<
  ReceiptLocale,
  Record<ReceiptErrorCode, string>
> = {
  "vi-VN": {
    UNAUTHORIZED: "Phiên đăng nhập không hợp lệ.",
    INVALID_REQUEST: "Dữ liệu yêu cầu không hợp lệ.",
    EMPTY_IMAGE: "Ảnh hóa đơn không được để trống.",
    IMAGE_TOO_LARGE: "Ảnh hóa đơn quá lớn.",
    UNSUPPORTED_IMAGE: "Định dạng ảnh hóa đơn không được hỗ trợ.",
    NO_ITEMS_FOUND: "Không tìm thấy món ăn hoặc dịch vụ nào.",
    GEMINI_RATE_LIMITED: "Dịch vụ phân tích đang quá tải. Vui lòng thử lại sau.",
    GEMINI_TIMEOUT: "Dịch vụ phân tích phản hồi quá chậm. Vui lòng thử lại.",
    GEMINI_UNAVAILABLE: "Dịch vụ phân tích hiện không khả dụng.",
    INVALID_MODEL_OUTPUT: "Kết quả phân tích hóa đơn không hợp lệ.",
    INTERNAL_ERROR: "Đã xảy ra lỗi nội bộ.",
  },
  "en-US": {
    UNAUTHORIZED: "The authenticated session is invalid.",
    INVALID_REQUEST: "Invalid request data.",
    EMPTY_IMAGE: "The receipt image must not be empty.",
    IMAGE_TOO_LARGE: "The receipt image is too large.",
    UNSUPPORTED_IMAGE: "The receipt image format is not supported.",
    NO_ITEMS_FOUND: "No food or service items were found.",
    GEMINI_RATE_LIMITED: "The parsing service is busy. Please try again later.",
    GEMINI_TIMEOUT: "The parsing service took too long. Please try again.",
    GEMINI_UNAVAILABLE: "The parsing service is currently unavailable.",
    INVALID_MODEL_OUTPUT: "The receipt parser returned invalid data.",
    INTERNAL_ERROR: "An internal error occurred.",
  },
};

export function receiptErrorMessage(
  code: ReceiptErrorCode,
  locale: ReceiptLocale,
): string {
  return errorMessages[locale][code];
}

export function localeFromReceiptBody(body: unknown): ReceiptLocale {
  return isRecord(body) && body.locale === "en-US" ? "en-US" : "vi-VN";
}

export function validateReceiptRequest(
  body: unknown,
  locale: ReceiptLocale,
): ValidatedReceiptRequest {
  if (!isRecord(body) || Object.hasOwn(body, "userId")) {
    throw new ReceiptFunctionError("INVALID_REQUEST", 400, locale);
  }

  const imageBase64 = typeof body.imageBase64 === "string"
    ? body.imageBase64.trim()
    : "";
  if (!imageBase64) {
    throw new ReceiptFunctionError("EMPTY_IMAGE", 400, locale);
  }

  const mimeType = typeof body.mimeType === "string"
    ? body.mimeType.split(";", 1)[0].trim().toLowerCase()
    : "";
  if (!supportedImageTypes.has(mimeType)) {
    throw new ReceiptFunctionError("UNSUPPORTED_IMAGE", 415, locale);
  }

  const imageBytes = estimateBase64Bytes(imageBase64);
  if (!Number.isSafeInteger(imageBytes) || imageBytes <= 0) {
    throw new ReceiptFunctionError("INVALID_REQUEST", 400, locale);
  }
  if (imageBytes > MAX_RECEIPT_IMAGE_BYTES) {
    throw new ReceiptFunctionError("IMAGE_TOO_LARGE", 413, locale);
  }
  try {
    atob(imageBase64);
  } catch {
    throw new ReceiptFunctionError("INVALID_REQUEST", 400, locale);
  }

  const categories = validateCategories(body.categories, locale);
  return { imageBase64, mimeType, locale, categories, imageBytes };
}

export function sanitizeReceiptOutput(
  value: unknown,
  categories: ReceiptCategoryInput[],
  locale: ReceiptLocale,
): ParsedReceiptData {
  if (!isRecord(value) || !Array.isArray(value.items)) {
    throw new ReceiptFunctionError("INVALID_MODEL_OUTPUT", 502, locale);
  }

  const allowed = new Set(categories.map((category) => category.key));
  const hasOther = allowed.has("Other");
  const items = value.items.map((raw): ParsedReceiptItem => {
    if (!isRecord(raw)) {
      throw new ReceiptFunctionError("INVALID_MODEL_OUTPUT", 502, locale);
    }

    const name = typeof raw.name === "string" ? raw.name.trim() : "";
    const amount = raw.amount;
    if (
      !name ||
      typeof amount !== "number" ||
      !Number.isSafeInteger(amount) ||
      amount <= 0
    ) {
      throw new ReceiptFunctionError("INVALID_MODEL_OUTPUT", 502, locale);
    }

    const rawCategory = typeof raw.categoryKey === "string"
      ? raw.categoryKey.trim()
      : "";
    const categoryKey = allowed.has(rawCategory)
      ? rawCategory
      : hasOther
      ? "Other"
      : null;

    return {
      name,
      amount,
      categoryKey,
      confidence: clampConfidence(raw.confidence),
      warning: optionalString(raw.warning),
    };
  });

  if (items.length === 0) {
    throw new ReceiptFunctionError("NO_ITEMS_FOUND", 422, locale);
  }

  const calculatedTotal = items.reduce((sum, item) => sum + item.amount, 0);
  const totalAmount =
    typeof value.totalAmount === "number" &&
      Number.isSafeInteger(value.totalAmount) &&
      value.totalAmount >= 0
      ? value.totalAmount
      : calculatedTotal;
  const warnings = Array.isArray(value.warnings)
    ? value.warnings
      .filter((item): item is string => typeof item === "string")
      .map((item) => item.trim())
      .filter(Boolean)
    : [];

  if (totalAmount > 0 && totalAmount !== calculatedTotal) {
    warnings.push(
      locale === "vi-VN"
        ? "Tổng hóa đơn và tổng các dòng chưa khớp. Vui lòng kiểm tra lại."
        : "The receipt total does not match the item total. Please review it.",
    );
  }

  return {
    merchantName: optionalString(value.merchantName),
    receiptDate: optionalString(value.receiptDate),
    currency: optionalString(value.currency) || "VND",
    items,
    totalAmount,
    warnings: [...new Set(warnings)],
  };
}

export function extractGeminiText(value: unknown): string {
  if (!isRecord(value) || !Array.isArray(value.candidates)) return "";
  const candidate = value.candidates[0];
  if (!isRecord(candidate) || !isRecord(candidate.content)) return "";
  const parts = candidate.content.parts;
  if (!Array.isArray(parts)) return "";
  const text = parts.find(
    (part) => isRecord(part) && typeof part.text === "string",
  );
  return isRecord(text) && typeof text.text === "string" ? text.text : "";
}

export function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function validateCategories(
  value: unknown,
  locale: ReceiptLocale,
): ReceiptCategoryInput[] {
  if (!Array.isArray(value) || value.length === 0) {
    throw new ReceiptFunctionError("INVALID_REQUEST", 400, locale);
  }

  const seen = new Set<string>();
  return value.map((item) => {
    if (
      !isRecord(item) ||
      typeof item.key !== "string" ||
      typeof item.label !== "string"
    ) {
      throw new ReceiptFunctionError("INVALID_REQUEST", 400, locale);
    }
    const key = item.key.trim();
    const label = item.label.trim();
    if (!key || !label || seen.has(key)) {
      throw new ReceiptFunctionError("INVALID_REQUEST", 400, locale);
    }
    seen.add(key);
    return { key, label };
  });
}

function estimateBase64Bytes(value: string): number {
  const padding = value.endsWith("==") ? 2 : value.endsWith("=") ? 1 : 0;
  return Math.floor(value.length * 3 / 4) - padding;
}

function clampConfidence(value: unknown): number {
  if (typeof value !== "number" || !Number.isFinite(value)) return 0;
  return Math.max(0, Math.min(1, value));
}

function optionalString(value: unknown): string | null {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}
