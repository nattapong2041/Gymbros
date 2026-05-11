import SwiftUI

struct SetRowView: View {
    let state: WorkoutSetRowState
    
    // Actions handed down from the parent view or VM
    var onUpdate: (String, String, Double?) -> Void
    var onComplete: () -> Void
    var onRetry: () -> Void
    var onDelete: () -> Void
    
    @FocusState private var isWeightFocused: Bool
    @FocusState private var isRepsFocused: Bool
    
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
                    get: { state.weightText },
                    set: { onUpdate($0, state.repsText, state.rpe) }
                ))
                .keyboardType(.decimalPad)
                .focused($isWeightFocused)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .rounded).bold())
                .multilineTextAlignment(.center)
                .padding(.vertical, 8)
                .background(Color.gymSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(minWidth: 60)
            }
            
            // Reps Input
            VStack(alignment: .leading, spacing: 4) {
                TextField("0", text: Binding(
                    get: { state.repsText },
                    set: { onUpdate(state.weightText, $0, state.rpe) }
                ))
                .keyboardType(.numberPad)
                .focused($isRepsFocused)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .rounded).bold())
                .multilineTextAlignment(.center)
                .padding(.vertical, 8)
                .background(Color.gymSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(minWidth: 60)
            }
            
            // RPE Picker (using Menu for HIG compliance and tap target)
            Menu {
                ForEach(Array(stride(from: 10.0, through: 1.0, by: -0.5)), id: \.self) { rpeValue in
                    Button {
                        onUpdate(state.weightText, state.repsText, rpeValue)
                    } label: {
                        Text(String(format: "%.1f", rpeValue))
                    }
                }
                Button(role: .destructive) {
                    onUpdate(state.weightText, state.repsText, nil)
                } label: {
                    Text("Clear RPE")
                }
            } label: {
                Text(state.rpe != nil ? String(format: "%.1f", state.rpe!) : "RPE")
                    .font(.system(.caption, design: .rounded).bold())
                    .foregroundStyle(state.rpe != nil ? .primary : .secondary)
                    .frame(minWidth: 44, minHeight: 36)
                    .background(Color.gymSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .contentShape(Rectangle()) // Ensure entire area is tappable
            
            Spacer(minLength: 0)
            
            // Sync & Completion
            HStack(spacing: 8) {
                syncIndicator
                
                Button(action: onComplete) {
                    Image(systemName: state.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 28))
                        .foregroundStyle(state.isCompleted ? .green : .secondary)
                        .frame(width: 48, height: 48) // HIG 48pt tap target
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
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
                Image(systemName: "exclamationmark.icloud.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.red)
                    .frame(width: 32, height: 32)
            }
        }
    }
}

#Preview {
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
        SetRowView(
            state: WorkoutSessionData.mock.exerciseSections[0].sets[2],
            onUpdate: { _, _, _ in },
            onComplete: {},
            onRetry: {},
            onDelete: {}
        )
    }
    .padding()
}
