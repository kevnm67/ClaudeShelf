import SwiftUI
import UniformTypeIdentifiers

/// The app Settings pane, accessible via the system Preferences menu item.
///
/// Allows the user to configure which directories are scanned for Claude
/// configuration files, add custom directories, and trigger a manual rescan.
struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showFolderPicker = false

    var body: some View {
        Form {
            Section("Scan Locations") {
                ForEach(appState.scanLocations) { location in
                    HStack {
                        Toggle(isOn: bindToggle(for: location.id)) {
                            VStack(alignment: .leading) {
                                Text(location.displayName)
                                    .font(.body)
                                Text(location.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if !location.isDefault {
                            Button(role: .destructive) {
                                appState.removeScanLocation(id: location.id)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button {
                    showFolderPicker = true
                } label: {
                    Label("Add Directory...", systemImage: "plus.circle")
                }
            }

            Section("Status") {
                LabeledContent("Files Found", value: "\(appState.files.count)")
                if let date = appState.lastScanDate {
                    LabeledContent("Last Scan", value: date, format: .dateTime)
                }

                Button {
                    Task {
                        await appState.performScan()
                        await appState.restartFileWatching()
                    }
                } label: {
                    Label("Rescan Now", systemImage: "arrow.clockwise")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 400)
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                if url.startAccessingSecurityScopedResource() {
                    appState.addScanLocation(path: url.path)
                    url.stopAccessingSecurityScopedResource()
                }
            }
        }
    }

    /// Creates a binding for the toggle of a specific scan location.
    ///
    /// When toggled, persists the change and restarts file watching
    /// so the updated locations take effect immediately.
    private func bindToggle(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { appState.scanLocations.first(where: { $0.id == id })?.isEnabled ?? false },
            set: { _ in
                appState.toggleScanLocation(id: id)
                Task {
                    await appState.restartFileWatching()
                }
            }
        )
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
}
