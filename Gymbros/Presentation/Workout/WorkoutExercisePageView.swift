import SwiftUI

struct WorkoutExercisePageView: View {
    let section: WorkoutExerciseSection
    var exerciseLookup: [UUID: Exercise] = [:]
    var lastSessionReference: LastSessionReference?
    var isComebackMode: Bool = false
    var overloadHint: Double?
    @Environment(AppPreferences.self) private var appPreferences
    @State private var tableWidth: CGFloat = 0

    // Actions
    var onAddSet: (UUID) -> Void // setId
    var onUpdateSet: (UUID, String, String, Double?) -> Void // setId
    var onCompleteSet: (UUID) -> Void // setId
    var onDeleteSet: (UUID) -> Void // setId
    var onFinishExercise: (UUID) -> Void // programExerciseId
    var onSwapExercise: (UUID) -> Void = { _ in } // programExerciseId
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                exerciseHeader
                
                VStack(spacing: 0) {
                    let columns = setTableColumns

                    if showsEasingBackBadge {
                        EasingBackBadge()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    } else if showsOverloadSuggestionBadge {
                        OverloadSuggestionBadge()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    }

                    setTableHeader(columns: columns)

                    ForEach(section.sets) { rowState in
                        if rowState.exerciseId != section.exercise?.id,
                           let originName = exerciseLookup[rowState.exerciseId]?.name {
                            SubstituteOriginBadge(originExerciseName: originName)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 8)
                        }

                        SetRowView(
                            state: rowState,
                            isReadOnly: section.isFinished,
                            columns: columns,
                            onUpdate: { w, r, rpe in
                                onUpdateSet(rowState.id, w, r, rpe)
                            },
                            onComplete: {
                                onCompleteSet(rowState.id)
                            },
                            onDelete: {
                                onDeleteSet(rowState.id)
                            }
                        )

                        if rowState.id != section.sets.last?.id {
                            Divider()
                                .padding(.leading, 36)
                        }
                    }
                    
                    if !section.isFinished, let lastSetId = section.sets.last?.id {
                        Button(action: { onAddSet(lastSetId) }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("workout.set.add")
                            }
                            .font(.system(.subheadline, design: .rounded).bold())
                            .foregroundStyle(Color.accentColor)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                        }
                        .padding(.top, 8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                .padding(.vertical, 8)
                // Grouped-list surface: the set fields use .secondarySystemBackground,
                // which is invisible directly on .systemGroupedBackground. A white
                // section behind them restores contrast (and matches the header).
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: WorkoutSetTableWidthPreferenceKey.self,
                            value: proxy.size.width
                        )
                    }
                )
                .onPreferenceChange(WorkoutSetTableWidthPreferenceKey.self) { width in
                    tableWidth = width
                }
                
                footerAction
            }
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
        .background(Color(uiColor: .systemGroupedBackground))
    }
    
    private var exerciseHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(section.exercise?.name ?? String(localized: "workout.exercise.unknownExercise"))
                    .font(.system(.title2, design: .rounded).bold())
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                if !section.isFinished {
                    Button {
                        onSwapExercise(section.programExercise.id)
                    } label: {
                        Label("workout.substitute.button", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(.subheadline, design: .rounded).bold())
                            .labelStyle(.iconOnly)
                            .frame(width: 48, height: 48)
                    }
                    .accessibilityLabel(Text("accessibility.workout.substitute_button"))
                }
            }

            HStack(spacing: 12) {
                Label(
                    String(format: String(localized: "programExercise.setsFormat"), section.programExercise.targetSets),
                    systemImage: "list.bullet"
                )
                Label(
                    String(
                        format: String(localized: "programExercise.repsFormat"),
                        section.programExercise.targetRepsMin,
                        section.programExercise.targetRepsMax
                    ),
                    systemImage: "repeat"
                )
                Label(
                    String(format: String(localized: "programExercise.restFormat"), section.programExercise.targetRestSeconds),
                    systemImage: "timer"
                )
            }
            .font(.system(.caption, design: .rounded))
            .foregroundStyle(.secondary)
            
            if let targetWeight = section.programExercise.targetWeight {
                HStack {
                    Text("workout.exercise.target_weight")
                    Text(verbatim: appPreferences.weightUnit.formattedKilograms(targetWeight))
                        .fontWeight(.bold)
                    Text(verbatim: appPreferences.weightUnit.localizedAbbreviation)
                }
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.14), in: Capsule())
            }
            
            if let notes = section.programExercise.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            if isComebackMode == false, let overloadHint {
                Text(String(
                    format: String(localized: "workout.overload.hint"),
                    "\(appPreferences.weightUnit.formattedKilograms(overloadHint)) \(appPreferences.weightUnit.localizedAbbreviation)"
                ))
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
            }

            lastSessionReferenceRow
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }

    private var showsEasingBackBadge: Bool {
        isComebackMode && lastSessionReference?.label == .baseline
    }

    private var showsOverloadSuggestionBadge: Bool {
        section.pendingOverloadPreviousWeight != nil
    }

    private var setTableColumns: WorkoutSetTableLayout.Columns {
        WorkoutSetTableLayout.columns(for: max(0, tableWidth - 32), isReadOnly: section.isFinished)
    }

    private func setTableHeader(columns: WorkoutSetTableLayout.Columns) -> some View {
        HStack(spacing: WorkoutSetTableLayout.spacing) {
            Text("workout.set.header.set")
                .frame(width: columns.set, alignment: .center)

            Text(verbatim: appPreferences.weightUnit.localizedAbbreviation)
                .frame(width: columns.weight, alignment: .center)

            Text("workout.set.header.reps")
                .frame(width: columns.reps, alignment: .center)

            Text("workout.set.header.feel")
                .frame(width: columns.rpe, alignment: .center)

            Text("workout.set.header.done")
                .frame(width: columns.actions, alignment: .trailing)
        }
        .font(.system(.caption2, design: .rounded).bold())
        .foregroundStyle(.secondary)
        .textCase(.uppercase)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var lastSessionReferenceRow: some View {
        let text = lastSessionText
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath")
                .accessibilityHidden(true)

            Text(text)
                .lineLimit(2)
                .truncationMode(.tail)
                .monospacedDigit()
        }
        .font(.system(.caption, design: .rounded))
        .foregroundStyle(lastSessionReference == nil ? .tertiary : .secondary)
        .accessibilityLabel(Text(String(format: String(localized: "accessibility.workout.last_session"), text)))
    }

    private var lastSessionText: String {
        guard let reference = lastSessionReference else {
            return String(localized: "workout.last_session.empty")
        }

        let reps = repsText(for: reference.sets)
        let base: String
        switch reference.label {
        case .last:
            if let weight = singleWeightedValue(in: reference.sets) {
                let weightText = weight.formatted(.number.precision(.fractionLength(0...1)))
                base = String(format: String(localized: "workout.last_session.reference"), weightText, reps)
            } else if reference.sets.contains(where: { $0.weight != nil }) {
                let details = reference.sets.map(setDetailText).joined(separator: " -> ")
                base = String(format: String(localized: "workout.last_session.reference.details"), details)
            } else {
                base = String(format: String(localized: "workout.last_session.reference.bodyweight"), reps)
            }
        case .baseline:
            base = String(format: String(localized: "workout.last_session.baseline.format"), referenceDetailsBody(reference))
        }

        guard reference.isFallback else { return base }
        return [
            base,
            String(localized: "workout.last_session.fallback_hint")
        ].joined(separator: " · ")
    }

    private func referenceDetailsBody(_ reference: LastSessionReference) -> String {
        let reps = repsText(for: reference.sets)
        if let weight = singleWeightedValue(in: reference.sets) {
            let weightText = weight.formatted(.number.precision(.fractionLength(0...1)))
            return "\(weightText) × \(reps)"
        }
        if reference.sets.contains(where: { $0.weight != nil }) {
            return reference.sets.map(setDetailText).joined(separator: " -> ")
        }
        return reps
    }

    private func repsText(for sets: [LastSessionReference.SetSummary]) -> String {
        sets.map(\.reps).map(String.init).joined(separator: ", ")
    }

    private func singleWeightedValue(in sets: [LastSessionReference.SetSummary]) -> Double? {
        guard sets.isEmpty == false,
              sets.allSatisfy({ $0.weight != nil }),
              let firstWeight = sets[0].weight,
              sets.allSatisfy({ $0.weight == firstWeight }) else {
            return nil
        }
        return firstWeight
    }

    private func setDetailText(for set: LastSessionReference.SetSummary) -> String {
        let reps = String(set.reps)
        if let weight = set.weight {
            let weightText = weight.formatted(.number.precision(.fractionLength(0...1)))
            return "\(weightText) × \(reps)"
        }
        let bodyweight = String(localized: "equipment.short.bodyweight")
        return "\(bodyweight) × \(reps)"
    }
    
    @ViewBuilder
    private var footerAction: some View {
        if section.isFinished {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("workout.exercise.finished")
            }
            .font(.system(.headline, design: .rounded))
            // .green stays: "done" is a strong universal convention worth keeping.
            .foregroundStyle(.green)
            .padding()
            .frame(maxWidth: .infinity)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        } else {
            Button("workout.exercise.finish_or_skip") {
                onFinishExercise(section.programExercise.id)
            }
            .font(.system(.headline, design: .rounded))
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .disabled(!canFinish)
            .padding(.horizontal)
        }
    }
    
    private var canFinish: Bool {
        true
    }
}

private struct WorkoutSetTableWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview("Active") {
    WorkoutExercisePageView(
        section: WorkoutSessionData.mock.exerciseSections[0],
        lastSessionReference: LastSessionReference(
            label: .last,
            sets: [
                .init(weight: 60, reps: 8),
                .init(weight: 60, reps: 8),
                .init(weight: 62.5, reps: 7)
            ],
            unit: .kg,
            isFallback: false
        ),
        onAddSet: { _ in },
        onUpdateSet: { _, _, _, _ in },
        onCompleteSet: { _ in },
        onDeleteSet: { _ in },
        onFinishExercise: { _ in }
    )
    .environment(AppPreferences())
}

#Preview("Finished") {
    var section = WorkoutSessionData.mock.exerciseSections[0]
    section.isFinished = true
    return WorkoutExercisePageView(
        section: section,
        lastSessionReference: nil,
        onAddSet: { _ in },
        onUpdateSet: { _, _, _, _ in },
        onCompleteSet: { _ in },
        onDeleteSet: { _ in },
        onFinishExercise: { _ in }
    )
    .environment(AppPreferences())
}
