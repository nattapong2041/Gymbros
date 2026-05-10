import SwiftUI

struct ProgramBuilderView: View {
    @State var viewModel: ProgramBuilderViewModel
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
                        Text(LocalizedStringKey(error.messageKey))
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
            .transientErrorAlert(error: Binding(
                get: { viewModel.transientError },
                set: { viewModel.transientError = $0 }
            ))
        }
    }

    private var isSaving: Bool {
        if case .loading = viewModel.state { return true }
        return false
    }
}

// MARK: - Previews

#Preview("Create") {
    ProgramBuilderView(viewModel: ProgramBuilderViewModel(mode: .create))
}

#Preview("Edit") {
    ProgramBuilderView(viewModel: ProgramBuilderViewModel(mode: .edit(ProgramSamples.program)))
}
