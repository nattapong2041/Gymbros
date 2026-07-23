import SwiftUI

struct SettingsView: View {
    @State var viewModel: SettingsViewModel
    private let loadsOnAppear: Bool

    @State private var showingPrivacySheet = false
    @State private var showingDeleteSheet = false

    @MainActor
    init(viewModel: SettingsViewModel? = nil, loadsOnAppear: Bool = true) {
        self._viewModel = State(initialValue: viewModel ?? SettingsViewModel())
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
                    "settings.empty.title",
                    systemImage: "gear"
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
                Form {
                    Section(header: Text("settings.section.preferences")) {
                        HStack {
                            Text("settings.weight_unit.label")
                            Spacer()
                            Picker("", selection: Binding(
                                get: { data.weightUnit },
                                set: { newUnit in
                                    Task { await viewModel.updateWeightUnit(newUnit) }
                                }
                            )) {
                                Text("settings.weight_unit.kg").tag(WeightUnit.kg)
                                Text("settings.weight_unit.lb").tag(WeightUnit.lb)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 120)
                            .accessibilityLabel(Text("settings.weight_unit.label"))
                            .accessibilityValue(Text(verbatim: data.weightUnit.localizedAbbreviation))
                        }
                        .frame(minHeight: 48)

                        HStack {
                            Text("settings.training_phase.title")
                            Spacer()
                            Menu {
                                Button("settings.training_phase.bulk") {
                                    Task { await viewModel.updateTrainingPhase(.bulk) }
                                }
                                Button("settings.training_phase.cut") {
                                    Task { await viewModel.updateTrainingPhase(.cut) }
                                }
                                Button("settings.training_phase.maintain") {
                                    Task { await viewModel.updateTrainingPhase(.maintain) }
                                }
                            } label: {
                                Text(trainingPhaseLabel(data.trainingPhase))
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityLabel(Text("settings.training_phase.title"))
                            .accessibilityValue(Text(trainingPhaseLabel(data.trainingPhase)))
                        }
                        .frame(minHeight: 48)
                    }

                    Section(header: Text("settings.section.account")) {
                        Button(role: .destructive) {
                            Task { await viewModel.signOut() }
                        } label: {
                            HStack {
                                Spacer()
                                if viewModel.isSigningOut {
                                    ProgressView()
                                } else {
                                    Text("settings.sign_out.button")
                                }
                                Spacer()
                            }
                        }
                        .frame(minHeight: 48)
                        .disabled(viewModel.isSigningOut)
                    }

                    Section(header: Text("settings.section.about")) {
                        HStack {
                            Text("settings.app_version.label")
                            Spacer()
                            Text(data.appVersion)
                                .foregroundStyle(.secondary)
                        }
                        .frame(minHeight: 48)

                        Button {
                            showingPrivacySheet = true
                        } label: {
                            HStack {
                                Text("settings.privacy_policy.label")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .foregroundStyle(.primary)
                        }
                        .frame(minHeight: 48)

                        Button {
                            showingDeleteSheet = true
                        } label: {
                            HStack {
                                Text("settings.delete_account.label")
                                    .foregroundStyle(.red)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(minHeight: 48)
                    }
                }
                .sheet(isPresented: $showingPrivacySheet) {
                    PlaceholderSheet(
                        title: "settings.privacy_policy.label",
                        message: "settings.privacy_policy.placeholder",
                        dismissKey: "settings.privacy_policy.dismiss",
                        isPresented: $showingPrivacySheet
                    )
                }
                .sheet(isPresented: $showingDeleteSheet) {
                    PlaceholderSheet(
                        title: "settings.delete_account.label",
                        message: "settings.delete_account.placeholder",
                        dismissKey: "settings.delete_account.dismiss",
                        isPresented: $showingDeleteSheet
                    )
                }
            }
        }
        .navigationTitle("settings.title")
        .transientErrorAlert(error: $viewModel.transientError)
        .task {
            guard loadsOnAppear else { return }
            await viewModel.load()
        }
    }

    private func trainingPhaseLabel(_ phase: TrainingPhase?) -> String {
        switch phase {
        case .bulk: String(localized: "settings.training_phase.bulk")
        case .cut: String(localized: "settings.training_phase.cut")
        case .maintain: String(localized: "settings.training_phase.maintain")
        case nil: "—"
        }
    }
}

struct PlaceholderSheet: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let dismissKey: LocalizedStringKey
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "info.circle")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(message)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(dismissKey) {
                        isPresented = false
                    }
                }
            }
        }
    }
}

#Preview("Loading") {
    NavigationStack {
        SettingsView(viewModel: .loading, loadsOnAppear: false)
    }
}

#Preview("Error") {
    NavigationStack {
        SettingsView(viewModel: .error, loadsOnAppear: false)
    }
}

#Preview("Success (kg)") {
    NavigationStack {
        SettingsView(viewModel: .success(weightUnit: .kg), loadsOnAppear: false)
    }
}

#Preview("Success (lb)") {
    NavigationStack {
        SettingsView(viewModel: .success(weightUnit: .lb), loadsOnAppear: false)
    }
}
