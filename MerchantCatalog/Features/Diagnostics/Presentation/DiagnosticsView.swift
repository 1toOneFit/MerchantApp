#if DEBUG
import SwiftUI

/// DEBUG-only Diagnostics sheet: installation and session ids, the slow-network toggle, the
/// experiment override, user properties, the analytics event log, and recent log entries. `AppTabView` presents it inside a navigation stack.
struct DiagnosticsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: DiagnosticsViewModel

    init(viewModel: DiagnosticsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List {
            installationSection
            networkSection
            experimentSection
            userPropertiesSection
            eventsSection
            logsSection
        }
        .navigationTitle("Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .task { await viewModel.loadLogs() }
        .refreshable { await viewModel.loadLogs() }
    }

    private var installationSection: some View {
        Section("Installation") {
            IdentifierRow(title: "Installation ID", value: viewModel.installationID)
            IdentifierRow(title: "Session ID", value: viewModel.currentSessionID ?? "No session yet")
            Button("Reset installation ID", role: .destructive) {
                viewModel.resetInstallationID()
            }
        }
    }

    private var networkSection: some View {
        Section {
            Toggle("Slow network", isOn: $viewModel.isSlowNetworkEnabled)
        } header: {
            Text("Network")
        } footer: {
            Text("Adds a 2-second server delay to every API request, to check loading states. Images aren't affected. Stays on after relaunch.")
        }
    }

    private var experimentSection: some View {
        Section {
            LabeledContent("Experiment ID", value: Experiment.productCardDensity.rawValue)
                .font(.callout.monospaced())
            LabeledContent(
                "This launch",
                value: "\(viewModel.cardAssignment.variant.rawValue) (\(viewModel.cardAssignment.source.rawValue))"
            )
            Picker("Override", selection: $viewModel.cardOverride) {
                Text("Auto").tag(ExperimentVariant?.none)
                Text("Control").tag(ExperimentVariant?.some(.control))
                Text("Treatment").tag(ExperimentVariant?.some(.treatment))
            }
        } header: {
            Text("Experiment")
        } footer: {
            Text("Changes apply at the next launch. Auto uses the installation's hashed variant; Reset installation ID re-buckets at the next launch and keeps the override.")
        }
    }

    private var userPropertiesSection: some View {
        Section("User properties") {
            ForEach(viewModel.userProperties) { property in
                LabeledContent(property.name, value: property.value)
                    .font(.callout.monospaced())
            }
        }
    }

    private var eventsSection: some View {
        Section {
            if viewModel.events.isEmpty {
                Text("No events yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.events) { event in
                    EventRow(event: event)
                }
            }
        } header: {
            Text("Events, newest first")
        }
    }

    @ViewBuilder
    private var logsSection: some View {
        Section {
            switch viewModel.logs {
            case .idle:
                ProgressView()
            case .loaded(let entries) where entries.isEmpty:
                Text("No log entries found.")
                    .foregroundStyle(.secondary)
            case .loaded(let entries):
                ForEach(entries) { entry in
                    LogEntryRow(entry: entry)
                }
            case .failed(let message):
                Text(message)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Recent logs")
        } footer: {
            Text("Last hour, newest first. Pull to refresh. Debug-level messages are usually not kept by the system; use Console.app to see them.")
        }
    }
}

private struct IdentifierRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.monospaced())
                .textSelection(.enabled)
        }
    }
}

private struct EventRow: View {
    let event: DiagnosticsEvent

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(event.name)
                    .font(.headline.monospaced())
                Spacer()
                Text("#\(event.sequence)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Text(event.timestamp, format: .dateTime.hour().minute().second())
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(event.properties) { property in
                Text("\(property.name): \(property.value)")
                    .font(.caption.monospaced())
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        VStack(alignment: .leading) {
            Text("\(entry.date.formatted(.dateTime.hour().minute().second())) · \(entry.category) · \(entry.level)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            Text(entry.message)
                .font(.caption)
        }
        .accessibilityElement(children: .combine)
    }
}
#endif
