# GKK Web -> Flutter Migration Master Plan

This document is the single source of truth for a file-by-file, line-by-line migration from Next.js + React + TypeScript to Flutter (iOS and Android only).

## 1) Scope and goals

- Platform target: iOS + Android only
- Migration style: strict, sequential, file-by-file
- Quality rule: no behavior loss
- Architecture target: Riverpod + Repository + Dio + Supabase
- Locale baseline: tr_TR

Out of scope:
- New gameplay feature design
- Backend schema redesign
- Web target in Flutter

## 2) Mandatory working protocol

For every source file conversion, apply this exact protocol:

1. Analyze source file behavior blocks
- state
- side effects
- API calls
- UI conditions
- event handlers

2. Build a line-by-line mapping table
- source behavior
- Flutter equivalent
- migration notes

3. Implement only one target file per cycle
- do not batch unrelated files

4. Validate before moving forward
- flutter analyze
- targeted tests (unit/widget/smoke)

5. Close file only if all checks pass

## 3) Migration phases

## Phase 0 - Discovery and mapping

Deliverables:
- Full source->target file map
- Dependency chain per module
- Risk ranking per file

Exit criteria:
- Every source file has a destination file
- Conversion order is frozen

## Phase 1 - Flutter foundation

Deliverables:
- Flutter project scaffold under gkk_flutter
- Core folders and architecture shell
- Base routing, theme, locale, error model

Exit criteria:
- Project runs on emulator/device
- Analyze passes on baseline

## Phase 2 - Type model migration

Order:
1. enums
2. primitive DTO models
3. composite models

Files (source groups):
- auth
- item
- player
- inventory
- crafting
- facility
- market
- dungeon
- guild
- pvp

Exit criteria:
- No missing field
- fromJson/toJson symmetry
- copyWith and equality available

## Phase 3 - API and Supabase layer

Deliverables:
- Dio-based API client
- Token bucket rate limiter
- Retry + timeout behavior
- Supabase auth/session wrapper
- Repository base abstraction

Exit criteria:
- Authenticated requests work
- Error mapping consistent
- Retries and timeout verified

## Phase 4 - State migration (Zustand -> Riverpod)

Order:
1. auth
2. player
3. inventory
4. crafting
5. facility
6. market

Exit criteria:
- Side effects preserved
- Debounce and polling preserved
- Derived state parity preserved

## Phase 5 - Screen migration (low risk -> high risk)

Order:
1. splash
2. login
3. register
4. home
5. profile
6. inventory (without drag-drop)
7. shop
8. crafting
9. facility
10. market
11. dungeon
12. guild
13. pvp

Exit criteria:
- Loading/error/empty states preserved
- Navigation parity preserved

## Phase 6 - High-risk modules

Modules:
- Inventory drag-drop
- Realtime market/chat
- Timers with app background/resume behavior

Exit criteria:
- Optimistic updates + rollback tested
- Reconnect/backoff behavior tested
- Timer correctness tested on physical devices

## Phase 7 - Stabilization and QA

Deliverables:
- Cross-module regression run
- Widget + integration smoke suites
- iOS + Android physical device check

Exit criteria:
- No critical regression
- Release build candidate ready

## 4) Definition of done per converted file

A file is complete only if:

1. Behavior parity is verified
2. No missing state path or error path
3. tr_TR formatting parity is preserved
4. analyze passes
5. at least one test path is executed
6. reviewer checklist is signed

## 5) Risk policy

Highest risk:
- inventory drag-drop
- realtime subscriptions
- timers and lifecycle background transitions

Policy:
- implement baseline behavior first
- then add advanced behavior
- never enable optimistic updates without rollback

## 6) Suggested folder structure in Flutter

Target root: gkk_flutter/lib

- core/
  - constants/
  - errors/
  - networking/
  - services/
  - utils/
- models/
- repositories/
- providers/
- screens/
- widgets/
- routing/
- theme/
- l10n/

## 7) Conversion command prompt template

Use this template for each file conversion task:

You are a Flutter migration specialist. Convert exactly one source file from Next.js/React/TypeScript to Flutter with strict behavior parity.

Input:
- Source file: <path>
- Target file: <path>
- Related provider/repository: <path>

Output format:
1. Source analysis
- File purpose
- Dependencies
- Risk points

2. Line-by-line behavior mapping table
- Source behavior
- Flutter equivalent
- Note

3. Flutter code
- Full target file content
- Imports
- State bindings
- Error/loading handling

4. Verification
- Build/analyze checklist
- Test suggestion
- Manual smoke scenario

Rules:
- Null-safe Dart only
- No behavior loss
- No missing field
- Keep tr_TR date/number formatting parity
- Keep async flow parity (loading/error/success)
- If optimistic updates are used, rollback must be implemented

## 8) First implementation wave

Wave 1 (foundation):
1. core/constants
2. core/errors
3. core/networking (api client shell)
4. core/services (supabase service shell)
5. routing + theme + locale shell

Wave 2 (models):
1. item model set
2. player model set
3. inventory model set

Wave 3 (state):
1. auth provider
2. player provider

## 9) Operational cadence

Per work cycle:
1. one source file
2. one target file
3. one verification pass
4. commit

Do not merge multiple high-risk files in a single cycle.

---

Owner note:
If this plan and the implementation differ, this plan wins.
