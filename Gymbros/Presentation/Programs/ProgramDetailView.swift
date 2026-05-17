import SwiftUI

struct ProgramDetailView: View {
    @State var viewModel: ProgramDetailViewModel
    @State private var isShowingEditProgram = false
    @State private var isShowingAddDayAlert = false
    @State private var newDayName = ""
    @State private var dayToRename: ProgramDay?
    @State private var renamedDayName = ""
    @State private var isShowingDeleteProgramConfirmation = false

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle:
                Color.clear
            case .loading:
                ProgressView()
            case .empty:
                ContentUnavailableView("programDetail.empty.title", systemImage: "calendar.badge.plus")
            case .success(let data):
                List {
                    headerSection(data.program)

                    Section {
                        ForEach(data.days) { day in
                            NavigationLink {
                                DayBuilderView(viewModel: DayBuilderViewModel(dayId: day.id))
                                    .id(day.id)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "calendar")
                                        .foregroundStyle(.blue)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(day.name)
                                            .font(.headline)
                                        Text("programDetail.exerciseCount \(day.exercises.count)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteDay(day) }
                                } label: {
                                    Label("common.delete", systemImage: "trash")
                                }
                                .tint(.red)

                                Button {
                                    dayToRename = day
                                    renamedDayName = day.name
                                } label: {
                                    Label("common.rename", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                        .onMove { source, destination in
                            Task { await viewModel.moveDays(from: source, to: destination) }
                        }
                    } header: {
                        HStack {
                            Label("programDetail.days.section", systemImage: "list.bullet.indent")
                            Spacer()
                            Button {
                                isShowingAddDayAlert = true
                                newDayName = ""
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("programDetail.addDay.action")
                                }
                                .font(.subheadline.bold())
                                .foregroundStyle(.blue)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .navigationTitle(data.program.name)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button {
                                isShowingEditProgram = true
                            } label: {
                                Label("common.edit", systemImage: "pencil")
                            }

                            if !data.program.isActive {
                                Button {
                                    Task { await viewModel.setActive() }
                                } label: {
                                    Label("programs.setActive.action", systemImage: "star")
                                }
                            }

                            Divider()

                            Button(role: .destructive) {
                                isShowingDeleteProgramConfirmation = true
                            } label: {
                                Label("common.delete", systemImage: "trash")
                            }
                            .tint(.red)
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            case .error(let error):
                ContentUnavailableView {
                    Label(LocalizedStringKey(error.titleKey), systemImage: "exclamationmark.triangle")
                } description: {
                    Text(LocalizedStringKey(error.messageKey))
                } actions: {
                    Button("common.retry") {
                        Task { await viewModel.loadProgram() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .task {
            await viewModel.loadProgram()
        }
        .alert("programDetail.addDay.title", isPresented: $isShowingAddDayAlert) {
            TextField("programDetail.dayName.placeholder", text: $newDayName)
            Button("common.add") {
                Task { await viewModel.addDay(name: newDayName) }
            }
            Button("common.cancel", role: .cancel) {}
        }
        .alert("programDetail.renameDay.title", isPresented: Binding(
            get: { dayToRename != nil },
            set: { if !$0 { dayToRename = nil } }
        )) {
            TextField("programDetail.dayName.placeholder", text: $renamedDayName)
            Button("common.save") {
                if let day = dayToRename {
                    Task { await viewModel.renameDay(day, name: renamedDayName) }
                }
            }
            Button("common.cancel", role: .cancel) {}
        }
        .alert("programs.delete.confirmation.title", isPresented: $isShowingDeleteProgramConfirmation) {
            Button("common.delete", role: .destructive) {
                Task { await viewModel.deleteProgram() }
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("programs.delete.confirmation.message")
        }
        .transientErrorAlert(error: Binding(
            get: { viewModel.transientError },
            set: { viewModel.transientError = $0 }
        ))
        .sheet(isPresented: $isShowingEditProgram) {
            if case .success(let data) = viewModel.state {
                ProgramBuilderView(viewModel: ProgramBuilderViewModel(mode: .edit(data.program)))
                    .onDisappear {
                        Task { await viewModel.loadProgram() }
                    }
            }
        }
    }

    private func headerSection(_ program: Program) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                if program.isActive {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.green)
                        Text("programs.active.badge")
                            .font(.subheadline.bold())
                    }
                    .padding(.bottom, 4)
                }

                if let description = program.description, !description.isEmpty {
                    Text(description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                } else {
                    Text("programDetail.noDescription")
                        .font(.body)
                        .italic()
                        .foregroundStyle(.secondary) // Increased contrast from .tertiary
                }
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Previews

#Preview("Success") {
    NavigationStack {
        ProgramDetailView(viewModel: {
            let viewModel = ProgramDetailViewModel(programId: ProgramSamples.programId)
            viewModel.state = .success(ProgramSamples.detailData)
            return viewModel
        }())
    }
}

#Preview("Loading") {
    NavigationStack {
        ProgramDetailView(viewModel: {
            let viewModel = ProgramDetailViewModel(programId: ProgramSamples.programId)
            viewModel.state = .loading
            return viewModel
        }())
    }
}

#Preview("Empty") {
    NavigationStack {
        ProgramDetailView(viewModel: {
            let viewModel = ProgramDetailViewModel(programId: ProgramSamples.programId)
            viewModel.state = .empty
            return viewModel
        }())
    }
}

#Preview("Error") {
    NavigationStack {
        ProgramDetailView(viewModel: {
            let viewModel = ProgramDetailViewModel(programId: ProgramSamples.programId)
            viewModel.state = .error(.api(.server, statusCode: 500))
            return viewModel
        }())
    }
}

