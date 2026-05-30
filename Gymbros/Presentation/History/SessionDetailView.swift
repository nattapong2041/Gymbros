import SwiftUI

struct SessionDetailView: View {
    @State var viewModel: SessionDetailViewModel
    private let loadsOnAppear: Bool

    @MainActor
    init(viewModel: SessionDetailViewModel, loadsOnAppear: Bool = true) {
        self._viewModel = State(initialValue: viewModel)
        self.loadsOnAppear = loadsOnAppear
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                ContentUnavailableView(
                    "session.exercise.unknown",
                    systemImage: "list.bullet.clipboard"
                )
            case .error(let error):
                ContentUnavailableView {
                    Label(LocalizedStringKey(error.titleKey), systemImage: "exclamationmark.triangle")
                } description: {
                    Text(LocalizedStringKey(error.messageKey))
                } actions: {
                    Button("common.retry", systemImage: "arrow.clockwise") {
                        Task { await viewModel.load() }
                    }
                }
            case .success(let data):
                List {
                    Section {
                        Text(durationText(for: data.session))
                            .font(.subheadline)
                    }

                    ForEach(exerciseGroups(from: data), id: \.id) { group in
                        Section {
                            ForEach(group.sets) { set in
                                Button {
                                    viewModel.editingSet = set
                                } label: {
                                    SessionSetRow(workoutSet: set)
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Text(group.name)
                        }
                    }
                }
                .navigationTitle(data.session.startedAt.workoutDisplayString)
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .sheet(item: Binding(
            get: { viewModel.editingSet },
            set: { viewModel.editingSet = $0 }
        )) { set in
            EditSetSheet(set: set, viewModel: viewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .transientErrorAlert(error: Binding(
            get: { viewModel.transientError },
            set: { viewModel.transientError = $0 }
        ))
        .task {
            guard loadsOnAppear else { return }
            await viewModel.load()
        }
    }

    private func durationText(for session: WorkoutSession) -> String {
        String(
            format: String(localized: "session.duration"),
            durationMinutes(for: session)
        )
    }

    private func durationMinutes(for session: WorkoutSession) -> Int {
        guard let duration = session.duration else { return 0 }
        return max(1, Int(duration / 60))
    }

    private func exerciseGroups(from data: SessionDetailData) -> [SessionExerciseSetGroup] {
        Dictionary(grouping: data.sets) { $0.exerciseId }
            .map { exerciseId, sets in
                SessionExerciseSetGroup(
                    id: exerciseId,
                    name: data.exerciseLookup[exerciseId]?.displayName ?? String(localized: "session.exercise.unknown"),
                    sets: sets.sorted { $0.setNumber < $1.setNumber }
                )
            }
            .sorted { lhs, rhs in
                guard let lhsFirstSet = lhs.sets.first, let rhsFirstSet = rhs.sets.first else {
                    return lhs.name < rhs.name
                }
                return lhsFirstSet.completedAt < rhsFirstSet.completedAt
            }
    }
}

private struct EditSetSheet: View {
    let set: WorkoutSet
    let viewModel: SessionDetailViewModel

    @State private var weightText: String
    @State private var repsText: String
    @State private var rpe: Double?
    @State private var didSyncWeightText = false
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.dismiss) private var dismiss

    init(set: WorkoutSet, viewModel: SessionDetailViewModel) {
        self.set = set
        self.viewModel = viewModel
        _weightText = State(initialValue: set.weight.formatted(.number.precision(.fractionLength(0...2))))
        _repsText = State(initialValue: "\(set.reps)")
        _rpe = State(initialValue: set.rpe)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("workout.set.weight")
                        Text(verbatim: appPreferences.weightUnit.localizedAbbreviation)
                            .foregroundStyle(.secondary)
                        Spacer()
                        TextField("0", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("workout.set.reps")
                        Spacer()
                        TextField("0", text: $repsText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
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
                }
            }
            .navigationTitle("session.set.edit.title")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                guard didSyncWeightText == false else { return }
                weightText = appPreferences.weightUnit.formattedKilograms(set.weight, fractionLength: 0...2)
                didSyncWeightText = true
            }
            .onChange(of: appPreferences.weightUnit) { _, newUnit in
                weightText = newUnit.formattedKilograms(set.weight, fractionLength: 0...2)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        guard let weight = parsedWeight, let reps = parsedReps else { return }
                        Task { await viewModel.updateSet(set, weight: weight, reps: reps, rpe: rpe) }
                    }
                    .disabled(parsedWeight == nil || parsedReps == nil)
                }
            }
        }
    }

    private var parsedWeight: Double? {
        appPreferences.weightUnit.kilogramValue(fromDisplayText: weightText)
    }

    private var parsedReps: Int? {
        let trimmed = repsText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let v = Int(trimmed), v >= 1 else { return nil }
        return v
    }
}

#Preview("Loading") {
    NavigationStack {
        SessionDetailView(viewModel: .loading, loadsOnAppear: false)
    }
    .environment(AppPreferences())
}

#Preview("Error") {
    NavigationStack {
        SessionDetailView(viewModel: .error, loadsOnAppear: false)
    }
    .environment(AppPreferences())
}

#Preview("Success") {
    NavigationStack {
        SessionDetailView(viewModel: .success, loadsOnAppear: false)
    }
    .environment(AppPreferences())
}
