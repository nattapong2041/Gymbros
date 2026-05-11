import SwiftUI

struct ProgramListView: View {
    @State var viewModel: ProgramListViewModel
    @State private var isShowingCreateSheet = false
    @State private var programToDelete: Program?
    @State private var hasLoadedPrograms = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("programs.title")
                .navigationDestination(for: UUID.self) { programId in
                    ProgramDetailView(viewModel: ProgramDetailViewModel(programId: programId))
                        .id(programId)
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            isShowingCreateSheet = true
                        } label: {
                            Label("programs.create.action", systemImage: "plus")
                        }
                    }
                }
        }
        .sheet(isPresented: $isShowingCreateSheet) {
            ProgramBuilderView(viewModel: ProgramBuilderViewModel(mode: .create))
                .onDisappear {
                    Task { await viewModel.loadPrograms(isRefreshing: true) }
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
            .tint(.red)
            Button("common.cancel", role: .cancel) {}
        } message: { program in
            Text("programs.delete.confirmation.message \(program.name)")
        }
        .transientErrorAlert(error: Binding(
            get: { viewModel.transientError },
            set: { viewModel.transientError = $0 }
        ))
        .task {
            await viewModel.loadPrograms()
            hasLoadedPrograms = true
        }
        .onAppear {
            guard hasLoadedPrograms else { return }
            Task { await viewModel.loadPrograms(isRefreshing: true) }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            Color.clear
        case .loading:
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
            }
        case .success(let programs):
            List {
                ForEach(programs) { program in
                    NavigationLink(value: program.id) {
                        ProgramRow(program: program)
                    }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                programToDelete = program
                            } label: {
                                Label("common.delete", systemImage: "trash")
                            }
                            .tint(.red)

                            if !program.isActive {
                                Button {
                                    Task { await viewModel.setActive(program: program) }
                                } label: {
                                    Label("programs.setActive.action", systemImage: "star.fill")
                                }
                                .tint(.blue)
                            }
                        }
                }
            }
            .refreshable {
                await viewModel.loadPrograms(isRefreshing: true)
            }
        case .error(let error):
            ContentUnavailableView {
                Label(LocalizedStringKey(error.titleKey), systemImage: "exclamationmark.triangle")
            } description: {
                Text(LocalizedStringKey(error.messageKey))
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
                        .background(Color.green.opacity(0.16))
                        .foregroundStyle(.green)
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

#Preview("Success") {
    ProgramListView(viewModel: {
        let viewModel = ProgramListViewModel()
        viewModel.state = .success(ProgramSamples.programs)
        return viewModel
    }())
}

#Preview("Empty") {
    ProgramListView(viewModel: {
        let viewModel = ProgramListViewModel()
        viewModel.state = .empty
        return viewModel
    }())
}

#Preview("Error") {
    ProgramListView(viewModel: {
        let viewModel = ProgramListViewModel()
        viewModel.state = .error(.network(.offline))
        return viewModel
    }())
}
