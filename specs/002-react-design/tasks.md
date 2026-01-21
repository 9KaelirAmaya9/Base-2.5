---
description: 'Tasks for React Glass UI System + App Shell'
---

# Tasks: React Glass UI System + App Shell

Input: Design documents from specs/002-react-design/
Prerequisites: specs/002-react-design/plan.md (required), specs/002-react-design/spec.md (required for user stories), specs/002-react-design/research.md, specs/002-react-design/data-model.md, specs/002-react-design/contracts/

Tests: Tests are REQUIRED for this feature (RTL, jest-axe, Storybook interactions, Playwright) per specs/002-react-design/plan.md and specs/002-react-design/spec.md.
Organization: Tasks are grouped by user story to enable independent implementation and testing.

Checklist format (REQUIRED):

```text
 - [ ] T001 [P] [US1] Description with file path
```

Notes:

- [P] tasks can be done in parallel (different files, no dependency)
- [US1]/[US2]/[US3] labels appear only inside user story phases
- All task descriptions include repo-relative file paths

## Phase 1: Setup (Shared Infrastructure)

Purpose: Project initialization and baseline wiring for the React frontend.

- [x] T001 [P] Ensure frontend dependencies install cleanly in react-app/package.json
- [x] T002 [P] Ensure Storybook is runnable and configured in react-app/.storybook/preview.js
- [x] T003 [P] Ensure Playwright runner is configured in react-app/playwright.config.js
- [x] T004 [P] Confirm baseline test setup is present (RTL + jest-axe helpers) in react-app/src/setupTests.js
- [x] T005 Add feature pointers to quickstart in specs/002-react-design/quickstart.md

---

## Phase 2: Foundational (Blocking Prerequisites)

Purpose: Core styling and layout primitives that block all user stories.

CRITICAL: No user story work starts until this phase completes.

- [x] T006 Define/verify design tokens (glass + layout + motion + focus) in react-app/src/styles/tokens.css
- [x] T007 [P] Define global glass base styles and dark-mode variants in react-app/src/styles/glass.css
- [x] T008 [P] Define mesh/gradient background primitives for light/dark in react-app/src/styles/background.css
- [x] T009 [P] Ensure global style import order (tokens → background → glass → app) in react-app/src/App.css
- [x] T010 [P] Add early theme hydration script to set theme class before React mounts in react-app/public/index.html
- [x] T011 Wire style entrypoints (tokens/glass/background) in react-app/src/index.js
- [x] T012 [P] Add/verify Storybook global style loading matches app order in react-app/.storybook/preview.js
- [x] T013 Confirm API contracts unchanged for this feature (no new endpoints) by reviewing specs/002-react-design/contracts/openapi.yaml

Checkpoint: Foundation ready; user stories can proceed.

---

## Phase 3: User Story 1 - Toggle Theme + Glass Fidelity (Priority: P1) MVP

Goal: Users can toggle light/dark and see consistent glass fidelity across the shell.
Independent Test: Toggle theme; reload; theme persists via cookie; no flicker; focus-visible glow present; contrast meets 4.5:1 for key text.

### Tests for User Story 1 (write first)

- [x] T014 [P] [US1] Add RTL tests for theme toggle behavior in react-app/src/**tests**/glass-header.test.tsx
- [x] T015 [P] [US1] Add RTL tests for cookie persistence + prefers-color-scheme fallback in react-app/src/**tests**/app-shell.test.tsx
- [x] T016 [P] [US1] Add accessibility tests for focus-visible + basic landmarks (jest-axe) in react-app/src/**tests**/\_\_home/home-a11y.test.jsx
- [x] T017 [P] [US1] Add Storybook interaction coverage for theme toggle in react-app/src/stories/glass/GlassHeader.stories.tsx

### Implementation for User Story 1

- [x] T018 [US1] Implement deterministic theme resolution (cookie → system) in react-app/src/contexts/ThemeContext.js
- [x] T019 [US1] Wire ThemeProvider at app root in react-app/src/App.js
- [x] T020 [P] [US1] Implement/verify ThemeToggle control UI in react-app/src/components/glass/ThemeToggle.tsx
- [x] T021 [US1] Ensure focus-visible 3px glow tokens and styles apply across components in react-app/src/styles/glass.css
- [x] T022 [US1] Document theme persistence rules (cookie attributes, precedence) in specs/002-react-design/quickstart.md

Checkpoint: US1 is independently testable (toggle + persistence + a11y).

---

## Phase 4: User Story 2 - Compose Screens with Glass Components (Priority: P2)

Goal: A reusable glass component library plus a composed public Home page.
Independent Test: Render each component in Storybook with states; Home page renders with no API calls and passes basic a11y.

### Tests for User Story 2 (write first)

- [x] T023 [P] [US2] Add RTL tests for GlassButton variants and disabled state in react-app/src/**tests**/glass-button.test.tsx
- [x] T024 [P] [US2] Add RTL tests for GlassCard variants and interactive states in react-app/src/**tests**/glass-card.test.tsx
- [x] T025 [P] [US2] Add RTL tests for GlassModal open/close and focus return in react-app/src/**tests**/glass-modal.test.tsx
- [x] T026 [P] [US2] Add RTL tests for GlassSidebar drawer behavior in react-app/src/**tests**/glass-sidebar.test.tsx
- [x] T027 [P] [US2] Add Storybook stories for component library states in react-app/src/stories/glass/GlassButton.stories.tsx (and siblings: GlassCard/GlassInput/GlassModal/GlassSidebar/GlassHeader)
- [x] T028 [P] [US2] Add Home page render + keyboard nav tests in react-app/src/**tests**/home/home-page.test.jsx

### Implementation for User Story 2

- [x] T029 [P] [US2] Implement GlassCard component in react-app/src/components/glass/GlassCard.tsx
- [x] T030 [P] [US2] Implement GlassButton component in react-app/src/components/glass/GlassButton.tsx
- [x] T031 [P] [US2] Implement GlassInput component in react-app/src/components/glass/GlassInput.tsx
- [x] T032 [P] [US2] Implement GlassModal component in react-app/src/components/glass/GlassModal.tsx
- [x] T033 [P] [US2] Implement GlassHeader component (public/app variants) in react-app/src/components/glass/GlassHeader.tsx
- [x] T034 [P] [US2] Implement GlassSidebar component (drawer + desktop) in react-app/src/components/glass/GlassSidebar.tsx
- [x] T035 [US2] Compose public Home sections using glass components in react-app/src/pages/Home.js
- [x] T036 [P] [US2] Implement HomeHero section in react-app/src/components/home/HomeHero.jsx
- [x] T037 [P] [US2] Implement HomeFeatures/HomeVisual/HomeTrust/HomeFooter in react-app/src/components/home/HomeFeatures.jsx, react-app/src/components/home/HomeVisual.jsx, react-app/src/components/home/HomeTrust.jsx, react-app/src/components/home/HomeFooter.jsx
- [x] T038 [US2] Add Home page Storybook composition in react-app/src/stories/home/HomePage.stories.jsx

Checkpoint: US2 is independently testable via Storybook + Home page tests.

---

## Phase 5: User Story 3 - Calc-Driven Responsive App Shell (Priority: P3)

Goal: App shell layout uses CSS calc discipline (no JS layout math) and is responsive.
Independent Test: Resize viewport; sidebar respects bounds; content height uses calc(100vh - header - footer); mobile drawer works.

### Tests for User Story 3 (write first)

- [x] T039 [P] [US3] Add RTL tests for AppShell structure and layout class wiring in react-app/src/**tests**/pages-glass.test.jsx
- [x] T040 [P] [US3] Add Playwright checks for responsive behavior in react-app/e2e/app-shell-layout.spec.ts
- [x] T041 [P] [US3] Add Playwright checks for sidebar drawer behavior in react-app/e2e/app-shell-sidebar.spec.ts

### Implementation for User Story 3

- [x] T042 [P] [US3] Implement AppShell layout wrapper (public/app variants) in react-app/src/components/glass/AppShell.tsx
- [x] T043 [US3] Enforce calc-based sizing tokens (header/footer/sidebar/content) in react-app/src/styles/tokens.css
- [x] T044 [US3] Ensure page routes use AppShell variants correctly in react-app/src/App.js
- [x] T045 [US3] Add AppShell Storybook composition and responsive controls in react-app/src/stories/glass/AppShell.stories.tsx

Checkpoint: US3 is independently testable via Playwright + Storybook.

---

## Phase 6: Integration (Cross-Story)

Purpose: Ensure target pages and global wiring are stable and do not change auth or backend/API behavior.

- [x] T046 Integrate AppShell + GlassHeader/GlassSidebar on authenticated pages in react-app/src/pages/Dashboard.jsx
- [x] T047 Integrate AppShell + GlassHeader/GlassSidebar on authenticated pages in react-app/src/pages/Settings.jsx
- [x] T048 Confirm auth flows are unchanged (no token/routing behavior changes) by reviewing react-app/src/contexts/AuthContext.js

---

## Final Phase: Polish & Cross-Cutting Concerns

Purpose: Cross-cutting hardening, docs, and operational safety.

- [x] T049 [P] Run and document local validation commands (lint/test/build/storybook) in docs/TESTING.md
- [x] T050 [P] Update developer notes for telling public vs protected routes in docs/DEVELOPMENT.md

### Additional tasks imported from junk/woodkilldev-speckit-tasks.md

- [x] T051 [P] Remove standalone "..." placeholders from react-app/src/contexts/ThemeContext.js
- [x] T052 [P] Remove standalone "..." placeholders from react-app/src/components/ErrorBoundary.jsx
- [x] T053 Add repo-wide guard to prevent "..." placeholder commits by documenting a grep check in docs/TESTING.md

- [x] T054 Add error + component stack logging in ErrorBoundary componentDidCatch in react-app/src/components/ErrorBoundary.jsx

- [x] T055 Update CSP to allow Google OAuth domains (script-src/connect-src/frame-src) in traefik/dynamic.yml
- [x] T056 Validate CSP changes in docs by adding a troubleshooting section in docs/CONFIG.md

- [x] T057 [P] Move inline theme init from react-app/public/index.html to external script file react-app/public/theme-init.js
- [x] T058 Update index.html to reference theme-init.js in react-app/public/index.html

- [x] T059 Ensure production builds inject REACT_APP_GOOGLE_CLIENT_ID via deploy configuration in local.docker.yml
- [x] T060 Ensure production builds inject REACT_APP_GOOGLE_CLIENT_ID via deploy configuration in digital_ocean/app_spec.yaml

- [x] T061 Add cache guidance for index.html vs hashed assets (purge strategy) in docs/DEPLOY.md
- [x] T062 Add a mobile regression checklist (iOS Safari + Android Chrome + dark mode) in docs/RELEASE.md
- [ ] T063 (Optional) Add frontend crash monitoring (Sentry) scaffolding in react-app/src/index.js

---

## Dependencies & Execution Order

Phase dependencies:

- Setup (Phase 1) → Foundational (Phase 2) → User Stories (Phase 3+) → Integration → Polish

User story dependencies:

- US1 depends on Phase 2 (tokens + early hydration)
- US2 depends on Phase 2; can proceed in parallel with US1 after Phase 2, but final UI review should include both
- US3 depends on Phase 2 and US2 components (AppShell composes header/sidebar/content)

Parallel opportunities:

- Within Phase 2, T006–T012 can be split across styling vs Storybook wiring
- Within each user story, tasks marked [P] can be assigned to different owners (tests, components, stories)

---

## Parallel Execution Examples

User Story 1 parallel bundle:

- T014, T015, T016, T017 (tests/stories)
- T020 (ThemeToggle UI) can proceed while T018/T019 is in progress

User Story 2 parallel bundle:

- T029–T034 (glass components) in parallel
- T023–T028 (tests/stories) in parallel
- T036–T037 (home sections) in parallel

---

## Implementation Strategy

MVP scope: Phase 1 + Phase 2 + US1 only.

Incremental delivery:

1. Land Foundation (Phase 1–2) and validate styling + theme hydration
2. Ship US1 (toggle + persistence + a11y) and validate independently
3. Ship US2 (component library + Home composition) and validate independently
4. Ship US3 (calc-driven AppShell) and validate independently
5. Apply Polish tasks (including Speckit production hardening backlog)
