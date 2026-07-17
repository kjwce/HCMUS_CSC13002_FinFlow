export type ChatIntent = "general" | "app_finance";

export type IntentHistoryItem = {
  role: "user" | "assistant";
  message: string;
};

const financePatterns = [
  /\bfinflow\b/,
  /\b(app nay|ung dung nay|this app)\b/,
  /\b(app|application|ung dung)\b.*\b(finflow|wallet|budget|transaction|finance|tai chinh)\b/,
  /\b(use|using|dung|su dung)\b.*\b(app|application|ung dung|finflow)\b/,
  /\b(balance|wallet|transactions?|spending|expenses?|income|budget|savings?|financial|finance|receipts?|invoices?|bills?)\b/,
  /\b(spend|spent|earn|earned|save|saved)\b/,
  /\b(so du|giao dich|chi tieu|khoan chi|thu nhap|ngan sach|tiet kiem|tai chinh|hoa don|bien lai|dong tien)\b/,
  /\b(vi tien|vi cua toi|vi cua minh|muc tieu tai chinh|danh muc chi)\b/,
  /\b(tieu bao nhieu|con bao nhieu tien|kiem duoc bao nhieu|da chi|da tieu)\b/,
  /\b(tien bac|tien cua toi|tien cua minh|my money)\b/,
  /\b(tieu|xai|spend|spent)\b.*\b(tien|tuan|thang|week|month|today|hom nay)\b/,
  /\b(tuan|thang|week|month|today|hom nay)\b.*\b(tieu|xai|spend|spent)\b/,
  /\b(an uong|mua sam|di lai|food|shopping|transport)\b.*\b(tuan|thang|week|month)\b/,
  /\b(add|edit|delete|create|them|sua|xoa|tao)\b.*\b(transaction|wallet|budget|goal|giao dich|vi|ngan sach|muc tieu)\b/,
];

const followUpPatterns = [
  /^(and|but|then|so|what about|how about)\b/,
  /^(con|the|vay|roi|neu vay|so voi)\b/,
  /\b(last week|last month|previous week|previous month|tuan truoc|thang truoc)\b/,
  /\b(more|less|higher|lower|hon|kem|tang|giam)\b/,
];

export function classifyChatIntent(
  message: string,
  history: IntentHistoryItem[] = [],
): ChatIntent {
  const normalized = normalizeIntentText(message);
  if (matchesAny(normalized, financePatterns)) return "app_finance";

  const looksLikeFollowUp = normalized.length <= 100 &&
    matchesAny(normalized, followUpPatterns);
  if (!looksLikeFollowUp) return "general";

  const previousUserMessage = [...history]
    .reverse()
    .find((item) => item.role === "user")?.message;
  if (!previousUserMessage) return "general";
  return matchesAny(normalizeIntentText(previousUserMessage), financePatterns)
    ? "app_finance"
    : "general";
}

export function normalizeIntentText(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/đ/g, "d")
    .replace(/Đ/g, "D")
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function matchesAny(value: string, patterns: RegExp[]): boolean {
  return patterns.some((pattern) => pattern.test(value));
}
