# FinFlow - Stitch Prompts for Missing UI

These prompts are based on the current FinFlow Android app, its Flutter theme, and the PA02 design document. They are intended to be pasted into Google Stitch one prompt at a time.

## Shared visual context

Prepend this block to every prompt when Stitch does not retain project context:

```text
Design a production-ready mobile UI for FinFlow, a friendly personal finance app. Match the existing FinFlow Android app exactly: mobile-first 390x844 viewport, very pale mint page background (#F3FBF6), white cards, primary emerald (#0D8F5A), deep emerald (#075E45), bright mint action accent (#00D09E), dark green-black text (#052224), muted gray-green text (#6D7B74), coral/red only for warnings and destructive actions, and amber for caution. Use Material 3 conventions, large comfortable touch targets, rounded cards (14-24 px), subtle green-tinted shadows, thin dividers, and generous 16-24 px spacing. Use Manrope for strong headings and Hanken Grotesk for body/metadata, matching the existing Community and Goal screens. Support both light and dark mode. Layout must allow Vietnamese labels to be longer than English labels without clipping. Do not redesign the app shell. Use the existing floating pill bottom navigation only on top-level tab screens: Home, Chatbot, center Add FAB, Community, Profile.
```

## 1. Community post menu in the real feed - required

```text
Create one polished, realistic FinFlow Community Feed mobile screen. This must look like the actual consumer app, not a component library, wireframe, design-system page, specification sheet, or menu showcase. Do not use headings such as "Menus Spec", "Author View", "Viewer View", "Post Variant", or "Comment Variant". Do not place multiple menu examples on one screen.

Preserve the existing Community layout:
- pale mint page background;
- top header titled "Financial advice" with a notification bell;
- horizontal topic chips: All, Budgeting, Saving, Debt-free, Investing, General;
- realistic vertical feed of white post cards;
- floating pill bottom navigation with Community selected;
- "What's on your mind?" composer bar above the bottom navigation.

The main post card should contain a realistic avatar, author name, timestamp, Saving topic chip, two or three lines of financial advice, one optional lifestyle/finance photo, and Like, Comment and Save actions. Add a subtle three-dot icon at the top-right of every post.

Show the three-dot menu OPEN only for one post written by another user. Anchor a compact elevated popup directly below the icon. The popup contains one row only: an outlined flag icon and "Report post". Use a white surface, 12 px rounded corners, thin neutral border, subtle shadow, 48 px minimum row height and dark green text. Use a muted coral flag icon without making the whole row bright red. The popup should feel like a natural overlay inside the existing social feed.

Other posts remain visible behind it and do not show open menus. Do not create a dark-mode sample on the same canvas. Generate only the light-mode production screen at 390x844.
```

### 1B. Comment menu in Post Details

```text
Using the same FinFlow Community visual style, create one realistic Post Details mobile screen, not a component specification page. Show the full post at the top and a natural threaded comments section below it with avatars, names, timestamps, Like, Reply and View replies controls.

Show the three-dot menu OPEN for exactly one comment written by another user. Anchor a compact white popup below that comment's three-dot icon. It contains one row only: outlined flag icon plus "Report comment". Use 12 px rounded corners, thin neutral border, subtle shadow, comfortable 48 px touch height, dark green text and a muted coral flag. Keep all other comments in their normal closed state.

Do not display labels such as Author View, Viewer View, Comment Variant, UI Spec, Light or Dark. Do not place multiple menu variants side by side. Generate one light-mode production screen at 390x844.
```

## 2. Report post/comment centered dialog and states - required

```text
Design a keyboard-aware Material 3 centered modal dialog for reporting Community content in FinFlow. This must be a popup centered on the screen, not a bottom sheet, full-screen page, component specification, or design-system canvas. Show the real Community Feed or Post Details screen dimmed behind the dialog. Use the same reusable dialog component for Post and Comment variants.

Dialog layout:
- centered with balanced space around it, approximately 88-92% of the phone width and no more than 82% of the available height;
- white surface in light mode or FinFlow dark elevated surface in dark mode;
- 20-24 px rounded corners, thin neutral border and soft green-tinted shadow;
- no drag handle;
- close X icon in the top-right corner;
- title "Report post" or "Report comment";
- helper text explaining that reports are confidential;
- a compact preview card containing the reported author's avatar/name and two lines of the content;
- single-select reason rows with radio controls: Spam or misleading, Scam or fraud, Harassment or hate, Unsafe or illegal content, Privacy violation, and Other;
- an optional multiline "Add details" field, maximum 240 characters, with character counter;
- a scrollable content area if the dialog becomes taller than the viewport or when the keyboard is open;
- a fixed action area inside the bottom of the dialog, separated from the form by a thin divider;
- a quiet Cancel text button and a prominent emerald "Submit report" button placed side by side, with Submit receiving more width;
- the submit button is disabled until a reason is selected;
- loading state inside the button without changing its size.

Create the main report form as one realistic production screen. Create the following result dialogs as separate screens/frames, never displayed together on the same phone canvas:
1) Success dialog: green check icon, "Report submitted", short reassurance, and one emerald Done button.
2) Already reported dialog: amber info icon, "You already reported this content", explanatory text, and one Close button.

Use coral only for the flag icon and caution emphasis; keep the main submit button FinFlow emerald so the dialog does not feel like a destructive delete flow. Generate the polished light-mode form first. Produce a dark-mode variant only when requested separately; do not place light and dark dialogs on the same canvas.
```

## 3. Community Moderation Center - required if moderators use the app

```text
Design a full-screen mobile "Moderation Center" for authorized FinFlow moderators. This screen is not visible to normal users and is opened from a moderator-only Profile menu. Preserve the FinFlow visual system; do not create a desktop admin table.

Include:
- top app bar with back button, title "Moderation Center", and overflow menu;
- summary strip with Pending, In review, Resolved counts;
- segmented filter chips: Pending, In review, Resolved, Dismissed;
- secondary filters for Posts, Comments, reason, and newest/oldest;
- search by report ID, author, or content keyword;
- vertically scrolling report cards showing content type, reason chip, truncated reported content, reported author, number of reports on the same content, submitted time, and current status;
- high-priority repeated reports have an amber left accent, never an aggressive red background;
- pull-to-refresh, skeleton loading, empty state, error state and pagination/loading footer.

Each card opens Report Detail. Do not include the normal five-item bottom navigation inside this operational screen. Make the design usable on a narrow Android phone and provide a dark-mode variant.
```

## 4. Moderation report detail and decision flow - required if moderators use the app

```text
Design a mobile FinFlow "Report Detail" screen for a moderator.

Content hierarchy:
- app bar with back button, report ID and status chip;
- reported content preview that clearly distinguishes Post versus Comment, including author, timestamp, topic and parent-post context for comments;
- report information card: reason, optional reporter description, reporter identity, submitted date, and count of unique reporters;
- compact moderation history timeline showing status changes and moderator notes;
- collapsible "Related reports" section;
- private moderator notes field.

Sticky bottom action area:
- secondary "Dismiss" button;
- primary "Resolve" button;
- overflow action for Hide content, Restore content, or Warn user;
- require a confirmation dialog before hiding content or warning a user;
- destructive actions use coral/red, normal resolution uses emerald.

Design Pending, In review, Resolved and Content unavailable states. Keep the screen calm, evidence-focused and consistent with FinFlow cards rather than a law-enforcement aesthetic. Include light and dark variants.
```

## 5. Spending and budget notification preferences - required

FinFlow currently has a Push Notifications master switch in App Settings. When this detailed page is implemented, replace that switch row with a navigation row named "Notification Preferences" and a trailing chevron. Move the master notification switch into this new page so there is only one source of truth.

```text
Create one polished production-ready FinFlow mobile screen titled "Notification Preferences" at 390x844. It is opened from Profile > App Settings > Notification Preferences. This must look like the current FinFlow Profile and Settings screens, not a generic Android settings page, wireframe, component specification, or dense admin form.

Visual direction:
- very pale mint background (#F3FBF6);
- centered app-bar title with a simple back arrow; no overflow menu;
- 20 px horizontal page padding and generous vertical spacing;
- white rounded cards with 18-20 px corners, subtle green-tinted shadow and thin #E6EAE8 dividers;
- Manrope headings and Hanken Grotesk body text;
- emerald switches and selected states;
- small colored icon bubbles to distinguish Budget, Recurring and Community groups;
- calm, spacious and premium personal-finance appearance.

Use a vertically scrollable layout. Do not shrink typography or compress all content to force every row above the fold. It is acceptable for lower sections to continue below the viewport.

At the top, create a compact hero control card titled "Notifications" with a soft emerald bell icon, helper text "Stay informed about your money", and one large master switch aligned to the right. Add the subtle status text "All alerts are on" when enabled. Do not place an error banner inside this card.

Create a section titled "Spending & budgets" as one white settings card with four spacious rows:
1) Daily budget - "Alert me as I approach today's limit" - enabled - threshold pill "80%"
2) Weekly budget - "Track this week's spending limit" - enabled - threshold pill "80%"
3) Monthly budget - "Stay within my monthly plan" - enabled - threshold pill "90%"
4) Category budgets - "Alerts for individual categories" - enabled - trailing text "Manage" with a chevron

Every row includes a distinct soft-colored 36 px icon bubble, title, one-line helper text, and a switch aligned to the far right. Place the small threshold pill below the helper text so it never collides with the switch. Do not display 70%, 80%, 90%, 100% and Custom chips together on this screen. Tapping a threshold pill opens a separate selector dialog.

Create a section titled "Recurring reminders" as a separate white card with three rows:
1) Recurring expenses - enabled - helper text "Bills, rent and subscriptions"
2) Recurring income - enabled - helper text "Salary and regular income"
3) Reminder timing - no switch - trailing value "1 day before" with a chevron

Add a small secondary option below these rows: "Schedule issues" with helper text "Notify me when a recurring transaction fails or is skipped" and an enabled switch. Use warm amber only for the schedule-issues icon, not as a warning panel.

Create a section titled "Community activity" as another white card with three rows:
1) Likes - enabled - "When someone likes my post or comment"
2) Comments & replies - enabled - "New comments and replies to my content"
3) New community posts - disabled - "Highlights from the FinFlow community"

Preferences save immediately when a switch changes, so do not add a large Save button. A small floating "Preferences updated" snackbar belongs to a separate result frame and must not be permanently visible on the main screen.

Keep the normal FinFlow floating pill bottom navigation fixed at the bottom with Profile selected. Give scroll content enough bottom padding so the last Community row is never hidden behind the navigation.

Do not show permission errors, loading indicators, snackbar, threshold dialog, dark mode, or multiple states on the same canvas. Generate only the clean light-mode main screen first. Keep labels comfortably readable around 13-16 px and ensure Vietnamese translations can wrap without colliding with switches, pills or chevrons. Do not use tiny uppercase labels, cramped chip rows, large red panels, or excessive empty space.
```

### 5B. Notification threshold selector dialog

```text
Using the same FinFlow style, design one centered modal dialog titled "Alert threshold" over a dimmed Notification Preferences screen. The dialog contains selectable rows for 70%, 80%, 90%, 100% and Custom, with 80% selected using an emerald radio indicator. Include short explanations such as "Early reminder" or "When the limit is reached". Use a 20 px rounded white dialog, Cancel text action and emerald Apply button. Do not show all threshold options directly on the main preferences screen.
```

### 5C. Permission denied state

```text
Create a separate alternate state of the Notification Preferences screen for denied system notification permission. Keep the clean screen unchanged and add one slim amber inline banner directly below the master Notifications card. Use an outlined bell-slash icon, title "Notifications are turned off", one sentence of helper text, and a compact "Open settings" action. Do not use a large red error card. Do not combine this state with success snackbar, loading state or dark mode on the same canvas.
```

### 5D. Recurring reminder timing dialog

```text
Using the same FinFlow style, design one centered modal dialog titled "Reminder timing" over a dimmed Notification Preferences screen. Show radio-list choices: On due date, 1 day before, 3 days before, 1 week before and Custom. Select "1 day before" with an emerald radio indicator. Add a short helper sentence explaining that the same timing applies to enabled recurring expenses and recurring income. Use a 20 px rounded white dialog, Cancel text action and emerald Apply button. Do not place this dialog beside other states on the same canvas.
```

## 6. Goal Activity history - required

```text
Design a full-screen mobile "Goal Activity" history page opened by tapping View All on FinFlow Goal Details. Match the existing Goal Details theme and do not redesign the goal system.

Include:
- top app bar with back button and title "Goal Activity";
- compact goal summary card containing goal icon, goal name, saved amount / target amount, progress bar and achieved percentage;
- filter chips: All, Money added, Withdrawals, Automatic, Redirected;
- optional date-range filter icon;
- chronological activity list grouped by month and date;
- each row shows a semantic icon, activity title, source or destination, timestamp, signed VND amount and resulting goal balance;
- green/emerald for allocations and income redirects, coral/red for withdrawals, blue for automatic/system activity;
- expandable row detail for source transaction ID, note and balance before/after;
- empty state, filtered-empty state, loading skeleton and pagination footer.

Use white rounded cards, subtle green shadow, Manrope headings and Hanken Grotesk metadata. No bottom navigation is needed because this is a detail route. Provide light and dark variants and ensure long Vietnamese activity labels wrap cleanly.
```

## 7. Help and Support hub - required

```text
Design a full-screen mobile "Help & Support" hub opened from the FinFlow Profile menu. Match the current Profile/Settings design.

Include:
- app bar with back button, centered title and notification bell only if consistent with existing Profile child screens;
- friendly header card with a small FinFlow icon and the message "How can we help?";
- rounded search field for FAQs;
- quick action grid: Browse FAQs, Chat with us, Email support, Report a problem;
- help categories in rounded list rows: Account & Security, Transactions, Budgets, Saving Goals, Recurring Payments, AI & Receipt Scan, Community & Safety;
- Popular articles list with chevrons;
- app version and privacy/terms links at the bottom.

Also create a Chat with us bottom-sheet variant with support availability, short issue-category selector, message field, attachment action and Start chat button. Add an offline state that offers email support. Keep the five-item bottom navigation visible with Profile selected on the hub, but not inside an opened article or chat sheet. Provide light and dark variants.
```

## 8. Change email and verification flow - required if PA02's editable email requirement is retained

```text
Design a secure two-step mobile Change Email flow for FinFlow, entered from Edit Profile or Security.

Screen 1 - Change Email:
- app bar with back button and centered title;
- current email in a read-only rounded field;
- new email field with inline validation;
- current password field with show/hide icon;
- short security note explaining that a verification code will be sent to the new address;
- full-width emerald "Send verification code" button pinned near the bottom;
- loading and backend-error states.

Screen 2 - Verify New Email:
- back button and title "Verify new email";
- illustration/icon consistent with FinFlow OTP screens;
- masked new email address;
- six separate OTP input boxes with auto-advance and paste support;
- resend countdown and Change email link;
- full-width emerald Verify button;
- incorrect-code inline error, expired-code state, loading state and success confirmation.

Use the existing pale mint authentication/profile surfaces, green outlines on focused fields, large touch targets, Manrope/Hanken Grotesk typography and bilingual-safe layout. Do not add social login or unrelated profile fields. Provide light and dark variants.
```

## 9. Goal cover image picker - optional enhancement

```text
Extend the existing FinFlow Create Goal and Edit Goal form with an optional goal cover image section. Do not create a separate goal form or change the existing fields.

At the top of the form, below the title:
- a wide 16:9 rounded cover preview with the selected goal category icon as the default placeholder;
- a compact "Add cover" or "Change cover" action;
- when an image exists, show Change and Remove actions without covering the preview;
- include an upload progress state and failed-upload retry state.

Design the image source bottom sheet with Camera, Photo library and Remove cover actions. Add a simple crop/position preview state, but keep it lightweight. Match the existing Goal screen's rounded white cards, emerald controls and purple category accents. Provide light and dark variants.
```

## Items that do not need new Stitch UI

- Delete account already has a Security screen, destructive confirmation dialog, loading state and error snackbar. It needs its missing Supabase Edge Function, not another design.
- Custom category creation already has UI. It needs database persistence.
- Community image upload already has picker and preview UI.
- OAuth provider mismatch is a product decision and icon/provider change, not a new screen.
- The empty Recurring Forecast "Details" callback is inside retained legacy code that is currently unused, so it should not drive a new design unless the forecast feature is reactivated.
