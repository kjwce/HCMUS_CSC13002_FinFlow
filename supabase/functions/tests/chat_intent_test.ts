import assert from "node:assert/strict";
import { describe, it } from "node:test";

import {
  classifyChatIntent,
  type ChatIntent,
  type IntentHistoryItem,
} from "../_shared/chat_intent.ts";

type EvalCase = {
  message: string;
  expected: ChatIntent;
  history?: IntentHistoryItem[];
};

const financeCases: EvalCase[] = [
  { message: "Số dư ví của tôi còn bao nhiêu?", expected: "app_finance" },
  { message: "Chi tiêu tuần này thế nào?", expected: "app_finance" },
  { message: "Cho tôi xem giao dịch gần đây", expected: "app_finance" },
  { message: "Ngân sách tháng này còn bao nhiêu?", expected: "app_finance" },
  { message: "Thu nhập tháng này của mình", expected: "app_finance" },
  { message: "Mục tiêu tiết kiệm tiến triển sao rồi?", expected: "app_finance" },
  { message: "Phân tích hóa đơn này", expected: "app_finance" },
  { message: "Đọc biên lai giúp mình", expected: "app_finance" },
  { message: "Ví của tôi có ổn không?", expected: "app_finance" },
  { message: "FinFlow có chức năng gì?", expected: "app_finance" },
  { message: "App này dùng như thế nào?", expected: "app_finance" },
  { message: "How do I use this app?", expected: "app_finance" },
  { message: "Show my spending this week", expected: "app_finance" },
  { message: "What is my current balance?", expected: "app_finance" },
  { message: "List my latest transactions", expected: "app_finance" },
  { message: "Am I over budget?", expected: "app_finance" },
  { message: "How much is in my wallet?", expected: "app_finance" },
  { message: "Analyze this receipt", expected: "app_finance" },
  { message: "How much did I spend?", expected: "app_finance" },
  { message: "Compare income and expenses", expected: "app_finance" },
  { message: "Add a transaction", expected: "app_finance" },
  { message: "Xóa giao dịch tiền cà phê", expected: "app_finance" },
  { message: "Mục tiêu tài chính của tôi", expected: "app_finance" },
  { message: "Tôi còn bao nhiêu tiền?", expected: "app_finance" },
  { message: "Tôi đã chi bao nhiêu tháng này?", expected: "app_finance" },
  { message: "Tháng này tôi xài có nhiều không?", expected: "app_finance" },
  { message: "Tiền của mình đang thế nào?", expected: "app_finance" },
  { message: "Ăn uống tháng này hết nhiều không?", expected: "app_finance" },
  { message: "How much was food this month?", expected: "app_finance" },
  { message: "Quét bill này giúp tôi", expected: "app_finance" },
  { message: "Give me financial advice based on my data", expected: "app_finance" },
  {
    message: "Thế còn tuần trước?",
    expected: "app_finance",
    history: [{ role: "user", message: "Chi tiêu tuần này bao nhiêu?" }],
  },
  {
    message: "What about last month?",
    expected: "app_finance",
    history: [{ role: "user", message: "Show my current spending" }],
  },
];

const generalCases: EvalCase[] = [
  { message: "Hú", expected: "general" },
  { message: "Alo bạn ơi", expected: "general" },
  { message: "Xin chào", expected: "general" },
  { message: "Hello", expected: "general" },
  { message: "Bạn tên gì?", expected: "general" },
  { message: "Kể tôi nghe một câu chuyện vui", expected: "general" },
  { message: "Hôm nay bạn khỏe không?", expected: "general" },
  { message: "Cảm ơn nha", expected: "general" },
  { message: "Dịch câu này sang tiếng Anh", expected: "general" },
  { message: "Gợi ý món ăn tối nay", expected: "general" },
  { message: "Viết lời chúc sinh nhật", expected: "general" },
  { message: "Giải thích AI là gì", expected: "general" },
  { message: "Cho mình một ví dụ dễ hiểu", expected: "general" },
  { message: "Mục tiêu học tập của mình là IELTS 7.0", expected: "general" },
  { message: "Ứng dụng học tiếng Anh nào tốt?", expected: "general" },
  { message: "Tell me a joke", expected: "general" },
  { message: "How is the weather today?", expected: "general" },
  { message: "Thanks for your help", expected: "general" },
  {
    message: "Thế còn hôm qua?",
    expected: "general",
    history: [{ role: "user", message: "Hôm nay thời tiết thế nào?" }],
  },
  {
    message: "What about last week?",
    expected: "general",
    history: [{ role: "user", message: "What movies are popular?" }],
  },
];

describe("chat intent evaluation set", () => {
  for (const [index, evalCase] of [...financeCases, ...generalCases].entries()) {
    it(`${index + 1}. routes ${JSON.stringify(evalCase.message)}`, () => {
      assert.equal(
        classifyChatIntent(evalCase.message, evalCase.history),
        evalCase.expected,
      );
    });
  }
});
