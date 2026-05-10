import SwiftUI

struct ProgramBuilderView<VM: ProgramBuilderProtocol>: View {
    @State var viewModel: VM
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("programBuilder.name.placeholder", text: $viewModel.name)
                        .autocorrectionDisabled()

                    TextField("programBuilder.description.placeholder", text: $viewModel.description, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("programBuilder.details.section")
                } footer: {
                    if let error = viewModel.transientError {
                        Text(error.messageKey)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(viewModel.mode == .create ? "programBuilder.title.create" : "programBuilder.title.edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    if case .loading = viewModel.state {
                        ProgressView()
                    } else {
                        Button("common.save") {
                            Task {
                                await viewModel.save()
                                if case .success = viewModel.state {
                                    dismiss()
                                }
                            }
                        }
                        .disabled(!viewModel.canSave)
                    }
                }
            }
            .disabled(isSaving)
        }
    }

    private var isSaving: Bool {
        if case .loading = viewModel.state { return true }
        return false
    }
}

// MARK: - Previews

@Observable final class PreviewProgramBuilderViewModel: ProgramBuilderProtocol {
    var mode: ProgramBuilderMode
    var name: String = ""
    var description: String = ""
    var state: ViewState<Program> = .idle
    var transientError: AppError? = nil

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(mode: ProgramBuilderMode) {
        self.mode = mode
        if case let .edit(program) = mode {
            self.name = program.name
            self.description = program.description ?? ""
        }
    }

    func save() async {
        state = .loading
        try? await Task.sleep(for: .seconds(1))
        state = .success(ProgramSamples.program)
    }

    func resetForm() {
        name = ""
        description = ""
    }
}

#Preview("Create") {
    ProgramBuilderView(viewModel: PreviewProgramBuilderViewModel(mode: .create))
}

#Preview("Edit") {
    ProgramBuilderView(viewModel: PreviewProgramBuilderViewModel(mode: .edit(ProgramSamples.program)))
}
