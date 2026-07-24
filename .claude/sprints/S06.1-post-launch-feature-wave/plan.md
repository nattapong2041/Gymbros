# Sprint 6.1 — Post-Launch Feature Wave Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship five independent, already-approved post-launch features: RPE UX
simplification, Skip a Day, Training Phase Setting, the Progressive Overload
Advisor, and Substitute (mid-workout exercise swap). Full product spec:
`.claude/sprints/S06.1-post-launch-feature-wave/spec.md`.

**Architecture:** RPE (Tasks 1-6) replaces two raw-number `Menu` controls with the
existing `HowDidThatFeel` 3-option scale and deletes a now-redundant comeback-mode
sheet — no data model changes. Skip a Day (Task 7) is a single `TodayView`-local
`@State` addition. Training Phase Setting (Tasks 8-11) adds one nullable `Profile`
column, mirrors the existing weight-unit Settings row exactly. Progressive Overload
Advisor (Tasks 12-17) adds one new pure service (`StallDetector`), one new local
UserDefaults-backed store (`OverloadAdvisorSnoozeStore`), one new Today card, and
`TodayViewModel` wiring that reintroduces a bounded sets-fetch on normal days.
Substitute (Tasks 18-24) adds one new pure service (`SubstituteRanker`), one small
model mutability change (`WorkoutSetRowState.exerciseId`), two new
`WorkoutSessionViewModel` methods, two new UI components, and a header button —
entirely within the workout logger, no `TodayView`/`Settings` changes.

**Tech Stack:** Swift, SwiftUI, Swift Testing (`import Testing`, `@Test`, `#expect`),
Xcode String Catalogs (`Localizable.xcstrings`, hand-edited JSON), Supabase Postgres
(one additive migration).

## Global Constraints

- Module name is `Gymbros` (not `GymBros`) — use `@testable import Gymbros` in all tests.
- Test framework is Swift Testing, not XCTest — `@Test func ...()`, `#expect(...)`, no `XCTestCase`.
- Build/test destination is `platform=iOS Simulator,name=iPhone 17e` per earlier tasks in
  this plan, but this machine currently has no `iPhone 17e` simulator installed (only
  `iPhone 17`/`17 Pro`/`17 Pro Max` — see STANDUP.md's 2026-07-24 environment note); use
  `iPhone 17` for all Substitute-related (Task 18+) commands.
- Every user-visible string must have both `en` and `th` entries in `Localizable.xcstrings` — no hardcoded strings in views.
- Minimum tap target is 48pt — do not shrink any existing tappable area.
- Commit messages end with `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`; never use `git commit --amend` or `--no-verify`.
- Custom brand colors (`AccentColor`, `GymPurple`) must NOT be used — semantic system colors only.
- Any operation that applies a database migration requires **explicit user confirmation at implementation time** per `CLAUDE.md` → "Data Safety and Approval" — see Task 9.
- Build order: RPE + Skip a Day first (independent), Training Phase Setting next (foundational), Progressive Overload Advisor next (depends on Training Phase Setting), Substitute last (independent of the other four, ordered last only because its approval landed a day later).
- Design docs, read first if anything below is ambiguous:
  - `docs/superpowers/specs/2026-07-22-rpe-ux-simplification-design.md`
  - `docs/superpowers/specs/2026-07-23-skip-a-day-design.md`
  - `docs/superpowers/specs/2026-07-23-training-phase-setting-design.md`
  - `docs/superpowers/specs/2026-07-23-progressive-overload-advisor-design.md`
  - `docs/superpowers/specs/2026-07-24-exercise-substitution-design.md`

---

# PART 1 — RPE UX SIMPLIFICATION

### Task 1: Localization — add `workout.set.feel*` and accessibility keys, remove old RPE keys

**Files:**
- Modify: `Gymbros/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: nothing (this is a data-only task).
- Produces: string catalog keys `workout.set.feel`, `workout.set.feel.clear`, `workout.set.feel.easy`, `workout.set.feel.hard`, `workout.set.feel.just_right`, `workout.set.header.feel`, `accessibility.workout.set.feel.prefix`, `accessibility.workout.set.feel.unset` — consumed by Tasks 2-4. Removes `workout.comeback.feel.easy`, `workout.comeback.feel.hard`, `workout.comeback.feel.just_right`, `workout.comeback.feel.skip`, `workout.comeback.feel.title`, `workout.set.header.rpe`, `workout.set.rpe`, `workout.set.rpe.clear`.

- [ ] **Step 1: Insert the new `workout.set.feel*` cluster before `workout.set.header.done`**

In `Gymbros/Resources/Localizable.xcstrings`, find:

```json
    "workout.set.header.done" : {
```

Replace with:

```json
    "workout.set.feel" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Feel"
          }
        },
        "th" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "รู้สึก"
          }
        }
      }
    },
    "workout.set.feel.clear" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Clear"
          }
        },
        "th" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "ล้าง"
          }
        }
      }
    },
    "workout.set.feel.easy" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Easy"
          }
        },
        "th" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "สบาย"
          }
        }
      }
    },
    "workout.set.feel.hard" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Hard"
          }
        },
        "th" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "หนัก"
          }
        }
      }
    },
    "workout.set.feel.just_right" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Just right"
          }
        },
        "th" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "พอดี"
          }
        }
      }
    },
    "workout.set.header.done" : {
```

- [ ] **Step 2: Add accessibility keys before `workout.set.header.done`**

Since Step 1 already moved `workout.set.header.done` down, find it again (it's now preceded by the block from Step 1) and insert two more keys directly before it:

```json
    "workout.set.header.done" : {
```

Replace with:

```json
    "accessibility.workout.set.feel.prefix" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Feel: "
          }
        },
        "th" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "ความรู้สึก: "
          }
        }
      }
    },
    "accessibility.workout.set.feel.unset" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Feel not set"
          }
        },
        "th" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "ยังไม่ระบุความรู้สึก"
          }
        }
      }
    },
    "workout.set.header.done" : {
```

- [ ] **Step 3: Insert `workout.set.header.feel` before `workout.set.header.reps`**

Find:

```json
    "workout.set.header.reps" : {
```

Replace with:

```json
    "workout.set.header.feel" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Feel"
          }
        },
        "th" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "รู้สึก"
          }
        }
      }
    },
    "workout.set.header.reps" : {
```

- [ ] **Step 4: Remove `workout.set.header.rpe`**

Find and delete this entire block (replace with nothing):

```json
    "workout.set.header.rpe" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "RPE"
          }
        },
        "th" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "RPE"
          }
        }
      }
    },
```

- [ ] **Step 5: Remove `workout.set.rpe` and `workout.set.rpe.clear`**

Find and delete this entire block (replace with nothing):

```json
    "workout.set.rpe" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "RPE"
          }
        },
        "th" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "RPE"
          }
        }
      }
    },
    "workout.set.rpe.clear" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Clear RPE"
          }
        },
        "th" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "ล้าง RPE"
          }
        }
      }
    },
```

- [ ] **Step 6: Remove the `workout.comeback.feel.*` cluster (5 keys)**

Find and delete this entire block (replace with nothing):

```json
    "workout.comeback.feel.easy" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Easy"
          }
        },
        "th" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "สบาย"
          }
        }
      }
    },
    "workout.comeback.feel.hard" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Hard"
          }
        },
        "th" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "หนัก"
          }
        }
      }
    },
    "workout.comeback.feel.just_right" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Just right"
          }
        },
        "th" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "พอดี"
          }
        }
      }
    },
    "workout.comeback.feel.skip" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Skip"
          }
        },
        "th" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "ข้าม"
          }
        }
      }
    },
    "workout.comeback.feel.title" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "How did that feel?"
          }
        },
        "th" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "รู้สึกยังไงบ้าง?"
          }
        }
      }
    },
```

- [ ] **Step 7: Validate JSON and key coverage**

Run:

```bash
jq empty Gymbros/Resources/Localizable.xcstrings && echo "valid json"
python3 -c "
import json
d = json.load(open('Gymbros/Resources/Localizable.xcstrings'))
new_keys = ['workout.set.feel', 'workout.set.feel.clear', 'workout.set.feel.easy',
            'workout.set.feel.hard', 'workout.set.feel.just_right', 'workout.set.header.feel',
            'accessibility.workout.set.feel.prefix', 'accessibility.workout.set.feel.unset']
old_keys = ['workout.comeback.feel.easy', 'workout.comeback.feel.hard', 'workout.comeback.feel.just_right',
            'workout.comeback.feel.skip', 'workout.comeback.feel.title', 'workout.set.header.rpe',
            'workout.set.rpe', 'workout.set.rpe.clear']
for k in new_keys:
    locs = d['strings'][k]['localizations']
    assert 'en' in locs and 'th' in locs, f'{k} missing a locale'
    print('OK', k)
for k in old_keys:
    assert k not in d['strings'], f'{k} should have been removed'
    print('REMOVED', k)
"
```

Expected: `valid json`, then `OK <key>` for each of the 8 new keys, then `REMOVED <key>` for each of the 8 old keys, no assertion errors.

- [ ] **Step 8: Commit**

```bash
git add Gymbros/Resources/Localizable.xcstrings
git commit -m "$(cat <<'EOF'
i18n: replace RPE localization keys with plain-language feel keys

Adds workout.set.feel* (Easy/Just right/Hard/Clear/placeholder) and
two accessibility keys; removes the RPE-labeled keys and the
comeback-only feel keys they're replacing.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: `HowDidThatFeel.nearest(to:)` bucketing helper + repoint `titleKey`

**Files:**
- Modify: `Gymbros/Data/Services/HowDidThatFeel.swift`
- Test: `GymbrosTests/HowDidThatFeelTests.swift` (create)

**Interfaces:**
- Consumes: `workout.set.feel.easy` / `workout.set.feel.just_right` / `workout.set.feel.hard` keys from Task 1.
- Produces: `HowDidThatFeel.nearest(to rpe: Double) -> HowDidThatFeel` — consumed by Tasks 3 and 4 to bucket a stored `Double` RPE value back to the nearest of the three cases for display. `HowDidThatFeel.titleKey: String` now returns `workout.set.feel.*` keys instead of `workout.comeback.feel.*`.

- [ ] **Step 1: Write the failing test**

Create `GymbrosTests/HowDidThatFeelTests.swift`:

```swift
import Testing
@testable import Gymbros

@Suite("HowDidThatFeel bucketing")
struct HowDidThatFeelTests {
    @Test func nearestBucketsCanonicalValues() {
        #expect(HowDidThatFeel.nearest(to: 6.0) == .easy)
        #expect(HowDidThatFeel.nearest(to: 7.5) == .justRight)
        #expect(HowDidThatFeel.nearest(to: 9.0) == .hard)
    }

    @Test func nearestBucketsLowerBoundaryToEasy() {
        #expect(HowDidThatFeel.nearest(to: 6.75) == .easy)
    }

    @Test func nearestBucketsJustAboveLowerBoundaryToJustRight() {
        #expect(HowDidThatFeel.nearest(to: 6.76) == .justRight)
    }

    @Test func nearestBucketsUpperBoundaryToJustRight() {
        #expect(HowDidThatFeel.nearest(to: 8.25) == .justRight)
    }

    @Test func nearestBucketsJustAboveUpperBoundaryToHard() {
        #expect(HowDidThatFeel.nearest(to: 8.26) == .hard)
    }

    @Test func nearestBucketsLegacyDecimalValues() {
        #expect(HowDidThatFeel.nearest(to: 6.5) == .easy)
        #expect(HowDidThatFeel.nearest(to: 8.0) == .justRight)
        #expect(HowDidThatFeel.nearest(to: 10.0) == .hard)
        #expect(HowDidThatFeel.nearest(to: 1.0) == .easy)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/HowDidThatFeelTests
```

Expected: **BUILD FAILURE** — `type 'HowDidThatFeel' has no member 'nearest'` (the function doesn't exist yet).

- [ ] **Step 3: Implement `nearest(to:)` and repoint `titleKey`**

Replace the full contents of `Gymbros/Data/Services/HowDidThatFeel.swift`:

```swift
import Foundation

enum HowDidThatFeel: CaseIterable {
    case easy
    case justRight
    case hard

    var rpe: Double {
        switch self {
        case .easy: 6.0
        case .justRight: 7.5
        case .hard: 9.0
        }
    }

    var symbolName: String {
        switch self {
        case .easy: "face.smiling"
        case .justRight: "checkmark.circle"
        case .hard: "flame"
        }
    }

    var titleKey: String {
        switch self {
        case .easy: "workout.set.feel.easy"
        case .justRight: "workout.set.feel.just_right"
        case .hard: "workout.set.feel.hard"
        }
    }

    static func nearest(to rpe: Double) -> HowDidThatFeel {
        if rpe <= 6.75 { return .easy }
        if rpe <= 8.25 { return .justRight }
        return .hard
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/HowDidThatFeelTests
```

Expected: `** TEST SUCCEEDED **`, all 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Gymbros/Data/Services/HowDidThatFeel.swift GymbrosTests/HowDidThatFeelTests.swift
git commit -m "$(cat <<'EOF'
feat: add HowDidThatFeel.nearest(to:) bucketing and repoint titleKey

Buckets any stored RPE double (including legacy values from the old
19-item scale) to the nearest of the three feel cases for display.
titleKey now points at the generalized workout.set.feel.* keys since
this enum is no longer comeback-only.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Simplify `SetRowView`'s per-set picker

**Files:**
- Modify: `Gymbros/Presentation/Workout/SetRowView.swift`
- Modify: `Gymbros/Presentation/Workout/WorkoutExercisePageView.swift`

**Interfaces:**
- Consumes: `HowDidThatFeel.allCases`, `.rpe`, `.symbolName`, `.titleKey`, `.nearest(to:)` from Task 2; `workout.set.feel`, `workout.set.feel.clear` keys from Task 1.
- Produces: no new symbols for other tasks — `rpe: Double?` continues to flow out through the existing `onUpdate: (String, String, Double?) -> Void` closure unchanged.

- [ ] **Step 1: Replace the RPE `Menu` with the simplified feel `Menu`**

In `Gymbros/Presentation/Workout/SetRowView.swift`, find:

```swift
            // RPE Picker (using Menu for HIG compliance and tap target)
            Menu {
                ForEach(Array(stride(from: 10.0, through: 1.0, by: -0.5)), id: \.self) { rpeValue in
                    Button {
                        rpe = rpeValue
                    } label: {
                        Text(String(format: "%.1f", rpeValue))
                    }
                }
                Button(role: .destructive) {
                    rpe = nil
                } label: {
                    Text("workout.set.rpe.clear")
                }
            } label: {
                Text(rpe.map { String(format: "%.1f", $0) } ?? String(localized: "workout.set.rpe"))
                    .font(.system(.caption, design: .rounded).bold())
                    .foregroundStyle(rpe != nil ? .primary : .secondary)
                    .frame(width: columns.rpe, height: 48) // Mandated 48pt tap target
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(isReadOnly)
            .contentShape(Rectangle()) // Ensure entire area is tappable
```

Replace with:

```swift
            // Feel Picker (using Menu for HIG compliance and tap target)
            Menu {
                ForEach(HowDidThatFeel.allCases, id: \.self) { feel in
                    Button {
                        rpe = feel.rpe
                    } label: {
                        Label(LocalizedStringKey(feel.titleKey), systemImage: feel.symbolName)
                    }
                }
                Button(role: .destructive) {
                    rpe = nil
                } label: {
                    Text("workout.set.feel.clear")
                }
            } label: {
                feelLabelContent
                    .font(.system(.caption, design: .rounded).bold())
                    .foregroundStyle(rpe != nil ? .primary : .secondary)
                    .frame(width: columns.rpe, height: 48) // Mandated 48pt tap target
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(isReadOnly)
            .contentShape(Rectangle()) // Ensure entire area is tappable
            .accessibilityLabel(feelAccessibilityLabel)
```

- [ ] **Step 2: Add the `feelLabelContent` and `feelAccessibilityLabel` helpers**

In the same file, find (in the `init`, this exact two-line span appears once, right before a blank line and `var body`):

```swift
        _rpe = State(initialValue: state.rpe)
    }
```

Replace with (this inserts the two new computed properties right after `init`; everything after — the blank line and `var body: some View {` — is untouched since it wasn't part of the matched text):

```swift
        _rpe = State(initialValue: state.rpe)
    }

    @ViewBuilder
    private var feelLabelContent: some View {
        if let rpe {
            Image(systemName: HowDidThatFeel.nearest(to: rpe).symbolName)
        } else {
            Text("workout.set.feel")
        }
    }

    private var feelAccessibilityLabel: Text {
        guard let rpe else {
            return Text("accessibility.workout.set.feel.unset")
        }
        return Text("accessibility.workout.set.feel.prefix")
            + Text(LocalizedStringKey(HowDidThatFeel.nearest(to: rpe).titleKey))
    }
```

- [ ] **Step 3: Update the header label**

In `Gymbros/Presentation/Workout/WorkoutExercisePageView.swift`, find:

```swift
            Text("workout.set.header.rpe")
                .frame(width: columns.rpe, alignment: .center)
```

Replace with:

```swift
            Text("workout.set.header.feel")
                .frame(width: columns.rpe, alignment: .center)
```

- [ ] **Step 4: Build to verify it compiles**

Run:

```bash
xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' build
```

Expected: `** BUILD SUCCEEDED **`. (There is no dedicated `SetRowView` unit test in this codebase — Views are verified by build success plus manual smoke per project convention; Services are what carry 100% unit-test coverage.)

- [ ] **Step 5: Manual smoke check**

Open `SetRowView.swift` in Xcode, view the "Active" preview. Confirm: the feel column shows a neutral "Feel" placeholder on an empty set; tapping it opens a 4-item menu (Easy/Just right/Hard with icons, then Clear); picking "Just right" shows only the checkmark-circle icon in the closed state.

- [ ] **Step 6: Commit**

```bash
git add Gymbros/Presentation/Workout/SetRowView.swift Gymbros/Presentation/Workout/WorkoutExercisePageView.swift
git commit -m "$(cat <<'EOF'
feat: simplify SetRowView's per-set RPE picker to Easy/Just right/Hard

Replaces the raw 1.0-10.0 decimal menu with the same friendly scale
already used in comeback mode, reusing HowDidThatFeel. Same Menu
component, column width, and 48pt tap target as before -- only the
menu contents and closed-state rendering change.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Simplify `SessionDetailView`'s edit-set feel picker

**Files:**
- Modify: `Gymbros/Presentation/History/SessionDetailView.swift`

**Interfaces:**
- Consumes: `HowDidThatFeel.allCases`, `.rpe`, `.titleKey`, `.nearest(to:)` from Task 2; `workout.set.feel`, `workout.set.feel.clear` keys from Task 1.
- Produces: nothing new for other tasks — `rpe: Double?` continues to flow into the existing `viewModel.updateSet(set, weight:reps:rpe:)` call unchanged.

- [ ] **Step 1: Replace the RPE `Menu` inside `EditSetSheet`**

In `Gymbros/Presentation/History/SessionDetailView.swift`, find:

```swift
                    Menu {
                        ForEach(Array(stride(from: 10.0, through: 1.0, by: -0.5)), id: \.self) { rpeValue in
                            Button { rpe = rpeValue } label: {
                                Text(String(format: "%.1f", rpeValue))
                            }
                        }
                        Button(role: .destructive) { rpe = nil } label: {
                            Text("workout.set.rpe.clear")
                        }
                    } label: {
                        HStack {
                            Text("workout.set.rpe")
                            Spacer()
                            Text(rpe.map { String(format: "%.1f", $0) } ?? "-")
                                .foregroundStyle(rpe != nil ? .primary : .secondary)
                        }
                    }
```

Replace with:

```swift
                    Menu {
                        ForEach(HowDidThatFeel.allCases, id: \.self) { feel in
                            Button { rpe = feel.rpe } label: {
                                Text(LocalizedStringKey(feel.titleKey))
                            }
                        }
                        Button(role: .destructive) { rpe = nil } label: {
                            Text("workout.set.feel.clear")
                        }
                    } label: {
                        HStack {
                            Text("workout.set.feel")
                            Spacer()
                            feelDisplayText
                                .foregroundStyle(rpe != nil ? .primary : .secondary)
                        }
                    }
```

- [ ] **Step 2: Add the `feelDisplayText` helper**

In the same file, find:

```swift
    private var parsedWeight: Double? {
        appPreferences.weightUnit.kilogramValue(fromDisplayText: weightText)
    }
```

Replace with:

```swift
    private var feelDisplayText: Text {
        guard let rpe else { return Text(verbatim: "—") }
        return Text(LocalizedStringKey(HowDidThatFeel.nearest(to: rpe).titleKey))
    }

    private var parsedWeight: Double? {
        appPreferences.weightUnit.kilogramValue(fromDisplayText: weightText)
    }
```

- [ ] **Step 3: Build to verify it compiles**

Run:

```bash
xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Manual smoke check**

In the running app (or Xcode preview if one covers `EditSetSheet` — it's `private`, so only reachable via `SessionDetailView`'s previews/live navigation): open History, tap a past session, edit a set, confirm the row now reads "Feel" with "Easy" / "Just right" / "Hard" / "—" instead of a raw decimal, and Save still persists correctly.

- [ ] **Step 5: Commit**

```bash
git add Gymbros/Presentation/History/SessionDetailView.swift
git commit -m "$(cat <<'EOF'
feat: simplify SessionDetailView's edit-set RPE picker

Same Easy/Just right/Hard/Clear replacement as SetRowView, applied to
the History edit-a-past-set form which had its own copy of the raw
1.0-10.0 menu sharing the same localization keys.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Remove comeback mode's redundant feedback sheet

**Files:**
- Modify: `Gymbros/Presentation/Workout/WorkoutSessionScreen.swift`
- Modify: `Gymbros/Presentation/Workout/WorkoutSessionViewModel.swift`
- Delete: `Gymbros/Presentation/Workout/Components/HowDidThatFeelPicker.swift`
- Modify: `GymbrosTests/WorkoutSessionViewModelTests.swift`

**Interfaces:**
- Consumes: nothing from Tasks 1-4.
- Produces: nothing — this task only removes now-dead code. `WorkoutSessionViewModel.finishExercise(programExerciseId:)` (unchanged, pre-existing) becomes the only path `onFinishExercise` calls.

- [ ] **Step 1: Simplify `onFinishExercise` and remove the sheet in `WorkoutSessionScreen.swift`**

Find:

```swift
    @State private var viewModel = WorkoutSessionViewModel()
    @State private var hasStarted = false
    @State private var feedbackExerciseId: UUID?
```

Replace with:

```swift
    @State private var viewModel = WorkoutSessionViewModel()
    @State private var hasStarted = false
```

Find:

```swift
            onFinishExercise: { programExerciseId in
                if viewModel.isComebackMode, viewModel.hasCompletedSets(for: programExerciseId) {
                    feedbackExerciseId = programExerciseId
                } else {
                    Task { await viewModel.finishExercise(programExerciseId: programExerciseId) }
                }
            },
```

Replace with:

```swift
            onFinishExercise: { programExerciseId in
                Task { await viewModel.finishExercise(programExerciseId: programExerciseId) }
            },
```

Find:

```swift
        .transientErrorAlert(error: Binding(
            get: { viewModel.transientError },
            set: { viewModel.transientError = $0 }
        ))
        .sheet(isPresented: Binding(
            get: { feedbackExerciseId != nil },
            set: { isPresented in
                if isPresented == false { feedbackExerciseId = nil }
            }
        )) {
            HowDidThatFeelPicker { feel in
                guard let programExerciseId = feedbackExerciseId else { return }
                feedbackExerciseId = nil
                Task {
                    if let feel {
                        viewModel.applyFeedback(feel, to: programExerciseId)
                    }
                    await viewModel.finishExercise(programExerciseId: programExerciseId)
                }
            }
            .interactiveDismissDisabled()
        }
        .task {
```

Replace with:

```swift
        .transientErrorAlert(error: Binding(
            get: { viewModel.transientError },
            set: { viewModel.transientError = $0 }
        ))
        .task {
```

- [ ] **Step 2: Remove `applyFeedback` and `hasCompletedSets` from `WorkoutSessionViewModel.swift`**

Find:

```swift
    func hasCompletedSets(for programExerciseId: UUID) -> Bool {
        guard case let .success(data) = state else { return false }
        return data.exerciseSections
            .first { $0.programExercise.id == programExerciseId }?
            .sets.contains(where: \.isCompleted) ?? false
    }

    func applyFeedback(_ feel: HowDidThatFeel, to programExerciseId: UUID) {
        guard case let .success(data) = state else { return }
        let completedSetIds = data.exerciseSections
            .first { $0.programExercise.id == programExerciseId }?
            .sets
            .filter(\.isCompleted)
            .map(\.id) ?? []
        guard completedSetIds.isEmpty == false else { return }

        // Sets live locally until finishSession uploads them; RPE is carried through
        // local row state and included in the WorkoutSet INSERT at finish time.
        for setId in completedSetIds {
            updateRow(setId: setId, save: false) { $0.rpe = feel.rpe }
        }
        saveBackup()
    }

    private func checkBaselineRegained(row: WorkoutSetRowState) {
```

Replace with:

```swift
    private func checkBaselineRegained(row: WorkoutSetRowState) {
```

- [ ] **Step 3: Delete `HowDidThatFeelPicker.swift`**

```bash
rm Gymbros/Presentation/Workout/Components/HowDidThatFeelPicker.swift
```

- [ ] **Step 4: Remove the two dead tests from `WorkoutSessionViewModelTests.swift`**

Find:

```swift
    @Test func applyFeedbackBackFillsRPEForCompletedSets() async throws {
        let workoutRepository = FakeWorkoutRepository()
        let viewModel = makeViewModel(workoutRepository: workoutRepository)
        viewModel.recommendation = comebackRecommendation()

        await viewModel.start(programDayId: ProgramSamples.upperDayId)
        let row = try firstRow(viewModel)
        await viewModel.completeSet(setId: row.id)
        viewModel.applyFeedback(.justRight, to: ProgramSamples.benchProgramExerciseId)

        // RPE is stored locally; no remote call until finishSession uploads sets.
        #expect(workoutRepository.rpeUpdates.isEmpty)
        #expect(try rowState(viewModel, id: row.id).rpe == 7.5)
    }

    @Test func applyFeedbackWithNoCompletedSetsSkipsUpdate() async throws {
        let workoutRepository = FakeWorkoutRepository()
        let viewModel = makeViewModel(workoutRepository: workoutRepository)
        viewModel.recommendation = comebackRecommendation()

        await viewModel.start(programDayId: ProgramSamples.upperDayId)
        viewModel.applyFeedback(.hard, to: ProgramSamples.benchProgramExerciseId)

        #expect(workoutRepository.rpeUpdates.isEmpty)
    }

    @Test func baselineRegainedFiresOncePerSession() async throws {
```

Replace with:

```swift
    @Test func baselineRegainedFiresOncePerSession() async throws {
```

- [ ] **Step 5: Run the full `WorkoutSessionViewModelTests` suite**

Run:

```bash
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/WorkoutSessionViewModelTests
```

Expected: `** TEST SUCCEEDED **` — confirms no other test referenced the removed methods and the remaining comeback tests (e.g. `baselineRegainedFiresOncePerSession`) still pass.

- [ ] **Step 6: Build to verify no other file references the removed symbols**

Run:

```bash
xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add Gymbros/Presentation/Workout/WorkoutSessionScreen.swift Gymbros/Presentation/Workout/WorkoutSessionViewModel.swift GymbrosTests/WorkoutSessionViewModelTests.swift
git rm Gymbros/Presentation/Workout/Components/HowDidThatFeelPicker.swift
git commit -m "$(cat <<'EOF'
refactor: remove comeback mode's redundant end-of-exercise feedback sheet

Per-set input now uses the same Easy/Just right/Hard scale in every
mode, so the separate sheet that used to overwrite every completed
set's RPE at Finish Exercise is redundant and would silently clobber
per-set picks. onFinishExercise now always finishes the exercise
directly, comeback or not.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: RPE verification pass

**Files:** none (verification only).

**Interfaces:**
- Consumes: the complete result of Tasks 1-5.
- Produces: nothing — this is the gate before moving to Skip a Day.

- [ ] **Step 1: Run the full test suite**

```bash
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e'
```

Expected: `** TEST SUCCEEDED **`. In particular, confirm `ComebackRampServiceTests` and `ProgressiveOverloadEngineTests` pass unmodified — this is the check that proves the "zero downstream changes" claim in the design doc.

- [ ] **Step 2: Run the full build**

```bash
xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Re-validate the string catalog**

```bash
jq empty Gymbros/Resources/Localizable.xcstrings && echo "valid json"
```

Expected: `valid json`.

- [ ] **Step 4: Manual smoke test**

Run the app in the iPhone 17e simulator and verify:
1. Start a normal (non-comeback) session. On any set, tap the feel column — confirm the menu shows Easy / Just right / Hard with icons, plus Clear, no raw numbers.
2. Pick each of the three options in turn on different sets — confirm the closed-state icon updates and matches the pick.
3. Force a comeback session (per the existing S06 smoke procedure: edit a `workout_sessions.ended_at` in Supabase to ≥14 days ago). Complete an exercise's sets. Confirm **no** end-of-exercise sheet appears — "Finish Exercise" proceeds directly.
4. In that same comeback session, confirm the per-set feel picks you made still drive the next comeback ramp decision (i.e. `ComebackRampService` is reading real stored RPE values, not something only the old sheet could produce).
5. Open History, edit a past set, confirm the feel row shows the same simplified picker and Save persists correctly.

---

# PART 2 — SKIP A DAY (ONE-OFF DAY SWAP)

### Task 7: "Change day" control on TodayView

**Files:**
- Modify: `Gymbros/Resources/Localizable.xcstrings`
- Modify: `Gymbros/Presentation/Today/TodayView.swift`

**Interfaces:**
- Consumes: `TodayData.activeProgram`, `TodayData.nextDay` (existing, unchanged).
- Produces: nothing new for other tasks — `WorkoutLaunchRoute` construction inside `comebackCard`/`nextWorkoutCard` is unchanged; only the `ProgramDay` value fed into those two functions changes.

- [ ] **Step 1: Add the `today.change_day.button` localization key**

In `Gymbros/Resources/Localizable.xcstrings`, find:

```json
    "today.comeback.ramp.decrease" : {
```

Replace with:

```json
    "today.change_day.button" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Change day"
          }
        },
        "th" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "เปลี่ยนวัน"
          }
        }
      }
    },
    "today.comeback.ramp.decrease" : {
```

- [ ] **Step 2: Validate JSON**

```bash
jq empty Gymbros/Resources/Localizable.xcstrings && echo "valid json"
```

Expected: `valid json`.

- [ ] **Step 3: Add `selectedDay` state and the environment-injected `AppPreferences`**

In `Gymbros/Presentation/Today/TodayView.swift`, find:

```swift
struct TodayView: View {
    @State var viewModel: TodayViewModel
    @Binding var deepLinkedWorkoutRoute: WorkoutLaunchRoute?
    let date: Date
    let onShowPrograms: () -> Void
    private let loadsOnAppear: Bool

    @State private var selectedWorkoutRoute: WorkoutLaunchRoute?
    @State private var didLogComebackCardShown = false
```

Replace with:

```swift
struct TodayView: View {
    @State var viewModel: TodayViewModel
    @Binding var deepLinkedWorkoutRoute: WorkoutLaunchRoute?
    let date: Date
    let onShowPrograms: () -> Void
    private let loadsOnAppear: Bool

    @Environment(AppPreferences.self) private var appPreferences
    @State private var selectedWorkoutRoute: WorkoutLaunchRoute?
    @State private var didLogComebackCardShown = false
    @State private var selectedDay: ProgramDay?
```

- [ ] **Step 4: Wire the "Change day" control into `successState` and add the `changeDayMenu` helper**

Find:

```swift
                    if let nextDay = data.nextDay {
                        if data.recommendation.mode.isComeback {
                            comebackCard(data: data, nextDay: nextDay)
                        } else {
                            nextWorkoutCard(data: data, nextDay: nextDay)
                        }
                    }
                }
                .padding()
            }
        }
    }

    private var noProgramState: some View {
```

Replace with:

```swift
                    if let nextDay = data.nextDay {
                        let displayedDay = selectedDay ?? nextDay
                        if let program = data.activeProgram {
                            changeDayMenu(days: program.days, recommendedDay: nextDay)
                        }
                        if data.recommendation.mode.isComeback {
                            comebackCard(data: data, nextDay: displayedDay)
                        } else {
                            nextWorkoutCard(data: data, nextDay: displayedDay)
                        }
                    }
                }
                .padding()
            }
        }
    }

    @ViewBuilder
    private func changeDayMenu(days: [ProgramDay], recommendedDay: ProgramDay) -> some View {
        let otherDays = days
            .sorted { $0.dayOrder < $1.dayOrder }
            .filter { $0.id != recommendedDay.id }
        if otherDays.isEmpty == false {
            Menu {
                ForEach(otherDays) { day in
                    Button(day.name) {
                        selectedDay = day
                    }
                }
            } label: {
                Label("today.change_day.button", systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline)
            }
            .frame(minHeight: 48)
        }
    }

    private var noProgramState: some View {
```

Note: `otherDays.isEmpty == false` also naturally hides the control on a single-day program (the only day left after excluding `recommendedDay` would be an empty list), matching the design's "Hidden when the active program has only one day" requirement with no separate count check needed. `nextWorkoutCard`/`comebackCard` already render whatever `ProgramDay` they're given (name, exercise preview, `WorkoutLaunchRoute`), so passing `displayedDay` instead of `nextDay` is sufficient — no changes needed inside either function.

- [ ] **Step 5: Build to verify it compiles**

```bash
xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' build
```

Expected: `** BUILD SUCCEEDED **`. (No new/modified unit tests are expected for this task — it's a `TodayView`-local `@State` addition with no `TodayViewModel`/`NextBestSessionEngine` changes, consistent with the design doc's Testing section.)

- [ ] **Step 6: Manual smoke test**

1. On a program with 2+ days, confirm "Change day" appears and lists every day except the recommended one.
2. Pick a different day, tap Start, confirm the session opens for the picked day (not the originally recommended one).
3. Finish that session, return to Today, confirm the next recommendation follows the day actually completed, not the originally-skipped day.
4. Force a comeback scenario (existing S06 smoke procedure), swap to a different day, confirm that day's exercises still show adjusted (ramped-down) weights.
5. On a program with only one day, confirm "Change day" does not appear.

- [ ] **Step 7: Commit**

```bash
git add Gymbros/Resources/Localizable.xcstrings Gymbros/Presentation/Today/TodayView.swift
git commit -m "$(cat <<'EOF'
feat: let the user swap today's recommended day for a different one

Adds a "Change day" menu next to the next-workout/comeback card,
listing every other day in the active program. Picking a day re-uses
the same card-rendering functions with a different ProgramDay -- no
NextBestSessionEngine changes, since comeback adjustments already
span every exercise in the program, not just the recommended day.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

# PART 3 — TRAINING PHASE SETTING

### Task 8: `Profile.trainingPhase` model field

**Files:**
- Modify: `Gymbros/Model/Profile.swift`
- Test: `GymbrosTests/EnumsTests.swift`
- Test: `GymbrosTests/CodableTests.swift`

**Interfaces:**
- Consumes: `TrainingPhase` enum (already exists, unused, at `Gymbros/Model/Enums/TrainingPhase.swift`).
- Produces: `Profile.trainingPhase: TrainingPhase?` (default `nil`) — consumed by Task 10 (`SettingsViewModel`) and Task 16 (`TodayViewModel`'s stall-gating logic).

- [ ] **Step 1: Write the failing tests**

In `GymbrosTests/EnumsTests.swift`, find:

```swift
    @Test func weightUnitConvertsBetweenKilogramsAndPounds() {
        #expect(WeightUnit.kg.formattedKilograms(60) == "60")
        #expect(WeightUnit.lb.formattedKilograms(60) == "132.3")
        #expect(WeightUnit.lb.kilogramValue(fromDisplayText: "132.3")! > 59.9)
        #expect(WeightUnit.lb.kilogramValue(fromDisplayText: "132.3")! < 60.1)
    }
}
```

Replace with:

```swift
    @Test func weightUnitConvertsBetweenKilogramsAndPounds() {
        #expect(WeightUnit.kg.formattedKilograms(60) == "60")
        #expect(WeightUnit.lb.formattedKilograms(60) == "132.3")
        #expect(WeightUnit.lb.kilogramValue(fromDisplayText: "132.3")! > 59.9)
        #expect(WeightUnit.lb.kilogramValue(fromDisplayText: "132.3")! < 60.1)
    }

    @Test func trainingPhaseRoundTripsJSON() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for phase in TrainingPhase.allCases {
            let data = try encoder.encode(phase)
            let decoded = try decoder.decode(TrainingPhase.self, from: data)
            #expect(phase == decoded)
        }
    }
}
```

In `GymbrosTests/CodableTests.swift`, find:

```swift
    @Test func profileDecodesEmailFromSupabaseJSON() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440010",
            "email": "user@example.com",
            "name": "Test User",
            "experience_level": "beginner",
            "goal": "strength",
            "days_per_week": 3,
            "weight_unit": "kg",
            "locale": "th",
            "created_at": "2026-05-08T10:00:00Z",
            "updated_at": "2026-05-08T10:00:00Z"
        }
        """.data(using: .utf8)!

        let profile = try decoder.decode(Profile.self, from: json)

        #expect(profile.email == "user@example.com")
        #expect(profile.name == "Test User")
    }
```

Replace with:

```swift
    @Test func profileDecodesEmailFromSupabaseJSON() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440010",
            "email": "user@example.com",
            "name": "Test User",
            "experience_level": "beginner",
            "goal": "strength",
            "training_phase": "bulk",
            "days_per_week": 3,
            "weight_unit": "kg",
            "locale": "th",
            "created_at": "2026-05-08T10:00:00Z",
            "updated_at": "2026-05-08T10:00:00Z"
        }
        """.data(using: .utf8)!

        let profile = try decoder.decode(Profile.self, from: json)

        #expect(profile.email == "user@example.com")
        #expect(profile.name == "Test User")
        #expect(profile.trainingPhase == .bulk)
    }

    @Test func profileDecodesNilTrainingPhaseWhenAbsent() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440011",
            "email": "user2@example.com",
            "name": "Test User Two",
            "experience_level": "beginner",
            "goal": "strength",
            "days_per_week": 3,
            "weight_unit": "kg",
            "locale": "en",
            "created_at": "2026-05-08T10:00:00Z",
            "updated_at": "2026-05-08T10:00:00Z"
        }
        """.data(using: .utf8)!

        let profile = try decoder.decode(Profile.self, from: json)

        #expect(profile.trainingPhase == nil)
    }
```

- [ ] **Step 2: Run tests to verify they fail to build**

```bash
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/EnumsTests -only-testing:GymbrosTests/CodableTests
```

Expected: **BUILD FAILURE** — `value of type 'Profile' has no member 'trainingPhase'` (the `trainingPhaseRoundTripsJSON` test itself would pass since `TrainingPhase` already exists standalone, but the `CodableTests` additions won't compile yet).

- [ ] **Step 3: Add the field to `Profile`**

In `Gymbros/Model/Profile.swift`, find:

```swift
struct Profile: Codable, Identifiable, Equatable {
    let id: UUID
    var email: String?
    var name: String?
    var experienceLevel: ExperienceLevel?
    var goal: Goal?
    var daysPerWeek: Int?
    var weightUnit: WeightUnit
    var locale: String
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, email, name, goal, locale
        case experienceLevel = "experience_level"
        case daysPerWeek = "days_per_week"
        case weightUnit = "weight_unit"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
```

Replace with:

```swift
struct Profile: Codable, Identifiable, Equatable {
    let id: UUID
    var email: String?
    var name: String?
    var experienceLevel: ExperienceLevel?
    var goal: Goal?
    var trainingPhase: TrainingPhase? = nil
    var daysPerWeek: Int?
    var weightUnit: WeightUnit
    var locale: String
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, email, name, goal, locale
        case experienceLevel = "experience_level"
        case trainingPhase = "training_phase"
        case daysPerWeek = "days_per_week"
        case weightUnit = "weight_unit"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
```

The `= nil` default (unlike `goal`/`daysPerWeek`, added when the struct was first written with no default) means the synthesized memberwise initializer treats `trainingPhase` as optional-to-pass — every existing `Profile(...)` call site in the codebase (the `SettingsViewModel` preview fake, `SettingsViewModelTests`' `makeProfile` helper) keeps compiling unchanged.

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/EnumsTests -only-testing:GymbrosTests/CodableTests
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Full build to catch any other affected call site**

```bash
xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add Gymbros/Model/Profile.swift GymbrosTests/EnumsTests.swift GymbrosTests/CodableTests.swift
git commit -m "$(cat <<'EOF'
feat: add Profile.trainingPhase field

Wires up the previously-unused TrainingPhase enum onto Profile as a
nilable field, matching goal's optionality. No behavior change yet --
Settings and the overload advisor wiring land in later tasks.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: Supabase migration for `profiles.training_phase` — REQUIRES EXPLICIT USER APPROVAL

**Files:**
- Create: `supabase/migrations/<today's date>_profiles_training_phase.sql`

**Interfaces:**
- Consumes: nothing.
- Produces: the `profiles.training_phase` column that `ProfileRepository.fetchCurrentProfile()` / `updateProfile(_:)` (unchanged in this task) will read and write once Task 10 wires up Settings. Nothing else in this sprint's build/test cycle depends on this column existing in a live database — `CodableTests` decodes hand-built JSON, not a live fetch — so this task can be done at any point without blocking Tasks 10-17.

- [ ] **Step 1: STOP — present the exact SQL to the user and wait for explicit confirmation**

Per `CLAUDE.md` → "Data Safety and Approval": every agent MUST obtain explicit user confirmation before applying any migration, even a purely additive one like this. Before running anything against a live database, show the user this exact SQL and this exact impact statement, then wait for an explicit yes:

> This adds one nullable `text` column (`training_phase`) to the existing `profiles`
> table. It does not modify, drop, or rename any existing column, does not touch any
> other table, and does not require a default value or backfill (existing rows simply
> get `NULL`). It is safe to run on a table with existing rows. No rollback beyond
> `alter table public.profiles drop column training_phase;` is needed if you want to
> undo it.

Do not call `mcp__supabase__apply_migration`, `mcp__supabase__execute_sql`, or any other execution path against a live project until the user has explicitly confirmed. Writing the migration *file* to disk (Step 2) is safe and does not require approval — only *applying* it does.

- [ ] **Step 2: Write the migration file**

Create `supabase/migrations/<today's date>_profiles_training_phase.sql` (use the actual current date in `YYYY-MM-DD` format, matching the existing `supabase/migrations/2026-05-11_program_exercises_target_weight.sql` naming convention):

```sql
alter table public.profiles
    add column if not exists training_phase text null;
```

- [ ] **Step 3: After explicit approval, apply the migration and verify**

Only after the user has explicitly confirmed in Step 1: apply the migration via whichever workflow the user's Supabase project actually uses (Supabase CLI `supabase db push`, the Supabase Studio SQL editor, or the `mcp__supabase__apply_migration` tool if available and the user directs you to use it). Then verify:

```sql
select column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public' and table_name = 'profiles' and column_name = 'training_phase';
```

Expected: one row, `data_type = 'text'`, `is_nullable = 'YES'`.

- [ ] **Step 4: Commit the migration file**

```bash
git add supabase/migrations/
git commit -m "$(cat <<'EOF'
feat: add profiles.training_phase column

Nullable text column backing the new Training Phase Setting feature.
Additive-only; existing rows get NULL, no backfill needed.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 10: `SettingsViewModel.updateTrainingPhase(_:)`

**Files:**
- Modify: `Gymbros/Presentation/Settings/SettingsViewModel.swift`
- Test: `GymbrosTests/SettingsViewModelTests.swift`

**Interfaces:**
- Consumes: `Profile.trainingPhase` from Task 8.
- Produces: `SettingsData.trainingPhase: TrainingPhase?`, `SettingsViewModel.updateTrainingPhase(_ phase: TrainingPhase) async` — consumed by Task 11's `SettingsView` row.

- [ ] **Step 1: Extend the `makeProfile` test helper and write the failing tests**

In `GymbrosTests/SettingsViewModelTests.swift`, find:

```swift
    private func makeProfile(weightUnit: WeightUnit = .kg) -> Profile {
        Profile(
            id: UUID(),
            email: "test@example.com",
            name: "Test User",
            experienceLevel: .intermediate,
            goal: .strength,
            daysPerWeek: 3,
            weightUnit: weightUnit,
            locale: "en",
            createdAt: Date(),
            updatedAt: Date()
        )
    }
```

Replace with:

```swift
    private func makeProfile(weightUnit: WeightUnit = .kg, trainingPhase: TrainingPhase? = nil) -> Profile {
        Profile(
            id: UUID(),
            email: "test@example.com",
            name: "Test User",
            experienceLevel: .intermediate,
            goal: .strength,
            trainingPhase: trainingPhase,
            daysPerWeek: 3,
            weightUnit: weightUnit,
            locale: "en",
            createdAt: Date(),
            updatedAt: Date()
        )
    }
```

Find:

```swift
    @Test func updateWeightUnit_cancellationRollsBackWithoutAlert() async throws {
        let profile = makeProfile(weightUnit: .kg)
        let repo = FakeProfileRepository()
        repo.profile = profile
        repo.updateError = CancellationError()
        let appPreferences = AppPreferences(weightUnit: .kg)
        let vm = SettingsViewModel(profileRepository: repo, authService: FakeAuthService(), appPreferences: appPreferences)

        await vm.load()
        await vm.updateWeightUnit(.lb)

        let data = try successValue(vm.state)
        #expect(data.weightUnit == .kg)
        #expect(appPreferences.weightUnit == .kg)
        #expect(vm.transientError == nil)
    }

    @Test func signOut_success() async throws {
```

Replace with:

```swift
    @Test func updateWeightUnit_cancellationRollsBackWithoutAlert() async throws {
        let profile = makeProfile(weightUnit: .kg)
        let repo = FakeProfileRepository()
        repo.profile = profile
        repo.updateError = CancellationError()
        let appPreferences = AppPreferences(weightUnit: .kg)
        let vm = SettingsViewModel(profileRepository: repo, authService: FakeAuthService(), appPreferences: appPreferences)

        await vm.load()
        await vm.updateWeightUnit(.lb)

        let data = try successValue(vm.state)
        #expect(data.weightUnit == .kg)
        #expect(appPreferences.weightUnit == .kg)
        #expect(vm.transientError == nil)
    }

    @Test func updateTrainingPhase_success() async throws {
        let profile = makeProfile(trainingPhase: nil)
        let repo = FakeProfileRepository()
        repo.profile = profile
        let vm = SettingsViewModel(profileRepository: repo, authService: FakeAuthService(), appPreferences: AppPreferences())

        await vm.load()
        await vm.updateTrainingPhase(.bulk)

        let data = try successValue(vm.state)
        #expect(data.trainingPhase == .bulk)
        #expect(repo.updatedProfile?.trainingPhase == .bulk)
        #expect(vm.transientError == nil)
    }

    @Test func updateTrainingPhase_failure_setsTransientErrorAndRollsBack() async throws {
        let profile = makeProfile(trainingPhase: .bulk)
        let repo = FakeProfileRepository()
        repo.profile = profile
        repo.updateError = AppError.network(.offline)
        let vm = SettingsViewModel(profileRepository: repo, authService: FakeAuthService(), appPreferences: AppPreferences())

        await vm.load()
        await vm.updateTrainingPhase(.cut)

        let data = try successValue(vm.state)
        #expect(data.trainingPhase == .bulk)
        #expect(vm.transientError == .network(.offline))
    }

    @Test func signOut_success() async throws {
```

- [ ] **Step 2: Run tests to verify they fail to build**

```bash
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/SettingsViewModelTests
```

Expected: **BUILD FAILURE** — `value of type 'SettingsData' has no member 'trainingPhase'` / `value of type 'SettingsViewModel' has no member 'updateTrainingPhase'`.

- [ ] **Step 3: Implement `SettingsData.trainingPhase` and `updateTrainingPhase(_:)`**

In `Gymbros/Presentation/Settings/SettingsViewModel.swift`, find:

```swift
struct SettingsData: Equatable {
    var weightUnit: WeightUnit
    let appVersion: String
}
```

Replace with:

```swift
struct SettingsData: Equatable {
    var weightUnit: WeightUnit
    var trainingPhase: TrainingPhase?
    let appVersion: String
}
```

Find:

```swift
            state = .success(SettingsData(
                weightUnit: fetchedProfile.weightUnit,
                appVersion: appVersionString
            ))
```

Replace with:

```swift
            state = .success(SettingsData(
                weightUnit: fetchedProfile.weightUnit,
                trainingPhase: fetchedProfile.trainingPhase,
                appVersion: appVersionString
            ))
```

Find:

```swift
    func updateWeightUnit(_ unit: WeightUnit) async {
        guard var updatedProfile = profile else { return }
        updatedProfile.weightUnit = unit

        let previousState = state
        if case .success(var data) = state {
            data.weightUnit = unit
            state = .success(data)
        }
        appPreferences.weightUnit = unit

        do {
            try await profileRepository.updateProfile(updatedProfile)
            self.profile = updatedProfile
        } catch {
            if let oldProfile = profile {
                appPreferences.apply(profile: oldProfile)
            }
            state = previousState
            let appError = ErrorMapper.map(error, context: .init(operation: "updateWeightUnit"))
            if appError != .cancelled {
                transientError = appError
            }
        }
    }

    func signOut() async {
```

Replace with:

```swift
    func updateWeightUnit(_ unit: WeightUnit) async {
        guard var updatedProfile = profile else { return }
        updatedProfile.weightUnit = unit

        let previousState = state
        if case .success(var data) = state {
            data.weightUnit = unit
            state = .success(data)
        }
        appPreferences.weightUnit = unit

        do {
            try await profileRepository.updateProfile(updatedProfile)
            self.profile = updatedProfile
        } catch {
            if let oldProfile = profile {
                appPreferences.apply(profile: oldProfile)
            }
            state = previousState
            let appError = ErrorMapper.map(error, context: .init(operation: "updateWeightUnit"))
            if appError != .cancelled {
                transientError = appError
            }
        }
    }

    func updateTrainingPhase(_ phase: TrainingPhase) async {
        guard var updatedProfile = profile else { return }
        updatedProfile.trainingPhase = phase

        let previousState = state
        if case .success(var data) = state {
            data.trainingPhase = phase
            state = .success(data)
        }

        do {
            try await profileRepository.updateProfile(updatedProfile)
            self.profile = updatedProfile
        } catch {
            state = previousState
            let appError = ErrorMapper.map(error, context: .init(operation: "updateTrainingPhase"))
            if appError != .cancelled {
                transientError = appError
            }
        }
    }

    func signOut() async {
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/SettingsViewModelTests
```

Expected: `** TEST SUCCEEDED **`, all tests including the two new ones pass.

- [ ] **Step 5: Commit**

```bash
git add Gymbros/Presentation/Settings/SettingsViewModel.swift GymbrosTests/SettingsViewModelTests.swift
git commit -m "$(cat <<'EOF'
feat: add SettingsViewModel.updateTrainingPhase(_:)

Mirrors updateWeightUnit(_:) exactly: optimistic local update, rollback
on failure, .cancelled errors suppressed from transientError.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 11: Settings row + localization

**Files:**
- Modify: `Gymbros/Resources/Localizable.xcstrings`
- Modify: `Gymbros/Presentation/Settings/SettingsView.swift`

**Interfaces:**
- Consumes: `SettingsData.trainingPhase`, `SettingsViewModel.updateTrainingPhase(_:)` from Task 10.
- Produces: nothing — this is the final, user-visible piece of Training Phase Setting.

- [ ] **Step 1: Add the `settings.training_phase.*` localization cluster**

In `Gymbros/Resources/Localizable.xcstrings`, find:

```json
    "settings.weight_unit.kg" : {
```

Replace with:

```json
    "settings.training_phase.bulk" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Building muscle"
          }
        },
        "th" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "เพิ่มกล้ามเนื้อ"
          }
        }
      }
    },
    "settings.training_phase.cut" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Losing weight"
          }
        },
        "th" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "ลดน้ำหนัก"
          }
        }
      }
    },
    "settings.training_phase.maintain" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Maintaining"
          }
        },
        "th" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "คงน้ำหนัก"
          }
        }
      }
    },
    "settings.training_phase.title" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Training phase"
          }
        },
        "th" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "ช่วงการฝึก"
          }
        }
      }
    },
    "settings.weight_unit.kg" : {
```

- [ ] **Step 2: Validate JSON**

```bash
jq empty Gymbros/Resources/Localizable.xcstrings && echo "valid json"
```

Expected: `valid json`.

- [ ] **Step 3: Add the Training Phase row to `SettingsView`**

In `Gymbros/Presentation/Settings/SettingsView.swift`, find:

```swift
                    Section(header: Text("settings.section.preferences")) {
                        HStack {
                            Text("settings.weight_unit.label")
                            Spacer()
                            Picker("", selection: Binding(
                                get: { data.weightUnit },
                                set: { newUnit in
                                    Task { await viewModel.updateWeightUnit(newUnit) }
                                }
                            )) {
                                Text("settings.weight_unit.kg").tag(WeightUnit.kg)
                                Text("settings.weight_unit.lb").tag(WeightUnit.lb)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 120)
                            .accessibilityLabel(Text("settings.weight_unit.label"))
                            .accessibilityValue(Text(verbatim: data.weightUnit.localizedAbbreviation))
                        }
                        .frame(minHeight: 48)
                    }
```

Replace with:

```swift
                    Section(header: Text("settings.section.preferences")) {
                        HStack {
                            Text("settings.weight_unit.label")
                            Spacer()
                            Picker("", selection: Binding(
                                get: { data.weightUnit },
                                set: { newUnit in
                                    Task { await viewModel.updateWeightUnit(newUnit) }
                                }
                            )) {
                                Text("settings.weight_unit.kg").tag(WeightUnit.kg)
                                Text("settings.weight_unit.lb").tag(WeightUnit.lb)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 120)
                            .accessibilityLabel(Text("settings.weight_unit.label"))
                            .accessibilityValue(Text(verbatim: data.weightUnit.localizedAbbreviation))
                        }
                        .frame(minHeight: 48)

                        HStack {
                            Text("settings.training_phase.title")
                            Spacer()
                            Menu {
                                Button("settings.training_phase.bulk") {
                                    Task { await viewModel.updateTrainingPhase(.bulk) }
                                }
                                Button("settings.training_phase.cut") {
                                    Task { await viewModel.updateTrainingPhase(.cut) }
                                }
                                Button("settings.training_phase.maintain") {
                                    Task { await viewModel.updateTrainingPhase(.maintain) }
                                }
                            } label: {
                                Text(trainingPhaseLabel(data.trainingPhase))
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityLabel(Text("settings.training_phase.title"))
                            .accessibilityValue(Text(trainingPhaseLabel(data.trainingPhase)))
                        }
                        .frame(minHeight: 48)
                    }
```

- [ ] **Step 4: Add the `trainingPhaseLabel(_:)` helper**

Find:

```swift
        .navigationTitle("settings.title")
        .transientErrorAlert(error: $viewModel.transientError)
        .task {
            guard loadsOnAppear else { return }
            await viewModel.load()
        }
    }
}

struct PlaceholderSheet: View {
```

Replace with:

```swift
        .navigationTitle("settings.title")
        .transientErrorAlert(error: $viewModel.transientError)
        .task {
            guard loadsOnAppear else { return }
            await viewModel.load()
        }
    }

    private func trainingPhaseLabel(_ phase: TrainingPhase?) -> String {
        switch phase {
        case .bulk: String(localized: "settings.training_phase.bulk")
        case .cut: String(localized: "settings.training_phase.cut")
        case .maintain: String(localized: "settings.training_phase.maintain")
        case nil: "—"
        }
    }
}

struct PlaceholderSheet: View {
```

- [ ] **Step 5: Build to verify it compiles**

```bash
xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Manual smoke test**

Open Settings, confirm the new "Training phase" row shows "—" when unset. Tap it, pick "Building muscle," confirm the row updates immediately. Relaunch the app (or pull-to-refresh Settings), confirm the choice persisted.

- [ ] **Step 7: Commit**

```bash
git add Gymbros/Resources/Localizable.xcstrings Gymbros/Presentation/Settings/SettingsView.swift
git commit -m "$(cat <<'EOF'
feat: add Training Phase row to Settings

Lets the user record bulk/cut/maintain, mirroring the existing
weight-unit row's styling and interaction pattern. No feature reads
this value yet -- the Progressive Overload Advisor is next.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

# PART 4 — PROGRESSIVE OVERLOAD ADVISOR

### Task 12: `StallDetector` pure service

**Files:**
- Create: `Gymbros/Data/Services/StallDetector.swift`
- Test: `GymbrosTests/StallDetectorTests.swift` (create)

**Interfaces:**
- Consumes: `WorkoutSession`, `WorkoutSet` (existing models, unchanged).
- Produces: `StallDetector.isStalled(exerciseId:recentSessions:sets:) -> Bool`, `StallDetector.sessionThreshold: Int` (= 4), `StallDetector.maxRPEForStall: Double` (= 8.0) — consumed by Task 16's `TodayViewModel` wiring.

- [ ] **Step 1: Write the failing tests**

Create `GymbrosTests/StallDetectorTests.swift`:

```swift
import Testing
import Foundation
@testable import Gymbros

@Suite("StallDetector")
struct StallDetectorTests {
    private let exerciseId = UUID()

    private func session(daysAgo: Double) -> WorkoutSession {
        let start = Date.now.addingTimeInterval(-daysAgo * 86_400)
        return WorkoutSession(
            id: UUID(),
            userId: UUID(),
            programDayId: nil,
            startedAt: start,
            endedAt: start.addingTimeInterval(3_000),
            notes: nil,
            createdAt: start
        )
    }

    private func set(sessionId: UUID, exerciseId: UUID? = nil, weight: Double, rpe: Double?) -> WorkoutSet {
        WorkoutSet(
            id: UUID(),
            sessionId: sessionId,
            exerciseId: exerciseId ?? self.exerciseId,
            programExerciseId: nil,
            setNumber: 1,
            weight: weight,
            reps: 8,
            rpe: rpe,
            targetRestSeconds: nil,
            actualRestSeconds: nil,
            restStartedAt: nil,
            restEndedAt: nil,
            completedAt: Date.now,
            notes: nil
        )
    }

    @Test func sameWeightFourSessionsIsStalled() {
        let sessions = [1, 3, 5, 7].map { session(daysAgo: Double($0)) }
        var sets: [UUID: [WorkoutSet]] = [:]
        for s in sessions { sets[s.id] = [set(sessionId: s.id, weight: 80, rpe: 7.0)] }

        #expect(StallDetector().isStalled(exerciseId: exerciseId, recentSessions: sessions, sets: sets))
    }

    @Test func fewerThanFourSessionsIsNotStalled() {
        let sessions = [1, 3, 5].map { session(daysAgo: Double($0)) }
        var sets: [UUID: [WorkoutSet]] = [:]
        for s in sessions { sets[s.id] = [set(sessionId: s.id, weight: 80, rpe: 7.0)] }

        #expect(StallDetector().isStalled(exerciseId: exerciseId, recentSessions: sessions, sets: sets) == false)
    }

    @Test func weightDiffersAcrossSessionsIsNotStalled() {
        let sessions = [1, 3, 5, 7].map { session(daysAgo: Double($0)) }
        var sets: [UUID: [WorkoutSet]] = [:]
        let weights: [Double] = [80, 80, 77.5, 80]
        for (s, weight) in zip(sessions, weights) { sets[s.id] = [set(sessionId: s.id, weight: weight, rpe: 7.0)] }

        #expect(StallDetector().isStalled(exerciseId: exerciseId, recentSessions: sessions, sets: sets) == false)
    }

    @Test func rpeAbove8BlocksStall() {
        let sessions = [1, 3, 5, 7].map { session(daysAgo: Double($0)) }
        var sets: [UUID: [WorkoutSet]] = [:]
        let rpes: [Double?] = [7.0, 7.0, 8.5, 7.0]
        for (s, rpe) in zip(sessions, rpes) { sets[s.id] = [set(sessionId: s.id, weight: 80, rpe: rpe)] }

        #expect(StallDetector().isStalled(exerciseId: exerciseId, recentSessions: sessions, sets: sets) == false)
    }

    @Test func missingRPEDoesNotBlockStall() {
        let sessions = [1, 3, 5, 7].map { session(daysAgo: Double($0)) }
        var sets: [UUID: [WorkoutSet]] = [:]
        let rpes: [Double?] = [7.0, nil, nil, 7.0]
        for (s, rpe) in zip(sessions, rpes) { sets[s.id] = [set(sessionId: s.id, weight: 80, rpe: rpe)] }

        #expect(StallDetector().isStalled(exerciseId: exerciseId, recentSessions: sessions, sets: sets))
    }

    @Test func sessionsWithoutThisExerciseAreIgnored() {
        let otherExerciseId = UUID()
        let qualifying = [1, 3, 5, 7].map { session(daysAgo: Double($0)) }
        let noise = [2, 4].map { session(daysAgo: Double($0)) }
        var sets: [UUID: [WorkoutSet]] = [:]
        for s in qualifying {
            sets[s.id] = [set(sessionId: s.id, weight: 80, rpe: 7.0)]
        }
        for s in noise {
            sets[s.id] = [set(sessionId: s.id, exerciseId: otherExerciseId, weight: 999, rpe: 7.0)]
        }

        let allSessions = (qualifying + noise).sorted { $0.startedAt > $1.startedAt }
        #expect(StallDetector().isStalled(exerciseId: exerciseId, recentSessions: allSessions, sets: sets))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/StallDetectorTests
```

Expected: **BUILD FAILURE** — `cannot find type 'StallDetector' in scope`.

- [ ] **Step 3: Implement `StallDetector`**

Create `Gymbros/Data/Services/StallDetector.swift`:

```swift
import Foundation

struct StallDetector {
    static let sessionThreshold = 4
    static let maxRPEForStall = 8.0

    func isStalled(
        exerciseId: UUID,
        recentSessions: [WorkoutSession],
        sets: [UUID: [WorkoutSet]]
    ) -> Bool {
        let qualifyingSessions = recentSessions
            .filter { session in (sets[session.id] ?? []).contains { $0.exerciseId == exerciseId } }
            .prefix(Self.sessionThreshold)

        guard qualifyingSessions.count == Self.sessionThreshold else { return false }

        let topWeights = qualifyingSessions.map { session in
            (sets[session.id] ?? [])
                .filter { $0.exerciseId == exerciseId }
                .map(\.weight)
                .max() ?? 0
        }
        guard let firstWeight = topWeights.first, topWeights.allSatisfy({ $0 == firstWeight }) else {
            return false
        }

        let anyOverThreshold = qualifyingSessions.contains { session in
            (sets[session.id] ?? [])
                .filter { $0.exerciseId == exerciseId }
                .contains { ($0.rpe ?? 0) > Self.maxRPEForStall }
        }
        return anyOverThreshold == false
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/StallDetectorTests
```

Expected: `** TEST SUCCEEDED **`, all 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Gymbros/Data/Services/StallDetector.swift GymbrosTests/StallDetectorTests.swift
git commit -m "$(cat <<'EOF'
feat: add StallDetector pure service

Detects the same top-set weight held across the 4 most recent
qualifying sessions for an exercise, gated on no session among those
4 recording an RPE above 8.0 (missing RPE does not block detection).
4 reuses NextBestSessionEngine.boundedExitSessionCount's convention;
8.0 reuses ProgressiveOverloadEngine's own hold-don't-suggest ceiling.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 13: `OverloadAdvisorSnoozeStore` local persistence

**Files:**
- Create: `Gymbros/Data/Services/OverloadAdvisorSnoozeStore.swift`
- Test: `GymbrosTests/OverloadAdvisorSnoozeStoreTests.swift` (create)

**Interfaces:**
- Consumes: nothing.
- Produces: `OverloadAdvisorSnoozing` protocol + `OverloadAdvisorSnoozeStore` concrete type — consumed by Task 16's `TodayViewModel`.

- [ ] **Step 1: Write the failing tests**

Create `GymbrosTests/OverloadAdvisorSnoozeStoreTests.swift`:

```swift
import Testing
import Foundation
@testable import Gymbros

@MainActor
@Suite("OverloadAdvisorSnoozeStore")
struct OverloadAdvisorSnoozeStoreTests {
    @Test func neverSnoozedReturnsFalse() {
        let store = makeStore()
        #expect(store.isSnoozed(programExerciseId: UUID(), now: .now) == false)
    }

    @Test func snoozedWithin14DaysReturnsTrue() {
        let store = makeStore()
        let id = UUID()
        let now = Date.now
        store.snooze(programExerciseId: id, now: now)

        #expect(store.isSnoozed(programExerciseId: id, now: now.addingTimeInterval(5 * 24 * 3600)))
    }

    @Test func snoozed15DaysAgoReturnsFalse() {
        let store = makeStore()
        let id = UUID()
        let now = Date.now
        store.snooze(programExerciseId: id, now: now)

        #expect(store.isSnoozed(programExerciseId: id, now: now.addingTimeInterval(15 * 24 * 3600)) == false)
    }

    @Test func persistsAcrossInstancesSharingUserDefaults() {
        let defaults = UserDefaults(suiteName: "OverloadAdvisorSnoozeStoreTests.\(UUID().uuidString)")!
        let id = UUID()
        let now = Date.now
        OverloadAdvisorSnoozeStore(userDefaults: defaults).snooze(programExerciseId: id, now: now)

        let reloaded = OverloadAdvisorSnoozeStore(userDefaults: defaults)
        #expect(reloaded.isSnoozed(programExerciseId: id, now: now.addingTimeInterval(24 * 3600)))
    }

    private func makeStore() -> OverloadAdvisorSnoozeStore {
        OverloadAdvisorSnoozeStore(userDefaults: UserDefaults(suiteName: "OverloadAdvisorSnoozeStoreTests.\(UUID().uuidString)")!)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/OverloadAdvisorSnoozeStoreTests
```

Expected: **BUILD FAILURE** — `cannot find type 'OverloadAdvisorSnoozeStore' in scope`.

- [ ] **Step 3: Implement `OverloadAdvisorSnoozeStore`**

Create `Gymbros/Data/Services/OverloadAdvisorSnoozeStore.swift`:

```swift
import Foundation

@MainActor
protocol OverloadAdvisorSnoozing {
    func isSnoozed(programExerciseId: UUID, now: Date) -> Bool
    func snooze(programExerciseId: UUID, now: Date)
}

@MainActor
final class OverloadAdvisorSnoozeStore: OverloadAdvisorSnoozing {
    static let snoozeDuration: TimeInterval = 14 * 24 * 3600
    private let userDefaults: UserDefaults
    private let key = "overload_advisor_snoozed_until"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func isSnoozed(programExerciseId: UUID, now: Date) -> Bool {
        guard let until = snoozedUntil[programExerciseId.uuidString] else { return false }
        return until > now
    }

    func snooze(programExerciseId: UUID, now: Date) {
        var dict = snoozedUntil
        dict[programExerciseId.uuidString] = now.addingTimeInterval(Self.snoozeDuration)
        save(dict)
    }

    private var snoozedUntil: [String: Date] {
        guard let data = userDefaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: Date].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func save(_ dict: [String: Date]) {
        guard let data = try? JSONEncoder().encode(dict) else { return }
        userDefaults.set(data, forKey: key)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/OverloadAdvisorSnoozeStoreTests
```

Expected: `** TEST SUCCEEDED **`, all 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Gymbros/Data/Services/OverloadAdvisorSnoozeStore.swift GymbrosTests/OverloadAdvisorSnoozeStoreTests.swift
git commit -m "$(cat <<'EOF'
feat: add OverloadAdvisorSnoozeStore

Local-only, UserDefaults-backed 14-day snooze per programExerciseId,
mirroring RestTimerNotificationScheduler's injectable-UserDefaults
style for testability. No cross-device sync -- a low-stakes,
per-device UI preference.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 14: Progressive Overload Advisor localization

**Files:**
- Modify: `Gymbros/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: nothing.
- Produces: `today.overload_advisor.title`, `today.overload_advisor.body`, `today.overload_advisor.not_now`, `today.overload_advisor.try_next_time`, `accessibility.today.overload_advisor_card` — consumed by Task 15's `OverloadAdvisorCardView`.

- [ ] **Step 1: Add the accessibility key**

In `Gymbros/Resources/Localizable.xcstrings`, find:

```json
    "accessibility.today.start" : {
```

Replace with:

```json
    "accessibility.today.overload_advisor_card" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Overload advisor. %@"
          }
        },
        "th" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "การ์ดแนะนำเพิ่มน้ำหนัก %@"
          }
        }
      }
    },
    "accessibility.today.start" : {
```

- [ ] **Step 2: Add the `today.overload_advisor.*` cluster**

Find:

```json
    "today.start_cta" : {
```

Replace with:

```json
    "today.overload_advisor.body" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "You've held %@ on %@ for 4 sessions in a row."
          }
        },
        "th" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "คุณใช้น้ำหนัก %@ กับ %@ มา 4 ครั้งติดกันแล้ว"
          }
        }
      }
    },
    "today.overload_advisor.not_now" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Not now"
          }
        },
        "th" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "ยังไม่ตอนนี้"
          }
        }
      }
    },
    "today.overload_advisor.title" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Same weight for a while"
          }
        },
        "th" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "น้ำหนักเท่าเดิมมาสักพัก"
          }
        }
      }
    },
    "today.overload_advisor.try_next_time" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Try it next time"
          }
        },
        "th" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "ลองครั้งหน้า"
          }
        }
      }
    },
    "today.start_cta" : {
```

- [ ] **Step 3: Validate JSON and key coverage**

```bash
jq empty Gymbros/Resources/Localizable.xcstrings && echo "valid json"
python3 -c "
import json
d = json.load(open('Gymbros/Resources/Localizable.xcstrings'))
keys = ['today.overload_advisor.title', 'today.overload_advisor.body',
        'today.overload_advisor.not_now', 'today.overload_advisor.try_next_time',
        'accessibility.today.overload_advisor_card']
for k in keys:
    locs = d['strings'][k]['localizations']
    assert 'en' in locs and 'th' in locs, f'{k} missing a locale'
    print('OK', k)
"
```

Expected: `valid json`, then `OK <key>` for each of the 5 keys.

- [ ] **Step 4: Commit**

```bash
git add Gymbros/Resources/Localizable.xcstrings
git commit -m "$(cat <<'EOF'
i18n: add Progressive Overload Advisor localization keys

today.overload_advisor.* (title/body/try_next_time/not_now) plus one
accessibility key for the new Today card.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 15: `OverloadAdvisorCardView`

**Files:**
- Create: `Gymbros/Presentation/Today/Components/OverloadAdvisorCardView.swift`

**Interfaces:**
- Consumes: `today.overload_advisor.*` / `accessibility.today.overload_advisor_card` keys from Task 14.
- Produces: `OverloadAdvisorCardView` SwiftUI view — consumed by Task 17's `TodayView` wiring.

- [ ] **Step 1: Create the view**

Create `Gymbros/Presentation/Today/Components/OverloadAdvisorCardView.swift`:

```swift
import SwiftUI

struct OverloadAdvisorCardView: View {
    let exerciseName: String
    let weightText: String
    let weightUnitAbbreviation: String
    let onTryNextTime: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("today.overload_advisor.title")
                .font(.title3.bold())
                .foregroundStyle(.primary)

            Text(bodyText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button(action: onNotNow) {
                    Text("today.overload_advisor.not_now")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .frame(minHeight: 48)

                Button(action: onTryNextTime) {
                    Text("today.overload_advisor.try_next_time")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .frame(minHeight: 48)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(String(format: String(localized: "accessibility.today.overload_advisor_card"), bodyText)))
    }

    private var bodyText: String {
        String(
            format: String(localized: "today.overload_advisor.body"),
            "\(weightText) \(weightUnitAbbreviation)",
            exerciseName
        )
    }
}

#if DEBUG
#Preview("Stalled") {
    OverloadAdvisorCardView(
        exerciseName: "Bench Press",
        weightText: "60",
        weightUnitAbbreviation: "kg",
        onTryNextTime: {},
        onNotNow: {}
    )
    .padding()
}
#endif
```

- [ ] **Step 2: Build to verify it compiles**

```bash
xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' build
```

Expected: `** BUILD SUCCEEDED **`. (No dedicated unit test — Views are verified by build success plus manual smoke, per project convention; this view is wired into `TodayView` and smoke-tested in Task 17.)

- [ ] **Step 3: Commit**

```bash
git add Gymbros/Presentation/Today/Components/OverloadAdvisorCardView.swift
git commit -m "$(cat <<'EOF'
feat: add OverloadAdvisorCardView

Same card shape as ComebackCardView: no custom colors, 48pt tap
targets on both actions.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 16: `TodayViewModel` wiring — stall detection, training-phase gating, snooze/apply actions

**Files:**
- Modify: `Gymbros/Presentation/Today/TodayViewModel.swift`
- Test: `GymbrosTests/TodayViewModelTests.swift`

**Interfaces:**
- Consumes: `StallDetector` from Task 12, `OverloadAdvisorSnoozing`/`OverloadAdvisorSnoozeStore` from Task 13, `Profile.trainingPhase` from Task 8, `ProgramRepositoryProviding.updateProgramExercise(_:)` (existing), `ProgressiveOverloadEngine.weightIncrementKg` (existing, unchanged), `ExerciseRepositoryProviding.fetchAll()` (existing, unchanged).
- Produces: `TodayData.stalledExercise: StalledExercise?`, `TodayData.trainingPhase: TrainingPhase?`, `TodayViewModel.tryOverloadSuggestion(_:) async`, `TodayViewModel.snoozeOverloadSuggestion(_:)` — consumed by Task 17's `TodayView` wiring.

- [ ] **Step 1: Add `StalledExercise` and extend `TodayData`**

In `Gymbros/Presentation/Today/TodayViewModel.swift`, find:

```swift
struct TodayData {
    var activeProgram: Program?
    var nextDay: ProgramDay?
    var recentSessions: [WorkoutSession]
    var streakWeeks: Int
    var lastSessionDate: Date?
    var isWelcomeBack: Bool
    var recommendation: TodayRecommendation = .normalDefault
    var rampPreview: [UUID: RampDecision] = [:]
}
```

Replace with:

```swift
struct StalledExercise: Equatable {
    let programExercise: ProgramExercise
    let exerciseName: String
    let weight: Double
}

struct TodayData {
    var activeProgram: Program?
    var nextDay: ProgramDay?
    var recentSessions: [WorkoutSession]
    var streakWeeks: Int
    var lastSessionDate: Date?
    var isWelcomeBack: Bool
    var recommendation: TodayRecommendation = .normalDefault
    var rampPreview: [UUID: RampDecision] = [:]
    var trainingPhase: TrainingPhase? = nil
    var stalledExercise: StalledExercise? = nil
}
```

- [ ] **Step 2: Extend the initializer with new dependencies**

Find:

```swift
    private let programRepository: ProgramRepositoryProviding
    private let workoutRepository: WorkoutRepositoryProviding
    private let streakService = StreakService()
    private let engine: NextBestSessionEngine
    private let analytics: AnalyticsTracking

    /// Per-session set fetches are budgeted: only when a gap candidate exists, and
    /// only for post-gap sessions plus this many recent pre-gap sessions (baseline window).
    private static let baselineSessionWindow = 10

    init(
        programRepository: ProgramRepositoryProviding? = nil,
        workoutRepository: WorkoutRepositoryProviding? = nil,
        engine: NextBestSessionEngine = NextBestSessionEngine(),
        analytics: AnalyticsTracking? = nil
    ) {
        self.programRepository = programRepository ?? ProgramRepository()
        self.workoutRepository = workoutRepository ?? WorkoutRepository()
        self.engine = engine
        self.analytics = analytics ?? AnalyticsProvider.makeDefault()
    }
```

Replace with:

```swift
    private let programRepository: ProgramRepositoryProviding
    private let workoutRepository: WorkoutRepositoryProviding
    private let exerciseRepository: ExerciseRepositoryProviding
    private let profileRepository: ProfileRepositoryProviding
    private let streakService = StreakService()
    private let engine: NextBestSessionEngine
    private let analytics: AnalyticsTracking
    private let overloadSnoozeStore: OverloadAdvisorSnoozing

    /// Per-session set fetches are budgeted: only when a gap candidate exists, and
    /// only for post-gap sessions plus this many recent pre-gap sessions (baseline window).
    private static let baselineSessionWindow = 10

    init(
        programRepository: ProgramRepositoryProviding? = nil,
        workoutRepository: WorkoutRepositoryProviding? = nil,
        exerciseRepository: ExerciseRepositoryProviding? = nil,
        profileRepository: ProfileRepositoryProviding? = nil,
        engine: NextBestSessionEngine = NextBestSessionEngine(),
        analytics: AnalyticsTracking? = nil,
        overloadSnoozeStore: OverloadAdvisorSnoozing? = nil
    ) {
        self.programRepository = programRepository ?? ProgramRepository()
        self.workoutRepository = workoutRepository ?? WorkoutRepository()
        self.exerciseRepository = exerciseRepository ?? ExerciseRepository()
        self.profileRepository = profileRepository ?? ProfileRepository()
        self.engine = engine
        self.analytics = analytics ?? AnalyticsProvider.makeDefault()
        self.overloadSnoozeStore = overloadSnoozeStore ?? OverloadAdvisorSnoozeStore()
    }
```

- [ ] **Step 3: Wire stall detection and training phase into `fetch()`**

Find:

```swift
    private func fetch() async {
        do {
            async let fetchedProgram = programRepository.fetchActive()
            async let fetchedHistory = workoutRepository.fetchHistory(limit: 50)
            let (activeProgram, allSessions) = try await (fetchedProgram, fetchedHistory)

            let completed = allSessions.filter(\.isComplete).sorted { $0.startedAt > $1.startedAt }
            let streakWeeks = streakService.streak(from: completed)
            let lastSessionDate = completed.first?.startedAt

            let now = Date.now
            let sets = await fetchBudgetedSets(for: completed, now: now)
            let recommendation = engine.recommend(program: activeProgram, history: completed, sets: sets, now: now)

            let isWelcomeBack: Bool
            if let lastDate = lastSessionDate {
                isWelcomeBack = now.timeIntervalSince(lastDate) >= 7 * 24 * 3600
            } else {
                isWelcomeBack = activeProgram != nil
            }

            state = .success(TodayData(
                activeProgram: activeProgram,
                nextDay: recommendation.programDay,
                recentSessions: completed,
                streakWeeks: streakWeeks,
                lastSessionDate: lastSessionDate,
                isWelcomeBack: isWelcomeBack,
                recommendation: recommendation,
                rampPreview: recommendation.rampPreview
            ))
        } catch {
            let appError = ErrorMapper.map(error, context: .init(operation: "loadToday"))
            if appError != .cancelled {
                state = .error(appError)
            }
        }
    }
```

Replace with:

```swift
    private func fetch() async {
        do {
            async let fetchedProgram = programRepository.fetchActive()
            async let fetchedHistory = workoutRepository.fetchHistory(limit: 50)
            let (activeProgram, allSessions) = try await (fetchedProgram, fetchedHistory)

            let completed = allSessions.filter(\.isComplete).sorted { $0.startedAt > $1.startedAt }
            let streakWeeks = streakService.streak(from: completed)
            let lastSessionDate = completed.first?.startedAt

            let now = Date.now
            let sets = await fetchBudgetedSets(for: completed, now: now)
            let recommendation = engine.recommend(program: activeProgram, history: completed, sets: sets, now: now)
            let trainingPhase = await fetchTrainingPhase()
            let stalledExercise = recommendation.mode.isComeback
                ? nil
                : await findStalledExercise(
                    in: recommendation.programDay,
                    completed: completed,
                    sets: sets,
                    trainingPhase: trainingPhase,
                    now: now
                )

            let isWelcomeBack: Bool
            if let lastDate = lastSessionDate {
                isWelcomeBack = now.timeIntervalSince(lastDate) >= 7 * 24 * 3600
            } else {
                isWelcomeBack = activeProgram != nil
            }

            state = .success(TodayData(
                activeProgram: activeProgram,
                nextDay: recommendation.programDay,
                recentSessions: completed,
                streakWeeks: streakWeeks,
                lastSessionDate: lastSessionDate,
                isWelcomeBack: isWelcomeBack,
                recommendation: recommendation,
                rampPreview: recommendation.rampPreview,
                trainingPhase: trainingPhase,
                stalledExercise: stalledExercise
            ))
        } catch {
            let appError = ErrorMapper.map(error, context: .init(operation: "loadToday"))
            if appError != .cancelled {
                state = .error(appError)
            }
        }
    }
```

- [ ] **Step 4: Extend `fetchBudgetedSets`'s budget and add the new private helpers + public actions**

Find:

```swift
    private func fetchBudgetedSets(for completed: [WorkoutSession], now: Date) async -> [UUID: [WorkoutSet]] {
        guard NextBestSessionEngine.hasGapCandidate(history: completed, now: now) else { return [:] }

        var sets: [UUID: [WorkoutSet]] = [:]
        for session in completed.prefix(Self.baselineSessionWindow + NextBestSessionEngine.boundedExitSessionCount) {
            do {
                sets[session.id] = try await workoutRepository.fetchSets(sessionId: session.id)
            } catch {
                // A failed set fetch degrades the recommendation, not the screen.
                break
            }
        }
        return sets
    }
}
```

Replace with:

```swift
    private func fetchBudgetedSets(for completed: [WorkoutSession], now: Date) async -> [UUID: [WorkoutSet]] {
        guard completed.isEmpty == false else { return [:] }
        let sessionBudget = NextBestSessionEngine.hasGapCandidate(history: completed, now: now)
            ? Self.baselineSessionWindow + NextBestSessionEngine.boundedExitSessionCount
            : StallDetector.sessionThreshold

        var sets: [UUID: [WorkoutSet]] = [:]
        for session in completed.prefix(sessionBudget) {
            do {
                sets[session.id] = try await workoutRepository.fetchSets(sessionId: session.id)
            } catch {
                // A failed set fetch degrades the recommendation, not the screen.
                break
            }
        }
        return sets
    }

    private func fetchTrainingPhase() async -> TrainingPhase? {
        (try? await profileRepository.fetchCurrentProfile())?.trainingPhase
    }

    private func findStalledExercise(
        in day: ProgramDay?,
        completed: [WorkoutSession],
        sets: [UUID: [WorkoutSet]],
        trainingPhase: TrainingPhase?,
        now: Date
    ) async -> StalledExercise? {
        guard trainingPhase != .cut, trainingPhase != .maintain else { return nil }
        guard let day, day.exercises.isEmpty == false else { return nil }

        let exercises = (try? await exerciseRepository.fetchAll()) ?? []
        let exercisesById = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        let detector = StallDetector()

        for programExercise in day.exercises.sorted(by: { $0.exerciseOrder < $1.exerciseOrder }) {
            guard overloadSnoozeStore.isSnoozed(programExerciseId: programExercise.id, now: now) == false else { continue }
            guard detector.isStalled(
                exerciseId: programExercise.exerciseId,
                recentSessions: completed,
                sets: sets
            ) else { continue }
            guard let weight = Self.topWeight(forExerciseId: programExercise.exerciseId, sessions: completed, sets: sets) else {
                continue
            }
            let name = exercisesById[programExercise.exerciseId]?.displayName
                ?? String(localized: "workout.exercise.unknownExercise")
            return StalledExercise(programExercise: programExercise, exerciseName: name, weight: weight)
        }
        return nil
    }

    private static func topWeight(forExerciseId exerciseId: UUID, sessions: [WorkoutSession], sets: [UUID: [WorkoutSet]]) -> Double? {
        for session in sessions {
            if let weight = (sets[session.id] ?? []).filter({ $0.exerciseId == exerciseId }).map(\.weight).max() {
                return weight
            }
        }
        return nil
    }

    func tryOverloadSuggestion(_ stalled: StalledExercise) async {
        var updated = stalled.programExercise
        updated.targetWeight = stalled.weight + ProgressiveOverloadEngine.weightIncrementKg
        do {
            _ = try await programRepository.updateProgramExercise(updated)
            clearStalledExercise()
        } catch {
            let appError = ErrorMapper.map(error, context: .init(operation: "applyOverloadSuggestion"))
            if appError != .cancelled {
                transientError = appError
            }
        }
    }

    func snoozeOverloadSuggestion(_ stalled: StalledExercise) {
        overloadSnoozeStore.snooze(programExerciseId: stalled.programExercise.id, now: .now)
        clearStalledExercise()
    }

    private func clearStalledExercise() {
        guard case .success(var data) = state else { return }
        data.stalledExercise = nil
        state = .success(data)
    }
}
```

- [ ] **Step 5: Add test fakes to `TodayViewModelTests.swift`**

In `GymbrosTests/TodayViewModelTests.swift`, find:

```swift
    func createProgramExercise(dayId: UUID, exerciseId: UUID, targetSets: Int, targetRepsMin: Int, targetRepsMax: Int, targetRestSeconds: Int, targetWeight: Double?, order: Int, notes: String?) async throws -> ProgramExercise { throw AppError.notFound }
    func updateProgramExercise(_ programExercise: ProgramExercise) async throws -> ProgramExercise { throw AppError.notFound }
    func deleteProgramExercise(id: UUID) async throws {}
    func reorderProgramExercises(_ exercises: [ProgramExercise]) async throws {}
}
```

Replace with:

```swift
    func createProgramExercise(dayId: UUID, exerciseId: UUID, targetSets: Int, targetRepsMin: Int, targetRepsMax: Int, targetRestSeconds: Int, targetWeight: Double?, order: Int, notes: String?) async throws -> ProgramExercise { throw AppError.notFound }

    var updatedProgramExercise: ProgramExercise?
    func updateProgramExercise(_ programExercise: ProgramExercise) async throws -> ProgramExercise {
        updatedProgramExercise = programExercise
        return programExercise
    }
    func deleteProgramExercise(id: UUID) async throws {}
    func reorderProgramExercises(_ exercises: [ProgramExercise]) async throws {}
}

@MainActor
private final class FakeTodayProfileRepository: ProfileRepositoryProviding {
    var profile: Profile?
    func fetchCurrentProfile() async throws -> Profile {
        guard let profile else { throw AppError.notFound }
        return profile
    }
    func updateProfile(_ profile: Profile) async throws {}
}

@MainActor
private final class FakeTodayExerciseRepository: ExerciseRepositoryProviding {
    var exercises: [Exercise] = []
    func fetchAll() async throws -> [Exercise] { exercises }
}

@MainActor
private final class FakeOverloadSnoozeStore: OverloadAdvisorSnoozing {
    var snoozed: Set<UUID> = []
    func isSnoozed(programExerciseId: UUID, now: Date) -> Bool { snoozed.contains(programExerciseId) }
    func snooze(programExerciseId: UUID, now: Date) { snoozed.insert(programExerciseId) }
}
```

- [ ] **Step 6: Add the failing tests**

In the same file, find:

```swift
    // MARK: - Error handling

    @Test func repositoryError_stateIsError() async {
```

Replace with:

```swift
    // MARK: - Progressive Overload Advisor

    private func makeExercise() -> Exercise {
        Exercise(
            id: TodaySamples.exerciseId,
            ownerUserId: nil,
            slug: "bench_press",
            name: "Bench Press",
            movementPattern: .push,
            primaryMuscle: .chest,
            secondaryMuscles: [],
            equipment: .barbell,
            isCompound: true,
            createdAt: TodaySamples.baseDate
        )
    }

    private func makeTodayProfile(trainingPhase: TrainingPhase?) -> Profile {
        Profile(
            id: TodaySamples.userId,
            email: nil,
            name: nil,
            experienceLevel: nil,
            goal: nil,
            trainingPhase: trainingPhase,
            daysPerWeek: nil,
            weightUnit: .kg,
            locale: "en",
            createdAt: TodaySamples.baseDate,
            updatedAt: TodaySamples.baseDate
        )
    }

    @Test func stalledExerciseAppearsInNormalModeAfterFourSessions() async throws {
        let program = makeTodayProgram(withExercises: true)
        // Last session on day2 so nextDay wraps to day1, which owns the exercise.
        let sessions = [1, 3, 5, 7].map { makeSession(programDayId: TodaySamples.day2Id, daysAgo: Double($0)) }
        let workoutRepo = FakeTodayWorkoutRepository(history: sessions)
        for session in sessions {
            workoutRepo.setsBySessionId[session.id] = [makeSet(sessionId: session.id, weight: 80, reps: 8, rpe: 7.0)]
        }
        let exerciseRepo = FakeTodayExerciseRepository()
        exerciseRepo.exercises = [makeExercise()]
        let vm = TodayViewModel(
            programRepository: FakeTodayProgramRepository(active: program),
            workoutRepository: workoutRepo,
            exerciseRepository: exerciseRepo,
            overloadSnoozeStore: FakeOverloadSnoozeStore()
        )

        await vm.load()

        let data = try successValue(vm.state)
        #expect(data.recommendation.mode == .normal)
        let stalled = try #require(data.stalledExercise)
        #expect(stalled.programExercise.id == TodaySamples.programExerciseId)
        #expect(stalled.exerciseName == "Bench Press")
        #expect(stalled.weight == 80)
    }

    @Test func stalledExerciseSuppressedWhenTrainingPhaseIsCut() async throws {
        let program = makeTodayProgram(withExercises: true)
        let sessions = [1, 3, 5, 7].map { makeSession(programDayId: TodaySamples.day2Id, daysAgo: Double($0)) }
        let workoutRepo = FakeTodayWorkoutRepository(history: sessions)
        for session in sessions {
            workoutRepo.setsBySessionId[session.id] = [makeSet(sessionId: session.id, weight: 80, reps: 8, rpe: 7.0)]
        }
        let exerciseRepo = FakeTodayExerciseRepository()
        exerciseRepo.exercises = [makeExercise()]
        let profileRepo = FakeTodayProfileRepository()
        profileRepo.profile = makeTodayProfile(trainingPhase: .cut)
        let vm = TodayViewModel(
            programRepository: FakeTodayProgramRepository(active: program),
            workoutRepository: workoutRepo,
            exerciseRepository: exerciseRepo,
            profileRepository: profileRepo,
            overloadSnoozeStore: FakeOverloadSnoozeStore()
        )

        await vm.load()

        let data = try successValue(vm.state)
        #expect(data.trainingPhase == .cut)
        #expect(data.stalledExercise == nil)
    }

    @Test func stalledExerciseNeverShownAlongsideComebackMode() async throws {
        let program = makeTodayProgram(withExercises: true)
        // All 4 sessions are >=14 days old and identical weight: would be a stall in
        // normal mode, but the whole history being that old also triggers comeback.
        let sessions = [20, 22, 24, 26].map { makeSession(programDayId: TodaySamples.day1Id, daysAgo: Double($0)) }
        let workoutRepo = FakeTodayWorkoutRepository(history: sessions)
        for session in sessions {
            workoutRepo.setsBySessionId[session.id] = [makeSet(sessionId: session.id, weight: 80, reps: 8, rpe: 7.0)]
        }
        let vm = TodayViewModel(
            programRepository: FakeTodayProgramRepository(active: program),
            workoutRepository: workoutRepo
        )

        await vm.load()

        let data = try successValue(vm.state)
        #expect(data.recommendation.mode.isComeback)
        #expect(data.stalledExercise == nil)
    }

    @Test func tryOverloadSuggestionUpdatesTargetWeightAndClearsCard() async throws {
        let program = makeTodayProgram(withExercises: true)
        let sessions = [1, 3, 5, 7].map { makeSession(programDayId: TodaySamples.day2Id, daysAgo: Double($0)) }
        let workoutRepo = FakeTodayWorkoutRepository(history: sessions)
        for session in sessions {
            workoutRepo.setsBySessionId[session.id] = [makeSet(sessionId: session.id, weight: 80, reps: 8, rpe: 7.0)]
        }
        let exerciseRepo = FakeTodayExerciseRepository()
        exerciseRepo.exercises = [makeExercise()]
        let programRepo = FakeTodayProgramRepository(active: program)
        let vm = TodayViewModel(
            programRepository: programRepo,
            workoutRepository: workoutRepo,
            exerciseRepository: exerciseRepo,
            overloadSnoozeStore: FakeOverloadSnoozeStore()
        )

        await vm.load()
        let stalled = try #require(try successValue(vm.state).stalledExercise)
        await vm.tryOverloadSuggestion(stalled)

        #expect(programRepo.updatedProgramExercise?.targetWeight == 82.5)
        #expect(try successValue(vm.state).stalledExercise == nil)
    }

    @Test func snoozeOverloadSuggestionHidesCardAndPersists() async throws {
        let program = makeTodayProgram(withExercises: true)
        let sessions = [1, 3, 5, 7].map { makeSession(programDayId: TodaySamples.day2Id, daysAgo: Double($0)) }
        let workoutRepo = FakeTodayWorkoutRepository(history: sessions)
        for session in sessions {
            workoutRepo.setsBySessionId[session.id] = [makeSet(sessionId: session.id, weight: 80, reps: 8, rpe: 7.0)]
        }
        let exerciseRepo = FakeTodayExerciseRepository()
        exerciseRepo.exercises = [makeExercise()]
        let snoozeStore = FakeOverloadSnoozeStore()
        let vm = TodayViewModel(
            programRepository: FakeTodayProgramRepository(active: program),
            workoutRepository: workoutRepo,
            exerciseRepository: exerciseRepo,
            overloadSnoozeStore: snoozeStore
        )

        await vm.load()
        let stalled = try #require(try successValue(vm.state).stalledExercise)
        vm.snoozeOverloadSuggestion(stalled)

        #expect(try successValue(vm.state).stalledExercise == nil)
        #expect(snoozeStore.snoozed.contains(TodaySamples.programExerciseId))
    }

    // MARK: - Error handling

    @Test func repositoryError_stateIsError() async {
```

- [ ] **Step 7: Run tests to verify they pass**

```bash
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:GymbrosTests/TodayViewModelTests
```

Expected: `** TEST SUCCEEDED **`, all tests including the 5 new ones pass.

- [ ] **Step 8: Full build**

```bash
xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 9: Commit**

```bash
git add Gymbros/Presentation/Today/TodayViewModel.swift GymbrosTests/TodayViewModelTests.swift
git commit -m "$(cat <<'EOF'
feat: wire StallDetector and training-phase gating into TodayViewModel

TodayData gains stalledExercise/trainingPhase; fetch() now also
fetches sets on normal days (bounded to StallDetector.sessionThreshold
sessions, not the full comeback budget) since the detector needs
recent data regardless of gap status. Stall check is only attempted
in normal mode, scoped to today's recommended day, and skips any
programExerciseId currently snoozed. tryOverloadSuggestion(_:) reuses
ProgressiveOverloadEngine.weightIncrementKg and the existing
updateProgramExercise pre-fill mechanism; snoozeOverloadSuggestion(_:)
writes to the new local-only snooze store. Both clear the card from
state immediately without a full refetch.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 17: `TodayView` wiring for the Overload Advisor card

**Files:**
- Modify: `Gymbros/Presentation/Today/TodayView.swift`

**Interfaces:**
- Consumes: `TodayData.stalledExercise`, `TodayViewModel.tryOverloadSuggestion(_:)`, `TodayViewModel.snoozeOverloadSuggestion(_:)` from Task 16; `OverloadAdvisorCardView` from Task 15.
- Produces: nothing — this is the final, user-visible piece of the Progressive Overload Advisor.

- [ ] **Step 1: Render the card in `successState`**

In `Gymbros/Presentation/Today/TodayView.swift`, find:

```swift
                        if data.recommendation.mode.isComeback {
                            comebackCard(data: data, nextDay: displayedDay)
                        } else {
                            nextWorkoutCard(data: data, nextDay: displayedDay)
                        }
                    }
```

Replace with:

```swift
                        if data.recommendation.mode.isComeback {
                            comebackCard(data: data, nextDay: displayedDay)
                        } else {
                            nextWorkoutCard(data: data, nextDay: displayedDay)
                            if let stalled = data.stalledExercise {
                                overloadAdvisorCard(stalled)
                            }
                        }
                    }
```

- [ ] **Step 2: Add the `overloadAdvisorCard(_:)` helper**

Find:

```swift
            .buttonStyle(.borderedProminent)
            .accessibilityLabel(Text("accessibility.today.start \(nextDay.name)"))
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func streakBadge(weeks: Int) -> some View {
```

Replace with:

```swift
            .buttonStyle(.borderedProminent)
            .accessibilityLabel(Text("accessibility.today.start \(nextDay.name)"))
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func overloadAdvisorCard(_ stalled: StalledExercise) -> some View {
        OverloadAdvisorCardView(
            exerciseName: stalled.exerciseName,
            weightText: appPreferences.weightUnit.formattedKilograms(stalled.weight),
            weightUnitAbbreviation: appPreferences.weightUnit.localizedAbbreviation,
            onTryNextTime: {
                Task { await viewModel.tryOverloadSuggestion(stalled) }
            },
            onNotNow: {
                viewModel.snoozeOverloadSuggestion(stalled)
            }
        )
    }

    private func streakBadge(weeks: Int) -> some View {
```

(`@Environment(AppPreferences.self) private var appPreferences` was already added to `TodayView` in Task 7, Step 3.)

- [ ] **Step 3: Build to verify it compiles**

```bash
xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Manual smoke test**

1. Log the same weight for an exercise across 4 sessions at RPE ≤8.0. Confirm `OverloadAdvisorCardView` appears below the next-workout card on Today (normal mode only — confirm it never appears alongside the comeback card).
2. In Settings, set training phase to "Losing weight." Confirm the card disappears on the next Today load for that exercise.
3. Set training phase back to "Building muscle" (or clear it). Confirm the card reappears.
4. Tap "Not now." Confirm the card disappears immediately and stays hidden across a relaunch (for 14 days).
5. On a fresh, unsnoozed stall, tap "Try it next time." Confirm the card disappears immediately and the program exercise's target weight increased by 2.5kg (check via Program Builder or the next session's pre-filled set 1 weight).
6. Run in both Thai and English device locales; verify the card's copy renders correctly in both.

- [ ] **Step 5: Commit**

```bash
git add Gymbros/Presentation/Today/TodayView.swift
git commit -m "$(cat <<'EOF'
feat: surface OverloadAdvisorCardView on Today

Shown only in normal mode (never alongside the comeback card, since
TodayData.stalledExercise is only ever populated in that branch of
TodayViewModel.fetch()), one exercise at a time, scoped to today's
recommended day.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

# PART 5 — SUBSTITUTE (MID-WORKOUT EXERCISE SWAP)

> Design: `docs/superpowers/specs/2026-07-24-exercise-substitution-design.md`.
> Approved 2026-07-24, resuming the 2026-07-23 outline. Independent of Parts 1-4 —
> touches `WorkoutSessionViewModel`/`WorkoutExercisePageView`, not `TodayView`/`Settings`.

### Task 18: `SubstituteRanker` pure service + tests

**Files:**
- Create: `Gymbros/Data/Services/SubstituteRanker.swift`
- Create: `GymbrosTests/SubstituteRankerTests.swift`

**Interfaces:**
- Consumes: `Exercise` (existing model).
- Produces: `SubstituteCandidate`, `SubstituteRanker.filter(original:library:)`,
  `SubstituteRanker.rank(original:candidates:lastLoggedWeightsKg:)` — consumed by Task 20.

- [x] **Step 1: Write the failing tests**

Cover: `filter` excludes the original exercise by id; excludes exercises with a
different `movementPattern` or `primaryMuscle`; includes exercises matching both.
`rank` orders different-equipment-from-original ahead of same-equipment; within an
equipment tier, has-history (`lastLoggedWeightsKg[id] != nil`) ranks ahead of
no-history; final tie-break is alphabetical by name. Empty `library`/`candidates`
returns `[]` without crashing.

- [x] **Step 2: Run tests to verify they fail to build**

- [x] **Step 3: Implement `SubstituteRanker`**

```swift
import Foundation

struct SubstituteCandidate: Identifiable, Equatable {
    var id: UUID { exercise.id }
    let exercise: Exercise
    let lastLoggedWeightKg: Double?
}

enum SubstituteRanker {
    static let minimumRankedResultsBeforeBrowseAllFallback = 3

    static func filter(original: Exercise, library: [Exercise]) -> [Exercise] {
        library.filter {
            $0.id != original.id
                && $0.movementPattern == original.movementPattern
                && $0.primaryMuscle == original.primaryMuscle
        }
    }

    static func rank(
        original: Exercise,
        candidates: [Exercise],
        lastLoggedWeightsKg: [UUID: Double]
    ) -> [SubstituteCandidate] {
        candidates
            .map { SubstituteCandidate(exercise: $0, lastLoggedWeightKg: lastLoggedWeightsKg[$0.id]) }
            .sorted { lhs, rhs in
                let lhsDifferentEquipment = lhs.exercise.equipment != original.equipment
                let rhsDifferentEquipment = rhs.exercise.equipment != original.equipment
                if lhsDifferentEquipment != rhsDifferentEquipment {
                    return lhsDifferentEquipment
                }
                let lhsHasHistory = lhs.lastLoggedWeightKg != nil
                let rhsHasHistory = rhs.lastLoggedWeightKg != nil
                if lhsHasHistory != rhsHasHistory {
                    return lhsHasHistory
                }
                return lhs.exercise.name < rhs.exercise.name
            }
    }
}
```

- [x] **Step 4: Run tests to verify they pass**
- [ ] **Step 5: Commit**

---

### Task 19: Substitute localization

**Files:**
- Modify: `Gymbros/Resources/Localizable.xcstrings`

**Interfaces:**
- Produces the keys listed in spec.md §7's Localization table:
  `workout.substitute.button`, `workout.substitute.sheet.title`,
  `workout.substitute.sheet.lastWeight`, `workout.substitute.sheet.browseAll`,
  `workout.substitute.sheet.empty`, `workout.substitute.badge`,
  `accessibility.workout.substitute_button`, `accessibility.workout.substitute_badge`
  — consumed by Tasks 21-23.

- [x] **Step 1: Add the `workout.substitute.*` and `accessibility.workout.substitute_*`
  cluster to `Localizable.xcstrings`, both `en` and `th`, per spec.md §7's table**
- [x] **Step 2: Validate JSON** — `jq empty Gymbros/Resources/Localizable.xcstrings`
- [ ] **Step 3: Commit**

---

### Task 20: `WorkoutSessionViewModel` substitute flow

**Files:**
- Modify: `Gymbros/Presentation/Workout/WorkoutSessionState.swift`
  (`WorkoutSetRowState.exerciseId`: `let` → `var`)
- Modify: `Gymbros/Presentation/Workout/WorkoutSessionViewModel.swift`
- Modify: `Gymbros/Data/Services/Analytics/AnalyticsTracking.swift`
  (add `.exerciseSubstituted`, `.substituteRankSelected` cases)
- Modify: `GymbrosTests/WorkoutSessionViewModelTests.swift`

**Interfaces:**
- Consumes: `SubstituteRanker` (Task 18), existing `workoutRepository.fetchLastLoggedSet`,
  existing `formatWeight(_:)`.
- Produces: `SubstitutePrompt`, `var substitutePrompt: SubstitutePrompt?`,
  `presentSubstituteOptions(programExerciseId:) async`, `selectSubstitute(_:) async` —
  consumed by Task 23's `WorkoutSessionScreen` wiring.

- [x] **Step 1: Write the failing tests**

Cover: `presentSubstituteOptions` builds `substitutePrompt` with correctly ranked
candidates and the right `showsBrowseAllFallback` value at the 3-result boundary (2 →
true, 3 → false); `selectSubstitute` reassigns `exerciseId` and clears/reformats
`weightText` on every not-yet-completed row while leaving completed rows' `exerciseId`/
`weightText`/`reps` untouched; `section.exercise` and `section.defaultWeight` update;
`addSet(after:)` called after a swap tags the new row with the substitute's
`exerciseId`; `.exerciseSubstituted` and `.substituteRankSelected` are tracked via a
fake `AnalyticsTracking`; backup is saved (existing `saveBackup()` call pattern).

- [x] **Step 2: Run tests to verify they fail to build**

- [x] **Step 3: Relax `WorkoutSetRowState.exerciseId` to `var`**

In `WorkoutSessionState.swift`, change `let exerciseId: UUID` to `var exerciseId: UUID`
on `WorkoutSetRowState`. No other field changes.

- [x] **Step 4: Add `.exerciseSubstituted` / `.substituteRankSelected` to `AnalyticsEvent`**

Two more no-payload cases, matching every existing case in the enum.

- [x] **Step 5: Add `SubstitutePrompt` and the two view-model methods**

```swift
struct SubstitutePrompt: Identifiable {
    let id = UUID()
    let programExerciseId: UUID
    let originalExercise: Exercise
    let candidates: [SubstituteCandidate]
    let showsBrowseAllFallback: Bool
}
```

`var substitutePrompt: SubstitutePrompt?` as a new `@Observable` property, alongside
`overloadOutcomePrompt`.

```swift
func presentSubstituteOptions(programExerciseId: UUID) async {
    guard case let .success(data) = state,
          let section = data.exerciseSections.first(where: { $0.programExercise.id == programExerciseId }),
          let activeExercise = section.exercise else {
        transientError = .notFound
        return
    }
    let library = Array(data.exerciseLookup.values)
    let filtered = SubstituteRanker.filter(original: activeExercise, library: library)

    var lastLoggedWeights: [UUID: Double] = [:]
    for candidate in filtered {
        if let lastSet = try? await workoutRepository.fetchLastLoggedSet(exerciseId: candidate.id, before: now()) {
            lastLoggedWeights[candidate.id] = lastSet.weight
        }
    }

    substitutePrompt = SubstitutePrompt(
        programExerciseId: programExerciseId,
        originalExercise: activeExercise,
        candidates: SubstituteRanker.rank(original: activeExercise, candidates: filtered, lastLoggedWeightsKg: lastLoggedWeights),
        showsBrowseAllFallback: filtered.count < SubstituteRanker.minimumRankedResultsBeforeBrowseAllFallback
    )
}

func selectSubstitute(_ exercise: Exercise) async {
    guard let prompt = substitutePrompt,
          case var .success(data) = state,
          let sectionIndex = data.exerciseSections.firstIndex(where: { $0.programExercise.id == prompt.programExerciseId }) else {
        substitutePrompt = nil
        return
    }

    let lastSet = try? await workoutRepository.fetchLastLoggedSet(exerciseId: exercise.id, before: now())
    let suggestedWeight = lastSet?.weight

    data.exerciseSections[sectionIndex].exercise = exercise
    data.exerciseSections[sectionIndex].defaultWeight = suggestedWeight
    for index in data.exerciseSections[sectionIndex].sets.indices
    where data.exerciseSections[sectionIndex].sets[index].isCompleted == false {
        data.exerciseSections[sectionIndex].sets[index].exerciseId = exercise.id
        data.exerciseSections[sectionIndex].sets[index].weightText = formatWeight(suggestedWeight)
    }
    state = .success(data)
    substitutePrompt = nil

    analytics.track(.exerciseSubstituted)
    analytics.track(.substituteRankSelected)

    await updateWorkoutLiveActivity()
    saveBackup()
}
```

- [x] **Step 6: Fix `addSet(after:)` to use the section's active exercise**

Change the hardcoded `exerciseId: data.exerciseSections[sectionIndex].programExercise.exerciseId`
to `exerciseId: data.exerciseSections[sectionIndex].exercise?.id ?? data.exerciseSections[sectionIndex].programExercise.exerciseId`.

- [x] **Step 7: Run tests to verify they pass**
- [ ] **Step 8: Commit**

---

### Task 21: `SubstituteOriginBadge` component

**Files:**
- Create: `Gymbros/Presentation/Workout/Components/SubstituteOriginBadge.swift`

**Interfaces:**
- Consumes: an exercise name `String`.
- Produces: a view consumed by Task 23.

- [x] **Step 1: Create the badge**, same visual family as `EasingBackBadge`/
  `OverloadSuggestionBadge` (capsule, `.caption.weight(.semibold)`,
  `arrow.uturn.left` icon, `Color(uiColor: .tertiarySystemFill)` background,
  `.secondary` foreground), showing `workout.substitute.badge` formatted with the
  origin exercise name, with `accessibility.workout.substitute_badge` as its
  accessibility label.
- [x] **Step 2: Build to verify it compiles**
- [ ] **Step 3: Commit**

---

### Task 22: `SubstituteCandidateSheet` component

**Files:**
- Create: `Gymbros/Presentation/Workout/Components/SubstituteCandidateSheet.swift`

**Interfaces:**
- Consumes: `SubstitutePrompt` (Task 20), `WeightUnit` (existing), `ExercisePickerView`/
  `ExercisePickerViewModel` (existing, unmodified), `EquipmentIconView` (existing).
- Produces: a view consumed by Task 23. `onSelect: (Exercise) -> Void` closure.

- [x] **Step 1: Create the sheet**

Medium-detent sheet (mirrors `FeelPickerSheet`'s chrome: Cancel toolbar action,
`.presentationDetents([.medium])`). Body: `workout.substitute.sheet.title` header,
then a `List` of `prompt.candidates` rows (`EquipmentIconView` + exercise name +
`workout.substitute.sheet.lastWeight` formatted with the unit-converted weight when
`lastLoggedWeightKg != nil`), each row calling `onSelect` and dismissing on tap. Empty
candidates show `workout.substitute.sheet.empty`. When `prompt.showsBrowseAllFallback`
is true, a trailing row/button labeled `workout.substitute.sheet.browseAll` sets
`@State private var showingBrowseAll = true`, presenting `ExercisePickerView` as a
nested sheet with the same `onSelect` closure.

- [x] **Step 2: Build to verify it compiles**
- [ ] **Step 3: Commit**

---

### Task 23: Wire the Swap button, origin badges, and sheet presentation

**Files:**
- Modify: `Gymbros/Presentation/Workout/WorkoutExercisePageView.swift`
- Modify: `Gymbros/Presentation/Workout/WorkoutSessionView.swift`
- Modify: `Gymbros/Presentation/Workout/WorkoutSessionScreen.swift`

**Interfaces:**
- Consumes: `onSwapExercise: (UUID) -> Void` action closure threaded through
  `WorkoutSessionScreen` → `WorkoutSessionView` → `WorkoutExercisePageView`, same
  pattern as `onFinishExercise`. `viewModel.substitutePrompt` / `selectSubstitute(_:)`
  (Task 20).

- [x] **Step 1: `WorkoutExercisePageView.exerciseHeader`** — add a "Swap exercise"
  button (`arrow.triangle.2.circlepath` + `workout.substitute.button`,
  `accessibility.workout.substitute_button`), hidden when `section.isFinished`, calling
  a new `onSwapExercise: (UUID) -> Void` action with `section.programExercise.id`.
- [x] **Step 2: Set-row origin badges** — in the `ForEach(section.sets)` loop, render
  `SubstituteOriginBadge` above/alongside a row when
  `rowState.exerciseId != section.exercise?.id`, using
  `section.exerciseLookup`/passed-in lookup to resolve the origin exercise's name (thread
  the existing `exerciseLookup` dictionary down from `WorkoutSessionData`, same as
  `lastSessionReference` is already threaded per-section).
- [x] **Step 3: Thread `onSwapExercise` through `WorkoutSessionView`** — new action
  parameter, passed to each `WorkoutExercisePageView`.
- [x] **Step 4: `WorkoutSessionScreen`** — wire `onSwapExercise` to
  `Task { await viewModel.presentSubstituteOptions(programExerciseId: $0) }`; add
  `.sheet(item:)` bound to `viewModel.substitutePrompt` presenting
  `SubstituteCandidateSheet(prompt:, onSelect: { exercise in Task { await viewModel.selectSubstitute(exercise) } })`.
- [x] **Step 5: Build to verify it compiles**
- [ ] **Step 6: Manual smoke test** — mid-workout, swap an exercise with 3+ candidates;
  confirm the header updates, not-yet-completed sets get the new suggested weight, and
  completed sets are unchanged and show the origin badge. Re-swap. Force a <3-candidate
  exercise; confirm the browse-all fallback opens `ExercisePickerView`.
- [ ] **Step 7: Commit**

---

# PART 6 — FULL SPRINT VERIFICATION

### Task 25: Full verification pass + STANDUP/GYMTRACK updates

**Files:**
- Modify: `STANDUP.md`
- Modify: `.claude/GYMTRACK.md`

**Interfaces:**
- Consumes: the complete result of Tasks 1-24.
- Produces: nothing — this is the final gate before considering Sprint 6.1 done.

- [ ] **Step 1: Run the full test suite**

```bash
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: `** TEST SUCCEEDED **`. In particular, confirm `ComebackRampServiceTests` and `ProgressiveOverloadEngineTests` pass unmodified across all five features — proves zero downstream impact on the existing comeback/overload engines. Note: this machine has no `iPhone 17e` simulator installed (only `iPhone 17`/`17 Pro`/`17 Pro Max` — see STANDUP.md's 2026-07-24 environment note); use `iPhone 17` here even though earlier tasks in this plan reference `17e`.

- [ ] **Step 2: Run the full build**

```bash
xcodebuild -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Re-validate the string catalog and check for diff hygiene**

```bash
jq empty Gymbros/Resources/Localizable.xcstrings && echo "valid json"
git diff --check
```

Expected: `valid json`, no whitespace-conflict output from `git diff --check`.

- [ ] **Step 4: Run the combined manual smoke checklist**

Repeat the manual smoke steps from Task 6 (RPE), Task 7 Step 6 (Skip a Day), Task 11 Step 6 (Training Phase), Task 17 Step 4 (Progressive Overload Advisor), and Task 23 Step 6 (Substitute) in one sitting, in that order, using the same simulator session so all five features are confirmed to coexist without interfering with each other (e.g. confirm the "Change day" control and the Overload Advisor card can both appear on the same Today load; confirm switching training phase does not affect the RPE picker, Skip a Day, or Substitute; confirm swapping an exercise mid-workout doesn't disturb the rest timer or Live Activity).

- [ ] **Step 5: Update `.claude/GYMTRACK.md`**

Update the Sprint 6.1 row in §9's Sprint Tracking table and the `### Sprint 6.1 — Post-Launch Feature Wave` section: mark all five items (RPE, Skip a Day, Training Phase, Progressive Overload Advisor, Substitute) as fully complete once manual smoke passes.

- [ ] **Step 6: Update `STANDUP.md`**

Add a new entry under "Last session did" summarizing the Substitute feature (design +
implementation), the HEAD SHA, and the verification commands run. Update "Next up" to
reflect that Sprint 6.1 is fully complete and the next work is Sprint 7.

- [ ] **Step 7: Commit the documentation updates**

```bash
git add STANDUP.md .claude/GYMTRACK.md
git commit -m "$(cat <<'EOF'
docs: mark Sprint 6.1 post-launch feature wave complete

Substitute (mid-workout exercise swap) is now designed and implemented,
completing all 5 of Sprint 6.1's post-launch features.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```
