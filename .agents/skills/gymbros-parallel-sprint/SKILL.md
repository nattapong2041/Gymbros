---
name: gymbros-parallel-sprint
description: Plan and coordinate GymBros feature sprints for fast parallel AI-agent development. Use when creating or updating GymBros sprint specs/plans, splitting work across agents, defining task ownership, or preparing no-protocol Repo+ViewModel / View+Mock / Localization / Wire+Verify workflows.
---

# GymBros Parallel Sprint

Use this skill when planning or executing a complex GymBros sprint that can be split across multiple coding agents.

## Required Reading

Before planning or coding:

1. Read `CLAUDE.md`.
2. Read `.claude/GYMTRACK.md`.
3. Read the sprint's `.claude/sprints/S[N]-name/spec.md`.
4. Read the sprint's `.claude/sprints/S[N]-name/plan.md`.
5. Check `git status --short` and preserve unrelated user changes.

## Default Strategy

Use the sprint spec and plan as the coordination contract. Do not create feature ViewModel protocols by default.

Preferred split:

```text
Task 0 - Spec Lock
Task 1 - Repo + ViewModel
Task 2 - View + Mock Data
Task 3 - Localization
Task 4 - Wire + Verify
```

Create protocols only when the user explicitly requests them or when an existing repo pattern already requires them.

## Task 0 - Spec Lock

Make the spec and plan decision-complete before parallel work starts.

Define:

- user goal and acceptance tests
- screen states and empty/error/loading behavior
- expected concrete `@Observable` ViewModel state and action names
- data shape used by both ViewModel and views
- repository/service behavior
- localization key families
- task ownership and forbidden files
- manual smoke test

Keep this short and concrete. Do not implement feature code in Task 0 unless the user has asked to execute.

## Task 1 - Repo + ViewModel

Own data and state.

Typical ownership:

- `Gymbros/Data/Repository/`
- `Gymbros/Data/Services/`
- concrete `Gymbros/Presentation/<Feature>/*ViewModel.swift`
- focused tests in `GymbrosTests/`
- payloads, backup stores, validators, and pure helper types needed by the ViewModel

Rules:

- Use concrete `@Observable` ViewModels.
- Use `ViewState` and `AppError`; never expose raw SDK errors or raw strings.
- Do not edit SwiftUI view files except unavoidable compile fixes agreed in the plan.
- Do not edit `Localizable.xcstrings` except temporary keys if Task 3 is unavailable.
- End with handoff notes listing public ViewModel initializers, state, actions, and known limitations.

## Task 2 - View + Mock Data

Own UI and previews.

Typical ownership:

- SwiftUI views in `Gymbros/Presentation/<Feature>/`
- local preview/mock data
- mock-only view models or lightweight preview state
- accessibility labels
- loading, success, empty, error, restore, confirmation, and disabled states

Rules:

- Do not depend on Task 1 implementation being complete.
- Use existing app models where practical.
- Keep mock-only runtime paths isolated so the wire task can remove or bypass them cleanly.
- Use localization keys, not hardcoded user-facing copy.
- Do not edit repositories or concrete data ViewModels.
- End with handoff notes listing mock entry points and the expected real ViewModel data/action mapping.

## Task 3 - Localization

Own `Gymbros/Resources/Localizable.xcstrings`.

Rules:

- Add complete English and Thai values for every new user-facing key.
- Include buttons, alerts, empty states, error surfaces, accessibility labels, and timer/status copy.
- Coordinate key names from the spec before editing.
- Search changed feature views for hardcoded user-facing strings before handoff.

## Task 4 - Wire + Verify

Run only after Tasks 1-3 are complete or explicitly handed off.

Own integration:

- connect concrete ViewModels to SwiftUI views
- remove or isolate mock-only runtime paths
- add navigation/start entry points
- resolve compile mismatches
- run targeted tests, then full tests
- perform manual smoke test
- update `CURRENT STATUS`, task checkboxes, known deviations, and next step

Use:

```bash
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e'
```

If sandboxed `xcodebuild` cannot write Xcode/Simulator caches, rerun with the required approval.

## Plan Format

Every parallel task must include:

- owner role
- parallel-safe ownership
- files likely touched
- forbidden files
- dependencies
- checkboxes
- verification command
- handoff notes checkbox

Mark each checkbox `[x]` immediately after completing it. Do not batch plan updates.
