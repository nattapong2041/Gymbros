import SwiftUI

struct SetRowView: View {
    let state: WorkoutSetRowState
    var isReadOnly: Bool = false
    
    // Actions handed down from the parent view or VM
    var onUpdate: (String, String, Double?) -> Void
    var onComplete: () -> Void
    var onRetry: () -> Void
    var onDelete: () -> Void
    
    @State private var weightText: String
    @State private var repsText: String
    @State private var rpe: Double?
    @FocusState private var isWeightFocused: Bool
    @FocusState private var isRepsFocused: Bool

    init(
        state: WorkoutSetRowState,
        isReadOnly: Bool = false,
        onUpdate: @escaping (String, String, Double?) -> Void,
        onComplete: @escaping () -> Void,
        onRetry: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.state = state
        self.isReadOnly = isReadOnly
        self.onUpdate = onUpdate
        self.onComplete = onComplete
        self.onRetry = onRetry
        self.onDelete = onDelete
        _weightText = State(initialValue: state.weightText)
        _repsText = State(initialValue: state.repsText)
        _rpe = State(initialValue: state.rpe)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Set Number
            Text("\(state.setNumber)")
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            
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
                .background(Color.gymSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(minWidth: 64, minHeight: 48) // Mandated 48pt tap target
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
                .background(Color.gymSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(minWidth: 64, minHeight: 48) // Mandated 48pt tap target
                .disabled(isReadOnly)
            }
            
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
                    .frame(minWidth: 48, minHeight: 48) // Mandated 48pt tap target
                    .background(Color.gymSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(isReadOnly)
            .contentShape(Rectangle()) // Ensure entire area is tappable
            
            Spacer(minLength: 0)
            
            // Sync & Completion
            HStack(spacing: 8) {
                if !isReadOnly {
                    syncIndicator

                    Button(role: .destructive, action: onDelete) {
                        Label("workout.set.delete", systemImage: "trash")
                            .labelStyle(.iconOnly)
                            .font(.system(size: 20))
                            .frame(width: 48, height: 48) // Mandated 48pt tap target
                    }
                }
                
                Button(action: onComplete) {
                    Label("accessibility.workout.set.complete", systemImage: state.isCompleted ? "checkmark.circle.fill" : "circle")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 28))
                        .foregroundStyle(state.isCompleted ? .green : .secondary)
                        .frame(width: 48, height: 48) // HIG 48pt tap target
                        .contentShape(Rectangle())
                }
                .disabled(isReadOnly)
            }
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
    }
    
    @ViewBuilder
    private var syncIndicator: some View {
        switch state.syncState {
        case .pending:
            EmptyView()
        case .uploading:
            ProgressView()
                .controlSize(.small)
                .frame(width: 24, height: 24)
        case .uploaded:
            Image(systemName: "cloud.checkmark")
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .failed:
            Button(action: onRetry) {
                Label("workout.sync.retry", systemImage: "exclamationmark.icloud.fill")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 20))
                    .foregroundStyle(.red)
                    .frame(width: 32, height: 32)
            }
        }
    }
}

#Preview("Active") {
    VStack {
        SetRowView(
            state: WorkoutSessionData.mock.exerciseSections[0].sets[0],
            onUpdate: { _, _, _ in },
            onComplete: {},
            onRetry: {},
            onDelete: {}
        )
        SetRowView(
            state: WorkoutSessionData.mock.exerciseSections[0].sets[1],
            onUpdate: { _, _, _ in },
            onComplete: {},
            onRetry: {},
            onDelete: {}
        )
    }
    .padding()
}

#Preview("ReadOnly") {
    VStack {
        SetRowView(
            state: WorkoutSessionData.mock.exerciseSections[0].sets[0],
            isReadOnly: true,
            onUpdate: { _, _, _ in },
            onComplete: {},
            onRetry: {},
            onDelete: {}
        )
    }
    .padding()
}

