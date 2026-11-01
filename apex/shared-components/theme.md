# HRMS Universal Theme

## Decision

Use the APEX Universal Theme for the target APEX 26.2 application. Retain the supplied responsive templates and theme defaults for the first release; no custom theme, custom JavaScript framework, or brand palette has been approved.

## Page and component conventions

- Use the Universal Theme responsive grid and standard page templates for desktop and tablet layouts. Avoid fixed-width pages and horizontal scrolling for primary workflows.
- Use consistent page titles, breadcrumbs, region headings, form labels, required-field indicators, validation messages, and success notifications.
- Use a visible primary action and reserve destructive styling for irreversible or sensitive operations. Do not communicate status or errors with color alone.
- Prefer native APEX components and template options. Keep custom CSS limited to documented, reusable exceptions; do not override core Universal Theme selectors.
- Use modal dialogs only for short, focused selection or confirmation tasks. Keep the primary HRMS workflows in normal navigable pages.
- Preserve visible keyboard focus, logical tab order, semantic headings, descriptive link text, and accessible names for icon-only controls.
- Ensure responsive tables and reports remain usable without losing required labels or action access on tablet.

## Accessibility and visual validation

Before release, run the APEX accessibility checks and manually test keyboard-only navigation, focus visibility, field labels, validation and error announcements, dialog behavior, and contrast on the six priority workflows. Use the approved organizational brand assets and palette only after they are supplied and checked for contrast.

Universal Theme is a presentation layer, not a security control. Page and component visibility must follow the authorization rules in `authorization.md`, and all data access remains enforced server-side.
