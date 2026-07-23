# Progressive Overload Advisor Sessions — Design

**Date:** 2026-07-23
**Status:** Approved, pending implementation plan
**Author:** Brainstormed with Claude Code

## Context

Fourth of four post-launch features (see `.claude/GYMTRACK.md` → "Post-Launch Feature
Backlog"). Depends on `docs/superpowers/specs/2026-07-23-training-phase-setting-design.md`
(3a — must ship first; this spec consumes `Profile.trainingPhase`).

## Problem

Two gaps, not one:

1. **No plateau detection exists.** The already-implemented `ProgressiveOverloadEngine`
   (`Data/Services/ProgressiveOverloadEngine.swift`) only looks at the *single most
   recent* session's RPE for an exercise — it has no concept of "you've logged the same
   weight for the last N sessions." Nothing in the codebase computes that today.
2. **Whatever suggestion does exist is easy to miss.** It's a small inline text line
   inside the exercise page (`WorkoutExercisePageView`, gated on
   `isComebackMode == false`), visible only while already mid-workout on that exact
   exercise.

## Goal

Detect real plateaus (same weight held across several sessions with room to grow) and
surface them proactively on Today — while respecting a user who's intentionally holding
steady during a cut or maintenance phase (via 3a's `trainingPhase` setting), so this
never reads as nagging.

## Non-goals

- No changes to the existing `ProgressiveOverloadEngine`, `SmartSessionAdvisor`, or
  `ComebackRampService`.
- No `DeloadAdvisor` — a plateau caused by grinding near failure every session is a
  *different* signal (the user needs to back off, not add weight) and is explicitly out
  of scope here; see the RPE gate in Design below for how the two are kept from
  overlapping.
- No actual nutrition/calorie tracking — this only reads the self-reported
  `trainingPhase` enum from 3a.
- No cross-device sync for the dismiss/snooze state (see Design — local only).

## Design

### `StallDetector` (new pure service, `Data/Services/StallDetector.swift`)

```swift
struct StallDetector {
    static let sessionThreshold = 4
    static let maxRPEForStall = 8.0

    func isStalled(
        exerciseId: UUID,
        recentSessions: [WorkoutSession],
        sets: [UUID: [WorkoutSet]]
    ) -> Bool {
        // recentSessions must already be completed-only, newest-first.
    }
}
```

A "stall" is: the same *top-set weight* logged across the last `sessionThreshold` (4)
sessions that included this exercise, **and** no session among those 4 recorded an RPE
above `maxRPEForStall` (8.0) on that top set. Missing RPE (now optional per the RPE UX
simplification spec) does **not** block detection — only a *recorded* RPE above 8.0
counts as evidence the plateau is effort-limited (which is `DeloadAdvisor` territory,
not this). If fewer than 4 qualifying sessions exist, or the top-set weight isn't
identical across all 4, it's not a stall.

`4` reuses the session-count convention already established by
`NextBestSessionEngine.boundedExitSessionCount`. `8.0` reuses
`ProgressiveOverloadEngine`'s own "hold, don't suggest" ceiling for consistency between
the two services.

### Delivery: `OverloadAdvisorCardView` on Today

New card, same family as `ComebackCardView`, shown only when **all** of:

- `TodayRecommendation.mode == .normal` (never alongside the comeback card — a user
  just back from a gap isn't in a plateau-nagging moment; the two modes are already
  mutually exclusive on `TodayRecommendation.Mode`, so this falls out for free).
- At least one exercise in **today's recommended day** (not the whole program — keeps
  it relevant to what the user's about to do) is stalled per `StallDetector`. If
  multiple qualify, show the first one in the day's exercise order.
- `profile.trainingPhase` is `nil` or `.bulk`. If `.cut` or `.maintain`, the card is
  suppressed entirely for that exercise — no softened copy, just silence, since the
  user explicitly said they don't want to be nudged to add weight right now.
- That exercise hasn't been snoozed in the last 14 days (see Snooze below).

Card copy: exercise name, current weight, and a plain-language plateau statement plus
two actions — "Try it next time" and "Not now."

**"Try it next time"** calls `ProgramRepo` to update that `ProgramExercise.targetWeight`
to `currentWeight + ProgressiveOverloadEngine.weightIncrementKg` (2.5kg) — reusing the
*existing* pre-fill mechanism (`CLAUDE.md` architecture: "Set 1 pre-fills from
`ProgramExercise.targetWeight`"). No new pre-fill plumbing needed.

**"Not now"** snoozes that specific `programExerciseId`'s stall prompt for 14 days.

### Snooze storage (new, `Data/Services/OverloadAdvisorSnoozeStore.swift`)

Local-only, `UserDefaults`-backed, mirroring `RestTimerNotificationScheduler`'s
protocol-wrapped style for testability:

```swift
protocol OverloadAdvisorSnoozing {
    func isSnoozed(programExerciseId: UUID, now: Date) -> Bool
    func snooze(programExerciseId: UUID, now: Date)
}
```

Stores `[UUID: Date]` (snoozed-until date per exercise) as JSON in `UserDefaults`.
Local-only is a deliberate choice: this is a low-stakes, per-device UI preference (losing
it on reinstall just means the prompt might reappear once — not worth a Supabase table
and migration for).

### `TodayViewModel` fetch cost (explicit tradeoff)

S06 (`D6` in `.claude/sprints/S06-next-best-session/plan.md`) deliberately fetches sets
*only* when a comeback gap candidate is detected, to keep normal days free of extra
requests. This feature reintroduces a fetch on normal days too, since `StallDetector`
needs recent sets regardless of gap status. The fetch stays bounded the same way D6
bounded its own cost: only for the exercises in **today's recommended day** (not the
whole program's history), last 4 sessions each — not an open-ended history pull.

### Localization

| Key | en | th |
|---|---|---|
| `today.overload_advisor.title` | Same weight for a while | น้ำหนักเท่าเดิมมาสักพัก |
| `today.overload_advisor.body` | You've held %@ on %@ for 4 sessions in a row. | คุณใช้น้ำหนัก %@ กับ %@ มา 4 ครั้งติดกันแล้ว |
| `today.overload_advisor.try_next_time` | Try it next time | ลองครั้งหน้า |
| `today.overload_advisor.not_now` | Not now | ยังไม่ตอนนี้ |

## Testing

- `StallDetectorTests`: same-weight-4-sessions positive case; fewer-than-4-sessions
  negative case; weight-differs-across-sessions negative case; RPE-above-8.0-blocks
  case; missing-RPE-does-not-block case.
- `OverloadAdvisorSnoozeStoreTests`: snoozed-within-14-days returns true;
  snoozed-15-days-ago returns false; never-snoozed returns false.
- `TodayViewModelTests`: new cases for card visibility gated on
  `trainingPhase` (`.bulk`/`nil` shows, `.cut`/`.maintain` suppresses) and on comeback
  mode (never shown alongside the comeback card).
- Build must succeed. Manual smoke: log the same weight for an exercise across 4
  sessions, confirm the card appears on Today; set `trainingPhase` to "Losing weight" in
  Settings, confirm it disappears for that exercise; dismiss with "Not now," confirm it
  stays hidden on next launch.

## Open follow-ups

- Positive reinforcement copy for `.cut` phase (e.g. affirming "held strength while
  losing weight" instead of just going silent) was considered and deliberately deferred
  — simplest correct behavior first, nicer copy can follow.
- `DeloadAdvisor` (Sprint 7 checklist item) is the natural next service once this ships
  — same shape, opposite trigger (near-max RPE instead of comfortable RPE).
