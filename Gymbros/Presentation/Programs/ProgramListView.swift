import SwiftUI

struct ProgramListView<VM: ProgramListProtocol>: View {
    @State var viewModel: VM
    @State private var selectedProgramId: UUID?
    @State private var isShowingCreateSheet = false
    @State private var programToDelete: Program?

    var body: some View {
        NavigationSplitView {
            content
                .navigationTitle("programs.title")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            isShowingCreateSheet = true
                        } label: {
                            Label("programs.create.action", systemImage: "plus")
                        }
                    }
                }
        } detail: {
            if let programId = selectedProgramId {
                // ProgramDetailView will be implemented next
                Text("Program Detail for \(programId.uuidString)")
            } else {
                ContentUnavailableView(
                    "programs.detail.placeholder.title",
                    systemImage: "dumbbell",
                    description: Text("programs.detail.placeholder.message")
                )
            }
        }
        .sheet(isPresented: $isShowingCreateSheet) {
            // ProgramBuilderView will be implemented later
            NavigationStack {
                Text("Create Program Form")
                    .navigationTitle("programBuilder.title.create")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("common.cancel") { isShowingCreateSheet = false }
                        }
                    }
            }
        }
        .alert(
            "programs.delete.confirmation.title",
            isPresented: Binding(
                get: { programToDelete != nil },
                set: { if !$0 { programToDelete = nil } }
            ),
            presenting: programToDelete
        ) { program in
            Button("common.delete", role: .destructive) {
                Task { await viewModel.deleteProgram(program) }
            }
            Button("common.cancel", role: .cancel) {}
        } message: { program in
            Text("programs.delete.confirmation.message \(program.name)")
        }
        .task {
            await viewModel.loadPrograms()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
        case .empty:
            ContentUnavailableView {
                Label("programs.empty.title", systemImage: "dumbbell.fill")
            } description: {
                Text("programs.empty.message")
            } actions: {
                Button("programs.create.action") {
                    isShowingCreateSheet = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.gymAccent)
            }
        case .success(let programs):
            List(selection: $selectedProgramId) {
                ForEach(programs) { program in
                    ProgramRow(program: program)
                        .tag(program.id)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                programToDelete = program
                            } label: {
                                Label("common.delete", systemImage: "trash")
                            }

                            if !program.isActive {
                                Button {
                                    Task { await viewModel.setActive(program: program) }
                                } label: {
                                    Label("programs.setActive.action", systemImage: "star.fill")
                                }
                                .tint(.gymAccent)
                            }
                        }
                }
            }
        case .error(let error):
            ContentUnavailableView {
                Label(error.titleKey, systemImage: "exclamationmark.triangle")
            } description: {
                Text(error.messageKey)
            } actions: {
                Button("common.retry") {
                    Task { await viewModel.loadPrograms() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

struct ProgramRow: View {
    let program: Program

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(program.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if program.isActive {
                    Text("programs.active.badge")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gymAccent)
                        .foregroundStyle(.black)
                        .clipShape(Capsule())
                }
            }

            if let description = program.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Text("programs.dayCount \(program.days.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Previews

@Observable final class PreviewProgramListViewModel: ProgramListProtocol {
    var state: ViewState<[Program]> = .success(ProgramSamples.programs)
    var transientError: AppError? = nil

    func loadPrograms() async {}
    func setActive(program: Program) async {
        // Toggle active for preview
        if case .success(var programs) = state {
            for i in programs.indices {
                programs[i].isActive = (programs[i].id == program.id)
            }
            state = .success(programs)
        }
    }
    func deleteProgram(_ program: Program) async {
        if case .success(var programs) = state {
            programs.removeAll { $0.id == program.id }
            state = programs.isEmpty ? .empty : .success(programs)
        }
    }
}

#Preview("Success") {
    ProgramListView(viewModel: PreviewProgramListViewModel())
}

#Preview("Empty") {
    let vm = PreviewProgramListViewModel()
    vm.state = .empty
    return ProgramListView(viewModel: vm)
}

#Preview("Error") {
    let vm = PreviewProgramListViewModel()
    vm.state = .error(.network(.offline))
    return ProgramListView(viewModel: vm)
}
