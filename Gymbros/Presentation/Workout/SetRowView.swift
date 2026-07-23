import SwiftUI

struct SetRowView: View {
    let state: WorkoutSetRowState
    var isReadOnly: Bool = false
    var columns: WorkoutSetTableLayout.Columns = WorkoutSetTableLayout.columns(for: 0, isReadOnly: false)
    
    // Actions handed down from the parent view or VM
    var onUpdate: (String, String, Double?) -> Void
    var onComplete: () -> Void
    var onDelete: () -> Void

    @State private var weightText: String
    @State private var repsText: String
    @State private var rpe: Double?
    @FocusState private var isWeightFocused: Bool
    @FocusState private var isRepsFocused: Bool

    init(
        state: WorkoutSetRowState,
        isReadOnly: Bool = false,
        columns: WorkoutSetTableLayout.Columns = WorkoutSetTableLayout.columns(for: 0, isReadOnly: false),
        onUpdate: @escaping (String, String, Double?) -> Void,
        onComplete: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.state = state
        self.isReadOnly = isReadOnly
        self.columns = columns
        self.onUpdate = onUpdate
        self.onComplete = onComplete
        self.onDelete = onDelete
        _weightText = State(initialValue: state.weightText)
        _repsText = State(initialValue: state.repsText)
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

    var body: some View {
        HStack(spacing: WorkoutSetTableLayout.spacing) {
            // Set Number
            Text("\(state.setNumber)")
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .frame(width: columns.set)
            
            // Weight Input
            VStack(alignment: .leading, spacing: 4) {
                TextField("0", text: Binding(
                    get: { weightText },
                    set: { weightText = $0 }
                ))
                .keyboardType(.decimalPad)
                .focused($isWeightFocused)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .rounded).bold())
                .multilineTextAlignment(.center)
                .padding(.vertical, 12) // Increased padding for 48pt target
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(width: columns.weight, height: 48) // Mandated 48pt tap target
                .disabled(isReadOnly)
            }
            
            // Reps Input
            VStack(alignment: .leading, spacing: 4) {
                TextField("0", text: Binding(
                    get: { repsText },
                    set: { repsText = $0 }
                ))
                .keyboardType(.numberPad)
                .focused($isRepsFocused)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .rounded).bold())
                .multilineTextAlignment(.center)
                .padding(.vertical, 12) // Increased padding for 48pt target
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(width: columns.reps, height: 48) // Mandated 48pt tap target
                .disabled(isReadOnly)
            }
            
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

            // Completion
            HStack(spacing: WorkoutSetTableLayout.actionSpacing) {
                if !isReadOnly, columns.showsInlineDelete {
                    Button(role: .destructive, action: onDelete) {
                        Label("workout.set.delete", systemImage: "trash")
                            .labelStyle(.iconOnly)
                            .font(.system(size: 20))
                            .frame(width: WorkoutSetTableLayout.minimumTapTarget, height: 48) // Mandated 48pt tap target
                    }
                }

                Button(action: onComplete) {
                    Label("accessibility.workout.set.complete", systemImage: state.isCompleted ? "checkmark.circle.fill" : "circle")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 28))
                        .foregroundStyle(state.isCompleted ? .green : .secondary)
                        .frame(width: WorkoutSetTableLayout.minimumTapTarget, height: 48) // HIG 48pt tap target
                        .contentShape(Rectangle())
                }
                .disabled(isReadOnly)
            }
            .frame(width: columns.actions, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if !isReadOnly {
                Button(role: .destructive, action: onDelete) {
                    Label("workout.set.delete", systemImage: "trash")
                }
                .tint(.red)
            }
        }
        .onChange(of: weightText) { _, newValue in
            onUpdate(newValue, repsText, rpe)
        }
        .onChange(of: repsText) { _, newValue in
            onUpdate(weightText, newValue, rpe)
        }
        .onChange(of: rpe) { _, newValue in
            onUpdate(weightText, repsText, newValue)
        }
        .onChange(of: state.weightText) { _, newValue in
            guard weightText != newValue else { return }
            weightText = newValue
        }
        .onChange(of: state.repsText) { _, newValue in
            guard repsText != newValue else { return }
            repsText = newValue
        }
        .onChange(of: state.rpe) { _, newValue in
            guard rpe != newValue else { return }
            rpe = newValue
        }
        .dismissKeyboardOnTap()
    }
    
}

#Preview("Active") {
    VStack {
        SetRowView(
            state: WorkoutSessionData.mock.exerciseSections[0].sets[0],
            onUpdate: { _, _, _ in },
            onComplete: {},
            onDelete: {}
        )
        SetRowView(
            state: WorkoutSessionData.mock.exerciseSections[0].sets[1],
            onUpdate: { _, _, _ in },
            onComplete: {},
            onDelete: {}
        )
    }
    .padding()
    .environment(AppPreferences())
}

#Preview("ReadOnly") {
    VStack {
        SetRowView(
            state: WorkoutSessionData.mock.exerciseSections[0].sets[0],
            isReadOnly: true,
            onUpdate: { _, _, _ in },
            onComplete: {},
            onDelete: {}
        )
    }
    .padding()
    .environment(AppPreferences())
}
