import assert from "node:assert/strict";
import { describe, it } from "node:test";

import {
  localeFromReceiptBody,
  MAX_RECEIPT_IMAGE_BYTES,
  ReceiptFunctionError,
  sanitizeReceiptOutput,
  validateReceiptRequest,
} from "../_shared/receipt_parser.ts";

const categories = [
  { key: "Food", label: "Food" },
  { key: "Service", label: "Service" },
  { key: "Other", label: "Other" },
];

function expectCode(code: string): (error: unknown) => boolean {
  return (error) => error instanceof ReceiptFunctionError && error.code === code;
}

describe("receipt request validation", () => {
  it("accepts an image and normalizes request context", () => {
    const result = validateReceiptRequest(
      {
        imageBase64: btoa("receipt"),
        mimeType: "IMAGE/JPEG; charset=binary",
        locale: "en-US",
        categories,
      },
      "en-US",
    );

    assert.equal(result.mimeType, "image/jpeg");
    assert.equal(result.locale, "en-US");
    assert.equal(result.imageBytes, 7);
    assert.deepEqual(result.categories, categories);
  });

  it("defaults unsupported locales to Vietnamese", () => {
    assert.equal(localeFromReceiptBody({ locale: "fr-FR" }), "vi-VN");
    assert.equal(localeFromReceiptBody({ locale: "en-US" }), "en-US");
  });

  it("rejects empty, invalid, and oversized images", () => {
    assert.throws(
      () => validateReceiptRequest({ mimeType: "image/png", categories }, "vi-VN"),
      expectCode("EMPTY_IMAGE"),
    );
    assert.throws(
      () => validateReceiptRequest({
        imageBase64: "%%%",
        mimeType: "image/png",
        categories,
      }, "vi-VN"),
      expectCode("INVALID_REQUEST"),
    );
    const oversized = "A".repeat(
      Math.ceil((MAX_RECEIPT_IMAGE_BYTES + 1) * 4 / 3),
    );
    assert.throws(
      () => validateReceiptRequest({
        imageBase64: oversized,
        mimeType: "image/jpeg",
        categories,
      }, "vi-VN"),
      expectCode("IMAGE_TOO_LARGE"),
    );
  });

  it("rejects unsupported formats, duplicate categories, and userId", () => {
    assert.throws(
      () => validateReceiptRequest({
        imageBase64: btoa("image"),
        mimeType: "image/gif",
        categories,
      }, "vi-VN"),
      expectCode("UNSUPPORTED_IMAGE"),
    );
    assert.throws(
      () => validateReceiptRequest({
        imageBase64: btoa("image"),
        mimeType: "image/png",
        categories: [categories[0], categories[0]],
      }, "vi-VN"),
      expectCode("INVALID_REQUEST"),
    );
    assert.throws(
      () => validateReceiptRequest({
        imageBase64: btoa("image"),
        mimeType: "image/png",
        categories,
        userId: "must-not-be-trusted",
      }, "vi-VN"),
      expectCode("INVALID_REQUEST"),
    );
  });
});

describe("Gemini receipt output sanitization", () => {
  it("keeps valid items and receipt metadata", () => {
    const result = sanitizeReceiptOutput(
      {
        merchantName: "  FinFlow Cafe  ",
        receiptDate: "2026-07-18",
        currency: "VND",
        items: [
          {
            name: " Cà phê ",
            amount: 50000,
            categoryKey: "Food",
            confidence: 0.95,
            warning: null,
          },
          {
            name: "Massage",
            amount: 100000,
            categoryKey: "Service",
            confidence: 1.5,
            warning: "  kiểm tra lại  ",
          },
        ],
        totalAmount: 150000,
        warnings: [],
      },
      categories,
      "vi-VN",
    );

    assert.equal(result.merchantName, "FinFlow Cafe");
    assert.equal(result.items[0].name, "Cà phê");
    assert.equal(result.items[1].categoryKey, "Service");
    assert.equal(result.items[1].confidence, 1);
    assert.equal(result.items[1].warning, "kiểm tra lại");
    assert.equal(result.totalAmount, 150000);
  });

  it("falls back to Other and warns when totals do not match", () => {
    const result = sanitizeReceiptOutput(
      {
        merchantName: null,
        receiptDate: null,
        currency: null,
        items: [{
          name: "Unknown item",
          amount: 25000,
          categoryKey: "InventedCategory",
          confidence: -1,
          warning: null,
        }],
        totalAmount: 30000,
        warnings: ["", "Manual review"],
      },
      categories,
      "en-US",
    );

    assert.equal(result.items[0].categoryKey, "Other");
    assert.equal(result.items[0].confidence, 0);
    assert.equal(result.currency, "VND");
    assert.deepEqual(result.warnings, [
      "Manual review",
      "The receipt total does not match the item total. Please review it.",
    ]);
  });

  it("rejects empty or invalid line items", () => {
    assert.throws(
      () => sanitizeReceiptOutput({ items: [] }, categories, "vi-VN"),
      expectCode("NO_ITEMS_FOUND"),
    );
    assert.throws(
      () => sanitizeReceiptOutput(
        { items: [{ name: "", amount: 0 }] },
        categories,
        "vi-VN",
      ),
      expectCode("INVALID_MODEL_OUTPUT"),
    );
  });
});
