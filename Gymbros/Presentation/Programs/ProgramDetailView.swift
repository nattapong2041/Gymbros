import SwiftUI

struct ProgramDetailView<VM: ProgramDetailProtocol>: View {
    @State var viewModel: VM
    @State private var isShowingEditProgram = false
    @State private var isShowingAddDayAlert = false
    @State private var newDayName = ""
    @State private var dayToRename: ProgramDay?
    @State private var renamedDayName = ""
    @State private var isShowingDeleteProgramConfirmation = false

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView()
            case .empty:
                ContentUnavailableView("programDetail.empty.title", systemImage: "calendar.badge.plus")
            case .success(let data):
                List {
                    headerSection(data.program)

                    Section {
                        ForEach(data.days) { day in
                            NavigationLink {
                                // DayBuilderView will be next
                                Text("Day Builder for \(day.name)")
                            } label: {
                                HStack {
                                    Text(day.name)
                                        .font(.headline)
                                    Spacer()
                                    Text("programDetail.exerciseCount \(day.exercises.count)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteDay(day) }
                                } label: {
                                    Label("common.delete", systemImage: "trash")
                                }

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
                            Text("programDetail.days.section")
                            Spacer()
                            Button {
                                isShowingAddDayAlert = true
                                newDayName = ""
                            } label: {
                                Label("programDetail.addDay.action", systemImage: "plus")
                                    .font(.subheadline.bold())
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
                        } label: {
                            Image(systemName: "ellipsis.circle")
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
        .sheet(isPresented: $isShowingEditProgram) {
            if case .success = viewModel.state {
                // ProgramBuilderView implementation needs to be injected here normally
                // For Task 3 we just use a placeholder if we don't have the real VM
                Text("Edit Program Metadata Sheet")
            }
        }
    }

    private func headerSection(_ program: Program) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                if program.isActive {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Color.gymAccent)
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
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Previews

@Observable final class PreviewProgramDetailViewModel: ProgramDetailProtocol {
    var programId: UUID = ProgramSamples.programId
    var state: ViewState<ProgramDetailData> = .success(ProgramSamples.detailData)
    var transientError: AppError? = nil

    func loadProgram() async {}
    func setActive() async {
        if case .success(var data) = state {
            data.program.isActive = true
            state = .success(data)
        }
    }
    func deleteProgram() async {}
    func addDay(name: String) async {
        if case .success(var data) = state {
            let newDay = ProgramDay(id: UUID(), programId: programId, name: name, dayOrder: data.days.count, createdAt: Date())
            data.days.append(newDay)
            state = .success(data)
        }
    }
    func renameDay(_ day: ProgramDay, name: String) async {
        if case .success(var data) = state {
            if let index = data.days.firstIndex(where: { $0.id == day.id }) {
                data.days[index].name = name
                state = .success(data)
            }
        }
    }
    func deleteDay(_ day: ProgramDay) async {
        if case .success(var data) = state {
            data.days.removeAll { $0.id == day.id }
            state = .success(data)
        }
    }
    func moveDays(from sourceOffsets: IndexSet, to destinationOffset: Int) async {
        if case .success(var data) = state {
            data.days.move(fromOffsets: sourceOffsets, toOffset: destinationOffset)
            state = .success(data)
        }
    }
}

#Preview {
    NavigationStack {
        ProgramDetailView(viewModel: PreviewProgramDetailViewModel())
    }
}
