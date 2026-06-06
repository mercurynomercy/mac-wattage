---
name: ui-ux-pro-max
description: "UI/UX design intelligence for web and mobile. Includes 50+ styles, 161 color palettes, 57 font pairings, 161 product types, 99 UX guidelines, and 25 chart types across 10 stacks (React, Next.js, Vue, Svelte, SwiftUI, React Native, Flutter, Tailwind, shadcn/ui, and HTML/CSS). Actions: plan, build, create, design, implement, review, fix, improve, optimize, enhance, refactor, and check UI/UX code. Projects: website, landing page, dashboard, admin panel, e-commerce, SaaS, portfolio, blog, and mobile app. Elements: button, modal, navbar, sidebar, card, table, form, chart. Styles: glassmorphism, claymorphism, minimalism, brutalism, neumorphism, bento grid, dark mode, responsive, skeuomorphism, and flat design. Topics: color systems, accessibility, animation, layout, typography, font pairing, spacing, interaction states, shadow, and gradient. Integrations: shadcn/ui MCP for component search and examples."
---

# UI/UX Pro Max - Design Intelligence

Comprehensive design guide for web and mobile applications. Contains 50+ styles, 161 color palettes, 57 font pairings, 161 product types with reasoning rules, 99 UX guidelines, and 25 chart types across 10 technology stacks. Searchable database with priority-based recommendations.

## When to Apply

This Skill should be used when the task involves **UI structure, visual design decisions, interaction patterns, or user experience quality control**.

### Must Use

This Skill must be invoked in the following situations:

- Designing new pages (Landing Page, Dashboard, Admin, SaaS, Mobile App)
- Creating or refactoring UI components (buttons, modals, forms, tables, charts, etc.)
- Choosing color schemes, typography systems, spacing standards, or layout systems
- Reviewing UI code for user experience, accessibility, or visual consistency
- Implementing navigation structures, animations, or responsive behavior
- Making product-level design decisions (style, information hierarchy, brand expression)
- Improving perceived quality, clarity, or usability of interfaces

### Recommended

This Skill is recommended in the following situations:

- UI looks "not professional enough" but the reason is unclear
- Receiving feedback on usability or experience
- Pre-launch UI quality optimization
- Aligning cross-platform design (Web / iOS / Android)
- Building design systems or reusable component libraries

### Skip

This Skill is not needed in the following situations:

- Pure backend logic development
- Only involving API or database design
- Performance optimization unrelated to the interface
- Infrastructure or DevOps work
- Non-visual scripts or automation tasks

**Decision criteria**: If the task will change how a feature **looks, feels, moves, or is interacted with**, this Skill should be used.

## Rule Categories by Priority

*For human/AI reference: follow priority 1→10 to decide which rule category to focus on first; use `--domain <Domain>` to query details when needed. Scripts do not read this table.*

| Priority | Category | Impact | Domain | Key Checks (Must Have) | Anti-Patterns (Avoid) |
|----------|----------|--------|--------|------------------------|----------------------|
| 1 | Accessibility | CRITICAL | `ux` | Contrast 4.5:1, Alt text, Keyboard nav, Aria-labels | Removing focus rings, Icon-only buttons without labels |
| 2 | Touch & Interaction | CRITICAL | `ux` | Min size 44×44px, 8px+ spacing, Loading feedback | Reliance on hover only, Instant state changes (0ms) |
| 3 | Performance | HIGH | `ux` | WebP/AVIF, Lazy loading, Reserve space (CLS < 0.1) | Layout thrashing, Cumulative Layout Shift |
| 4 | Style Selection | HIGH | `style`, `product` | Match product type, Consistency, SVG icons (no emoji) | Mixing flat & skeuomorphic randomly, Emoji as icons |
| 5 | Layout & Responsive | HIGH | `ux` | Mobile-first breakpoints, Viewport meta, No horizontal scroll | Horizontal scroll, Fixed px container widths, Disable zoom |
| 6 | Typography & Color | MEDIUM | `typography`, `color` | Base 16px, Line-height 1.5, Semantic color tokens | Text < 12px body, Gray-on-gray, Raw hex in components |
| 7 | Animation | MEDIUM | `ux` | Duration 150–300ms, Motion conveys meaning, Spatial continuity | Decorative-only animation, Animating width/height, No reduced-motion |
| 8 | Forms & Feedback | MEDIUM | `ux` | Visible labels, Error near field, Helper text, Progressive disclosure | Placeholder-only label, Errors only at top, Overwhelm upfront |
| 9 | Navigation Patterns | HIGH | `ux` | Predictable back, Bottom nav ≤5, Deep linking | Overloaded nav, Broken back behavior, No deep links |
| 10 | Charts & Data | LOW | `chart` | Legends, Tooltips, Accessible colors | Relying on color alone to convey meaning |

## Quick Reference

### 1. Accessibility (CRITICAL)
- `color-contrast` - Minimum 4.5:1 ratio for normal text (large text 3:1); Material Design
- `focus-states` - Visible focus rings on interactive elements (2–4px; Apple HIG, MD)
- `alt-text` - Descriptive alt text for meaningful images
- `aria-labels` - aria-label for icon-only buttons; accessibilityLabel in native (Apple HIG)
- `keyboard-nav` - Tab order matches visual order; full keyboard support (Apple HIG)
- `form-labels` - Use label with for attribute
- `skip-links` - Skip to main content for keyboard users
- `heading-hierarchy` - Sequential h1→h6, no level skip
- `color-not-only` - Don't convey info by color alone (add icon/text)
- `dynamic-type` - Support system text scaling; avoid truncation as text grows (Apple Dynamic Type, MD)
- `reduced-motion` - Respect prefers-reduced-motion; reduce/disable animations when requested (Apple Reduced Motion API, MD)
- `voiceover-sr` - Meaningful accessibilityLabel/accessibilityHint; logical reading order for VoiceOver/screen readers (Apple HIG, MD)
- `escape-routes` - Provide cancel/back in modals and multi-step flows (Apple HIG)
- `keyboard-shortcuts` - Preserve system and a11y shortcuts; offer keyboard alternatives for drag-and-drop (Apple HIG)

### 2. Touch & Interaction (CRITICAL)
- `touch-target-size` - Min 44×44pt (Apple) / 48×48dp (Material); extend hit area beyond visual bounds if needed
- `touch-spacing` - Minimum 8px/8dp gap between touch targets (Apple HIG, MD)
- `hover-vs-tap` - Use click/tap for primary interactions; don't rely on hover alone
- `loading-buttons` - Disable button during async operations; show spinner or progress
- `error-feedback` - Clear error messages near problem
- `cursor_pointer` - Add cursor-pointer to clickable elements (Web)
- `gesture-conflicts` - Avoid horizontal swipe on main content; prefer vertical scroll
- `tap-delay` - Use touch-action: manipulation to reduce 300ms delay (Web)
- `standard-gestures` - Use platform standard gestures consistently; don't redefine (e.g. swipe-back, pinch-zoom) (Apple HIG)
- `system-gestures` - Don't block system gestures (Control Center, back swipe, etc.) (Apple HIG)
- `press-feedback` - Visual feedback on press (ripple/highlight; MD state layers)
- `haptic-feedback` - Use haptic for confirmations and important actions; avoid overuse (Apple HIG)
- `gesture-alternative` - Don't rely on gesture-only interactions; always provide visible controls for critical actions
- `safe-area-awareness` - Keep primary touch targets away from notch, Dynamic Island, gesture bar and screen edges
- `no-precision-required` - Avoid requiring pixel-perfect taps on small icons or thin edges
- `swipe-clarity` - Swipe actions must show clear affordance or hint (chevron, label, tutorial)
- `drag-threshold` - Use a movement threshold before starting drag to avoid accidental drags

### 3. Performance (HIGH)
- `image-optimization` - Use WebP/AVIF, responsive images (srcset/sizes), lazy load non-critical assets
- `image-dimension` - Declare width/height or use aspect-ratio to prevent layout shift (Core Web Vitals: CLS)
- `font-loading` - Use font_display: swap/optional to avoid invisible text (FOIT); reserve space to reduce layout shift (MD)
- `font-preload` - Preload only critical fonts; avoid overusing preload on every variant
- `critical-css` - Prioritize above-the-fold CSS (inline critical CSS or early-loaded stylesheet)
- `lazy-loading` - Lazy load non-hero components via dynamic import / route-level splitting
- `bundle-splitting` - Split code by route/feature (React Suspense / Next.js dynamic) to reduce initial load and TTI
- `third-party-scripts` - Load third-party scripts async/defer; audit and remove unnecessary ones (MD)
- `reduce-reflows` - Avoid frequent layout reads/writes; batch DOM reads then writes
- `content-jumping` - Reserve space for async content to avoid layout jumps (Core Web Vitals: CLS)
- `lazy-load-below-fold` - Use loading="lazy" for below-the-fold images and heavy media
- `virtualize-lists` - Virtualize lists with 50+ items to improve memory efficiency and scroll performance
- `main-thread_budget` - Keep per-frame work under ~16ms for 60fps; move heavy tasks off main thread (HIG, MD)
- `progressive_loading` - Use skeleton screens / shimmer instead of long blocking spinners for >1s operations (Apple HIG)
- `input_latency` - Keep input latency under ~100ms for taps/scrolls (Material responsiveness standard)
- `tap_feedback_speed` - Provide visual feedback within 100ms of tap (Apple HIG)
- `debounce-throttle` - Use debounce/throttle for high-frequency events (scroll, resize, input)
- `offline_support` - Provide offline state messaging and basic fallback (PWA / mobile)
- `network_fallback` - Offer degraded modes for slow networks (lower-res images, fewer animations)

### 4. Style Selection (HIGH)
- `style_match` - Match style to product type (use `--design-system` for recommendations)
- `consistency` - Use same style across all pages
- `no-emoji-icons` - Use SVG icons (Heroicons, Lucide), not emojis
- `color-palette_from_product` - Choose palette from product/industry (search `--domain color`)
- `effects_match_style` - Shadows, blur, radius aligned with chosen style (glass / flat / clay etc.)
- `platform_adaptive` - Respect platform idioms (iOS HIG vs Material): navigation, controls, typography, motion
- `state_clarity` - Make hover/pressed/disabled states visually distinct while staying on-style (Material state layers)
- `elevation_consistent` - Use a consistent elevation/shadow scale for cards, sheets, modals; avoid random shadow values
- `dark_mode_pairing` - Design light/dark variants together to keep brand, contrast, and style consistent
- `icon_style_consistent` - Use one icon set/visual language (stroke width, corner radius) across the product
- `system_controls` - Prefer native/system controls over fully custom ones; only customize when branding requires it (Apple HIG)
- `blur_purpose` - Use blur to indicate background dismissal (modals, sheets), not as decoration (Apple HIG)
- `primary_action` - Each screen should have only one primary CTA; secondary actions visually subordinate (Apple HIG)

### 5. Layout & Responsive (HIGH)
- `viewport_meta` - width=device-width initial_scale=1 (never disable zoom)
- `mobile-first` - Design mobile-first, then scale up to tablet and desktop
- `breakpoint_consistency` - Use systematic breakpoints (e.g. 375 / 768 / 1024 / 1440)
- `readable_font_size` - Minimum 16px body text on mobile (avoids iOS auto-zoom)
- `line_length_control` - Mobile 35–60 chars per line; desktop 60–75 chars
- `horizontal_scroll` - No horizontal scroll on mobile; ensure content fits viewport width
- `spacing_scale` - Use 4pt/8dp incremental spacing system (Material Design)
- `touch-density` - Keep component spacing comfortable for touch: not cramped, not causing mis-taps
- `container_width` - Consistent max-width on desktop (max-w-6xl / 7xl)
- `z-index_management` - Define layered z-index scale (e.g. 0 / 10 / 20 / 40 / 100 / 1000)
- `fixed_element_offset` - Fixed navbar/bottom bar must reserve safe padding for underlying content
- `scroll_behavior` - Avoid nested scroll regions that interfere with the main scroll experience
- `viewport_units` - Prefer min-h-dvh over 100vh on mobile
- `orientation_support` - Keep layout readable and operable in landscape mode
- `content_priority` - Show core content first on mobile; fold or hide secondary content
- `visual_hierarchy` - Establish hierarchy via size, spacing, contrast — not color alone

### 6. Typography & Color (MEDIUM)
- `line_height` - Use 1.5-1.75 for body text
- `line_length` - Limit to 65-75 characters per line
- `font_pairing` - Match heading/body font personalities
- `font_scale` - Consistent type scale (e.g. 12 14 16 18 24 32)
- `contrast_readability` - Darker text on light backgrounds (e.g. slate-900 on white)
- `text_styles_system` - Use platform type system: iOS 11 Dynamic Type styles / Material 5 type roles (display, headline, title, body, label) (HIG, MD)
- `weight_hierarchy` - Use font_weight to reinforce hierarchy: Bold headings (600–700), Regular body (400), Medium labels (500) (MD)
- `color_semantic` - Define semantic color tokens (primary, secondary, error, surface, on-surface) not raw hex in components (Material color system)
- `color_dark_mode` - Dark mode uses desaturated / lighter tonal variants, not inverted colors; test contrast separately (HIG, MD)
- `color_accessible_pairs` - Foreground/background pairs must meet 4.5:1 (AA) or 7:1 (AAA); use tools to verify (WCAG, MD)
- `color_not_decorative_only` - Functional color (error red, success green) must include icon/text; avoid color-only meaning (HIG, MD)
- `truncation_strategy` - Prefer wrapping over truncation; when truncating use ellipsis and provide full text via tooltip/expand (Apple HIG)
- `letter_spacing` - Respect default letter-spacing per platform; avoid tight tracking on body text (HIG, MD)
- `number_tabular` - Use tabular/monospaced figures for data columns, prices, and timers to prevent layout shift
- `whitespace_balance` - Use whitespace intentionally to group related items and separate sections; avoid visual clutter (Apple HIG)

### 7. Animation (MEDIUM)
- `duration_timing` - Use 150–300ms for micro-interactions; complex transitions ≤400ms; avoid >500ms (MD)
- `transform_performance` - Use transform/opacity only; avoid animating width/height/top/left
- `loading_states` - Show skeleton or progress indicator when loading exceeds 300ms
- `excessive_motion` - Animate 1-2 key elements per view max
- `easing` - Use ease-out for entering, ease-in for exiting; avoid linear for UI transitions
- `motion_meaning` - Every animation must express a cause-effect relationship, not just be decorative (Apple HIG)
- `state_transition` - State changes (hover / active / expanded / collapsed / modal) should animate smoothly, not snap
- `continuity` - Page/screen transitions should maintain spatial continuity (shared element, directional slide) (Apple HIG)
- `parallax_subtle` - Use parallax sparingly; must respect reduced-motion and not cause disorientation (Apple HIG)
- `spring_physics` - Prefer spring/physics-based curves over linear or cubic_bezier for natural feel (Apple fluid animations)
- `exit_faster_than_enter` - Exit animations shorter than enter (~60–70% of enter duration) to feel responsive (MD motion)
- `stagger_sequence` - Stagger list/grid item entrance by 30–50ms per item; avoid all-at-once or too_slow reveals (MD)
- `shared_element_transition` - Use shared element / hero transitions for visual continuity between screens (MD, HIG)
- `interruptible` - Animations must be interruptible; user tap/gesture cancels in-progress animation immediately (Apple HIG)
- `no_blocking_animation` - Never block user input during an animation; UI must stay interactive (Apple HIG)
- `fade_crossfade` - Use crossfade for content replacement within the same container (MD)
- `scale_feedback` - Subtle scale (0.95–1.05) on press for tappable cards/buttons; restore on release (HIG, MD)
- `gesture_feedback` - Drag, swipe, and pinch must provide real-time visual response tracking the finger (MD Motion)
- `hierarchy_motion` - Use translate/scale direction to express hierarchy: enter from below = deeper, exit upward = back (MD)
- `motion_consistency` - Unify duration/easing tokens globally; all animations share the same rhythm and feel
- `opacity_threshold` - Fading elements should not linger below opacity 0.2; either fade fully or remain visible
- `modal_motion` - Modals/sheets should animate from their trigger source (scale+fade or slide-in) for spatial context (HIG, MD)
- `navigation_direction` - Forward navigation animates left/up; backward animates right/down — keep direction logically consistent (HIG)
- `layout_shift_avoid` - Animations must not cause layout reflow or CLS; use transform for position changes

### 8. Forms & Feedback (MEDIUM)
- `input_labels` - Visible label per input (not placeholder-only)
- `error_placement` - Show error below the related field
- `submit_feedback` - Loading then success/error state on submit
- `required_indicators` - Mark required fields (e.g. asterisk)
- `empty_states` - Helpful message and action when no content
- `toast_dismiss` - Auto-dismiss toasts in 3-5s
- `confirmation_dialogs` - Confirm before destructive actions
- `input_helper_text` - Provide persistent helper text below complex inputs, not just placeholder (Material Design)
- `disabled_states` - Disabled elements use reduced opacity (0.38–0.5) + cursor change + semantic attribute (MD)
- `progressive_disclosure` - Reveal complex options progressively; don't overwhelm users upfront (Apple HIG)
- `inline_validation` - Validate on blur (not keystroke); show error only after user finishes input (MD)
- `input_type_keyboard` - Use semantic input types (email, tel, number) to trigger the correct mobile keyboard (HIG, MD)
- `password_toggle` - Provide show/hide toggle for password fields (MD)
- `autofill_support` - Use autocomplete / textContentType attributes so the system can autofill (HIG, MD)
- `undo_support` - Allow undo for destructive or bulk actions (e.g. "Undo delete" toast) (Apple HIG)
- `success_feedback` - Confirm completed actions with brief visual feedback (checkmark, toast, color flash) (MD)
- `error_recovery` - Error messages must include a clear recovery path (retry, edit, help link) (HIG, MD)
- `multi_step_progress` - Multi-step flows show step indicator or progress bar; allow back navigation (MD)
- `form_autosave` - Long forms should auto-save drafts to prevent data loss on accidental dismissal (Apple HIG)
- `sheet_dismiss_confirm` - Confirm before dismissing a sheet/modal with unsaved changes (Apple HIG)
- `error_clarity` - Error messages must state cause + how to fix (not just "Invalid input") (HIG, MD)
- `field_grouping` - Group related fields logically (fieldset/legend or visual grouping) (MD)
- `read_only_distinction` - Read-only state should be visually and semantically different from disabled (MD)
- `focus_management` - After submit error, auto-focus the first invalid field (WCAG, MD)
- `error_summary` - For multiple errors, show summary at top with anchor links to each field (WCAG)
- `touch_friendly_input` - Mobile input height ≥44px to meet touch target requirements (Apple HIG)
- `destructive_emphasis` - Destructive actions use semantic danger color (red) and are visually separated from primary actions (HIG, MD)
- `toast_accessibility` - Toasts must not steal focus; use aria-live="polite" for screen reader announcement (WCAG)
- `aria_live_errors` - Form errors use aria-live region or role="alert" to notify screen readers (WCAG)
- `contrast_feedback` - Error and success state colors must meet 4.5:1 contrast ratio (WCAG, MD)
- `timeout_feedback` - Request timeout must show clear feedback with retry option (MD)

### 9. Navigation Patterns (HIGH)
- `bottom_nav_limit` - Bottom navigation max 5 items; use labels with icons (Material Design)
- `drawer_usage` - Use drawer/sidebar for secondary navigation, not primary actions (Material Design)
- `back_behavior` - Back navigation must be predictable and consistent; preserve scroll/state (Apple HIG, MD)
- `deep_linking` - All key screens must be reachable via deep link / URL for sharing and notifications (Apple HIG, MD)
- `tab_bar_ios` - iOS: use bottom Tab Bar for top-level navigation (Apple HIG)
- `top_app_bar_android` - Android: use Top App Bar with navigation icon for primary structure (Material Design)
- `nav_label_icon` - Navigation items must have both icon and text label; icon-only nav harms discoverability (MD)
- `nav_state_active` - Current location must be visually highlighted (color, weight, indicator) in navigation (HIG, MD)
- `nav_hierarchy` - Primary nav (tabs/bottom bar) vs secondary nav (drawer/settings) must be clearly separated (MD)
- `modal_escape` - Modals and sheets must offer a clear close/dismiss affordance; swipe-down to dismiss on mobile (Apple HIG)
- `search_accessible` - Search must be easily reachable (top bar or tab); provide recent/suggested queries (MD)
- `breadcrumb_web` - Web: use breadcrumbs for 3+ level deep hierarchies to aid orientation (MD)
- `state_preservation` - Navigating back must restore previous scroll position, filter state, and input (HIG, MD)
- `gesture_nav_support` - Support system gesture navigation (iOS swipe-back, Android predictive back) without conflict (HIG, MD)
- `tab_badge` - Use badges on nav items sparingly to indicate unread/pending; clear after user visits (HIG, MD)
- `overflow_menu` - When actions exceed available space, use overflow/more menu instead of cramming (MD)
- `bottom_nav_top_level` - Bottom nav is for top-level screens only; never nest sub-navigation inside it (MD)
- `adaptive_navigation` - Large screens (≥1024px) prefer sidebar; small screens use bottom/top nav (Material Adaptive)
- `back_stack_integrity` - Never silently reset the navigation stack or unexpectedly jump to home (HIG, MD)
- `navigation_consistency` - Navigation placement must stay the same across all pages; don't change by page type
- `avoid_mixed_patterns` - Don't mix Tab + Sidebar + Bottom Nav at the same hierarchy level
- `modal_vs_navigation` - Modals must not be used for primary navigation flows; they break the user's path (HIG)
- `focus_on_route_change` - After page transition, move focus to main content region for screen reader users (WCAG)
- `persistent_nav` - Core navigation must remain reachable from deep pages; don't hide it entirely in sub-flows (HIG, MD)
- `destructive_nav_separation` - Dangerous actions (delete account, logout) must be visually and spatially separated from normal nav items (HIG, MD)
- `empty_nav_state` - When a nav destination is unavailable, explain why instead of silently hiding it (MD)

### 10. Charts & Data (LOW)
- `chart_type` - Match chart type to data type (trend → line, comparison → bar, proportion → pie/donut)
- `color_guidance` - Use accessible color palettes; avoid red/green only pairs for colorblind users (WCAG, MD)
- `data_table` - Provide table alternative for accessibility; charts alone are not screen-reader friendly (WCAG)
- `pattern_texture` - Supplement color with patterns, textures, or shapes so data is distinguishable without color (WCAG, MD)
- `legend_visible` - Always show legend; position near the chart, not detached below a scroll fold (MD)
- `tooltip_on_interact` - Provide tooltips/data labels on hover (Web) or tap (mobile) showing exact values (HIG, MD)
- `axis_labels` - Label axes with units and readable scale; avoid truncated or rotated labels on mobile
- `responsive_chart` - Charts must reflow or simplify on small screens (e.g. horizontal bar instead of vertical, fewer ticks)
- `empty_data_state` - Show meaningful empty state when no data exists ("No data yet" + guidance), not a blank chart (MD)
- `loading_chart` - Use skeleton or shimmer placeholder while chart data loads; don't show an empty axis frame
- `animation_optional` - Chart entrance animations must respect prefers-reduced-motion; data should be readable immediately (HIG)
- `large_dataset` - For 1000+ data points, aggregate or sample; provide drill-down for detail instead of rendering all (MD)
- `number_formatting` - Use locale-aware formatting for numbers, dates, currencies on axes and labels (HIG, MD)
- `touch_target_chart` - Interactive chart elements (points, segments) must have ≥44pt tap area or expand on touch (Apple HIG)
- `no_pie_overuse` - Avoid pie/donut for >5 categories; switch to bar chart for clarity
- `contrast_data` - Data lines/bars vs background ≥3:1; data text labels ≥4.5:1 (WCAG)
- `legend_interactive` - Legends should be clickable to toggle series visibility (MD)
- `direct_labeling` - For small datasets, label values directly on the chart to reduce eye travel
- `tooltip_keyboard` - Tooltip content must be keyboard-reachable and not rely on hover alone (WCAG)
- `sortable_table` - Data tables must support sorting with aria_sort indicating current sort state (WCAG)
- `axis_readability` - Axis ticks must not be cramped; maintain readable spacing, auto-skip on small screens
- `data_density` - Limit information density per chart to avoid cognitive overload; split into multiple charts if needed
- `trend_emphasis` - Emphasize data trends over decoration; avoid heavy gradients/shadows that obscure the data
- `gridline_subtle` - Grid lines should be low-contrast (e.g. gray-200) so they don't compete with data
- `focusable_elements` - Interactive chart elements (points, bars, slices) must be keyboard_navigable (WCAG)
- `screen_reader_summary` - Provide a text summary or aria_label describing the chart's key insight for screen readers (WCAG)
- `error_state_chart` - Data load failure must show error message with retry action, not a broken/empty chart
- `export_option` - For data-heavy products, offer CSV/image export of chart data
- `drill_down_consistency` - Drill-down interactions must maintain a clear back-path and hierarchy breadcrumb
- `time_scale_clarity` - Time series charts must clearly label time granularity (day/week/month) and allow switching
