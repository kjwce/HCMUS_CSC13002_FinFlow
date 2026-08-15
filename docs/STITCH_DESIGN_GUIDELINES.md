# Stitch Design Guidelines

This document is for Google Stitch AI or other AI design tools generating FinFlow mobile UI.

## Visual Identity

FinFlow is a friendly personal finance app with a clean green identity. The product should feel practical, trustworthy, and lightweight rather than corporate or decorative.

Design cues from the current app:

- Finance-focused green palette.
- Soft rounded surfaces.
- Large mobile touch targets.
- Simple iconography.
- Friendly budget and savings visuals.
- Vietnamese bank and e-wallet context.

## Design Language

- Mobile-first.
- Material 3 influenced.
- Clean dashboard surfaces with strong hierarchy.
- Use soft green backgrounds and white content panels.
- Use blue accents for scan, secondary amounts, and chart details.
- Use coral/red only for warnings, delete actions, or negative states.

Avoid:

- Heavy gradients except existing cover/header areas.
- Dense desktop-style tables.
- Overly decorative illustrations.
- Marketing landing-page layouts.

## Mobile-First Principles

- Primary target is a phone viewport.
- Design for one-handed interaction where possible.
- Bottom navigation is the main app navigation.
- Keep primary actions reachable near the bottom or in obvious card actions.
- Use scrollable vertical layouts for content-heavy screens.
- Avoid horizontal overflow except charts that intentionally scroll.

## Material 3

Use Material 3 conventions:

- Rounded buttons.
- Cards and surfaces with clear elevation or contrast.
- Filled inputs.
- Segmented controls for period filters and income/expense choices.
- Modal bottom sheets for creation and selection flows.
- Snackbars for short feedback.
- Dialogs for destructive confirmation.

## Color Palette

Inferred core colors:

- Primary green: bright mint/emerald, used for main buttons and selected states.
- Light green: pale mint background for navigation and input surfaces.
- Dark green text: near-black green for headings and labels.
- Blue accent: used for scan UI, secondary transaction amounts, chart accents.
- Coral/red: used for expenses, warnings, delete actions.
- White: primary card and form surface.
- Muted gray: helper text and empty states.

Use green as the brand anchor, but do not make every element the same hue. Use white space and blue/coral accents to separate meaning.

## Typography

Existing UI mixes `Poppins` and `Roboto`.

Guidelines:

- Use Poppins for headings, prominent labels, profile names, buttons.
- Use Roboto for general Material text where appropriate.
- Keep mobile headings around 18-24px.
- Use 12-15px for dense labels, transaction metadata, and chips.
- Avoid oversized hero typography except launch/onboarding brand screens.

## Component Styles

Buttons:

- Primary: green filled, rounded pill or rounded rectangle.
- Secondary: pale green filled or text button.
- Destructive: red text or red outlined.

Inputs:

- Filled backgrounds.
- Rounded corners.
- Clear label/hint.
- Numeric fields should support VND formatting visually.

Icon buttons:

- Circular or compact rounded containers.
- Use existing icon style and sizes.

## Card Styles

Use cards for:

- Dashboard chart blocks.
- Goal summary.
- Profile/settings menu sections.
- Transaction-like repeated items when needed.

Card guidance:

- White or green surface depending on importance.
- Rounded corners, commonly 12-30px in current screens.
- Avoid nesting cards inside cards.
- Use subtle shadow only where needed.

## Forms

Forms should be short and task-focused:

- Auth forms: email/password/name.
- Budget forms: single amount input.
- Profile forms: name, phone, email, avatar.
- Transaction forms: amount, account, category.

Use immediate validation feedback through snackbars or inline hints. Keep input sizes comfortable for mobile.

## Dashboard Layout

Home dashboard:

- Top visual header with greeting, notification, chart shortcut.
- Balance and expense summary near top.
- Budget progress bar.
- Goal summary card.
- Period selector.
- Recent transactions list.
- Floating `View All` action centered above the bottom navigation bar.

Transaction history:

- Group transactions by day with clear section headers.
- Provide quick insights for weekly spending and top category.
- Show a clear empty state when filters remove all rows.

Analytics dashboard:

- Header with back button.
- Vertical list of chart cards.
- Each chart card includes title, period selector, and chart body.
- Show empty state when there is no data.

## Bottom Navigation

Current navigation is a floating pill with 5 slots:

- Home.
- Chatbot (AI financial assistant).
- **Add** — center circular FAB that opens the Add Transaction sheet.
- Community.
- Profile.

The center Add action is visually emphasized with a circular FAB that animates a plus→close rotation on tap. Keep selected states obvious with a filled green/blue background. (The AI-analysis and Scan screens from the earlier design are no longer separate tabs — Scan is reachable from Add Transaction's Scan mode, and the AI assistant lives in the Chatbot tab.)

## Spacing

Use consistent mobile spacing:

- Screen horizontal padding: about 20-24px.
- Section gaps: about 16-32px.
- Row item gaps: about 8-16px.
- Bottom padding above nav: enough to avoid clipping, often around 80-100px for scroll content.

## Responsive Rules

The app uses a custom `Responsive` helper. Designs should specify relative spacing and dimensions that can scale from a base phone size.

Avoid:

- Fixed desktop widths.
- Tiny tap targets.
- Text that only fits in English.
- Unbounded chart or list layouts.

## Auto Layout Requirements

For Stitch-generated designs:

- Use vertical auto layout for screen content.
- Use horizontal auto layout for rows.
- Make transaction rows flexible: icon fixed, middle text expands, amount fixed.
- Cards should have intrinsic height or defined minimum height.
- Chart cards should have fixed chart areas and flexible labels.
- Use constraints so text wraps or truncates intentionally.

## Reusable Components

Create reusable components for:

- Primary button.
- Secondary button.
- Amount input.
- Category circle.
- Wallet/bank picker item.
- Transaction row.
- Goal summary card.
- Period segmented control.
- Notification bell.
- Bottom navigation item.
- Profile/settings menu row.
- Chart card.

## UI Consistency Rules

- Keep financial numbers consistently formatted as VND.
- Positive income should use plus sign or green/dark text.
- Expenses should use minus sign and blue/coral depending on existing context.
- Use the same icons for the same concepts across screens.
- Preserve existing brand tone: simple, calm, finance-oriented.
- Do not replace bank/e-wallet logos with generic placeholders unless the asset is unavailable.
