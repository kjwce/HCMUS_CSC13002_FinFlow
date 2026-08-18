# Nhiệm vụ 04 — Xóa Bank Import, cập nhật Notification & Chatbot

**Người phù hợp:** phụ trách refactor, dọn code cũ và Community/Chatbot UI.

**Phụ thuộc:** merge sau nhiệm vụ 01–03. Bản mới thay Bank Notification Import bằng recurring reminder trong Notification Center.

## File sửa `[M]`

- `lib/core/i18n/app_language.dart`
- `lib/features/chatbot/presentation/chat_screen.dart`
- `lib/features/community/models/notification_model.dart`
- `lib/features/community/presentation/notification_screen.dart`
- `lib/features/community/services/notification_service.dart`
- `test/features/chatbot/chat_screen_test.dart`

## File xóa `[D]`

- `android/app/src/main/kotlin/com/finflow/BankNotificationListenerService.kt`
- `android/app/src/main/kotlin/com/finflow/BankNotificationStore.kt`
- `android/app/src/main/kotlin/com/finflow/BankTransactionNotificationPresenter.kt`
- `android/app/src/main/kotlin/com/finflow/NotificationListenerRebindReceiver.kt`
- `android/hs_err_pid32496.log`
- `lib/features/notification_import/models/bank_notification_models.dart`
- `lib/features/notification_import/presentation/bank_notification_import_screen.dart`
- `lib/features/notification_import/services/bank_notification_configuration_migration.dart`
- `lib/features/notification_import/services/bank_notification_import_coordinator.dart`
- `lib/features/notification_import/services/bank_notification_import_service.dart`
- `lib/features/notification_import/services/bank_notification_platform.dart`
- `supabase/functions/parse-bank-notification/index.ts`
- `test/features/notification_import/bank_notification_import_service_test.dart`
- `test/features/notification_import/bank_notification_models_test.dart`

## Ghi chú

- File `android/hs_err_pid32496.log` là crash log, không phải mã nguồn.
- Sau khi xóa, kiểm tra không còn import/reference đến `notification_import` hoặc `parse-bank-notification`.
- Commit đề xuất: `refactor: replace bank notification import with recurring reminders`
