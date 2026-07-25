# RPE UX Simplification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the raw 1.0–10.0 decimal RPE menu (in both the live logger and the History edit-set form) with the existing friendly Easy / Just right / Hard scale, and remove the now-redundant comeback-mode feedback sheet it duplicates.

**Architecture:** No data model or algorithm changes. `HowDidThatFeel` (an existing pure enum) gains one static bucketing function and has its localization keys repointed; two SwiftUI `Menu` controls (`SetRowView`, `SessionDetailView`'s `EditSetSheet`) get their contents swapped from a 19-item numeric list to the same 3-option-plus-Clear list; the comeback-only feedback sheet and its supporting code are deleted since it becomes redundant once per-set input uses the same scale everywhere.

**Tech Stack:** Swift, SwiftUI, Swift Testing (`import Testing`, `@Test`, `#expect`), Xcode String Catalogs (`Localizable.xcstrings`, hand-edited JSON).

## Global Constraints

- Module name is `Gymbros` (not `GymBros`) — use `@testable import Gymbros` in all tests.
- Test framework is Swift Testing, not XCTest — `@Test func ...()`, `#expect(...)`, no `XCTestCase`.
- Build/test destination is always `platform=iOS Simulator,name=iPhone 17e` (not `iPhone 16`).
- Every user-visible string must have both `en` and `th` entries in `Localizable.xcstrings` — no hardcoded strings in views.
- Minimum tap target is 48pt — do not shrink any existing tappable area.
- Commit messages end with `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`; never use `git commit --amend` or `--no-verify`.
- Design spec: `docs/superpowers/specs/2026-07-22-rpe-ux-simplification-design.md` (read it first if anything below is ambiguous).

---

### Task 1: Localization — add `workout.set.feel*` and accessibility keys, remove old RPE keys

**Files:**
- Modify: `Gymbros/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: nothing (this is a data-only task).
- Produces: string catalog keys `workout.set.feel`, `workout.set.feel.clear`, `workout.set.feel.easy`, `workout.set.feel.hard`, `workout.set.feel.just_right`, `workout.set.header.feel`, `accessibility.workout.set.feel.prefix`, `accessibility.workout.set.feel.unset` — consumed by Tasks 2–4. Removes `workout.comeback.feel.easy`, `workout.comeback.feel.hard`, `workout.comeback.feel.just_right`, `workout.comeback.feel.skip`, `workout.comeback.feel.title`, `workout.set.header.rpe`, `workout.set.rpe`, `workout.set.rpe.clear`.

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
- Consumes: nothing from Tasks 1–4.
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

### Task 6: Full verification pass

**Files:** none (verification only).

**Interfaces:**
- Consumes: the complete result of Tasks 1–5.
- Produces: nothing — this is the final gate before considering the feature done.

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

- [ ] **Step 5: Update STANDUP.md**

Add an entry noting this feature is implemented, list the commits from Tasks 1–5, and mark the manual smoke test result (pass/fail) from Step 4 above, following the existing `STANDUP.md` format.
