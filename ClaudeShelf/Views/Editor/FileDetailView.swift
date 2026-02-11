import SwiftUI
import QuickLook
import os

/// Displays a selected Claude configuration file with a metadata header
/// and an editable code editor.
///
/// The metadata header shows the file's name, category, scope, lock status,
/// size, and modification date. Below the header, a ``CodeEditorView`` provides
/// an NSTextView-based editor with line numbers and monospaced font.
/// Content is loaded asynchronously and reloads when the selected file changes.
///
/// Supports saving with Cmd+S (preserving POSIX permissions), dirty state
/// tracking with a visual indicator, read-only detection with a banner,
/// and a diff view for reviewing unsaved changes.
struct FileDetailView: View {
    private static let logger = Logger(subsystem: "com.claudeshelf.app", category: "FileDetailView")

    let file: FileEntry

    @Environment(AppState.self) private var appState

    @State private var fileContent: String = ""
    @State private var originalContent: String = ""
    @State private var isLoaded: Bool = false
    @State private var loadError: String?
    @State private var saveError: String?
    @State private var showDiff: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var deleteError: String?
    @State private var quickLookURL: URL?

    /// Whether the editor content differs from the last saved/loaded version.
    private var isDirty: Bool {
        isLoaded && fileContent != originalContent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - Metadata Header
            headerView
            Divider()

            // MARK: - Read-Only Banner
            if file.isReadOnly {
                readOnlyBanner
                Divider()
            }

            // MARK: - File Content
            contentView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: file.id) {
            isLoaded = false
            loadError = nil
            saveError = nil
            fileContent = ""
            originalContent = ""
            do {
                let url = URL(fileURLWithPath: file.path)
                let content = try String(contentsOf: url, encoding: .utf8)
                fileContent = content
                originalContent = content
                isLoaded = true
            } catch {
                loadError = "Unable to read file contents"
                Self.logger.error("Failed to load file: \(error.localizedDescription, privacy: .public)")
            }
        }
        .alert("Save Error", isPresented: .init(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {
                saveError = nil
            }
        } message: {
            if let errorMessage = saveError {
                Text(errorMessage)
            }
        }
        .sheet(isPresented: $showDiff) {
            DiffView(
                original: originalContent,
                modified: fileContent,
                onSave: {
                    saveFile()
                    showDiff = false
                },
                onCancel: {
                    showDiff = false
                }
            )
        }
        .sheet(isPresented: $showDeleteConfirmation) {
            DeleteConfirmationView(
                files: [file],
                onTrash: {
                    trashCurrentFile()
                    showDeleteConfirmation = false
                },
                onPermanentDelete: {
                    permanentlyDeleteCurrentFile()
                    showDeleteConfirmation = false
                },
                onCancel: {
                    showDeleteConfirmation = false
                }
            )
        }
        .alert("Delete Error", isPresented: .init(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK", role: .cancel) {
                deleteError = nil
            }
        } message: {
            if let errorMessage = deleteError {
                Text(errorMessage)
            }
        }
        .quickLookPreview($quickLookURL)
    }

    // MARK: - Header

    @ViewBuilder
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // File name, lock icon, dirty indicator, and action buttons
            HStack(spacing: 6) {
                Text(file.displayName)
                    .font(.headline)
                    .lineLimit(1)

                if file.isReadOnly {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .help("This file is read-only")
                        .accessibilityLabel("Read-only file")
                }

                if isDirty {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 8, height: 8)
                        .help("Unsaved changes")
                        .accessibilityLabel("Unsaved changes")
                }

                Spacer()

                // Quick Look preview button
                Button {
                    quickLookURL = URL(fileURLWithPath: file.path)
                } label: {
                    Label("Preview", systemImage: "eye")
                }
                .help("Preview file with Quick Look")

                // Action buttons (only for writable files)
                if !file.isReadOnly {
                    if isDirty {
                        Button {
                            showDiff = true
                        } label: {
                            Label("Review Changes", systemImage: "doc.text.magnifyingglass")
                        }
                        .help("Review unsaved changes")

                        Button {
                            saveFile()
                        } label: {
                            Label("Save", systemImage: "square.and.arrow.down")
                        }
                        .keyboardShortcut("s", modifiers: .command)
                        .help("Save file (Cmd+S)")
                    }

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .help("Move to Trash or permanently delete")
                }
            }

            // Badges and metadata row
            HStack(spacing: 12) {
                // Category badge
                Label(file.category.displayName, systemImage: file.category.sfSymbol)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.fill.tertiary, in: Capsule())

                // Scope badge
                Text(scopeLabel)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.fill.tertiary, in: Capsule())

                Spacer()

                // File size
                Text(formattedSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Last modified date
                Text(file.modifiedDate, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    // MARK: - Read-Only Banner

    @ViewBuilder
    private var readOnlyBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.caption)
            Text("This file is read-only")
                .font(.caption)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.quaternary)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        if isLoaded {
            CodeEditorView(text: $fileContent, isEditable: !file.isReadOnly, filename: file.name)
        } else if let error = loadError {
            ContentUnavailableView {
                Label("Cannot Read File", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error)
            }
        } else {
            VStack {
                Spacer()
                ProgressView("Loading...")
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Save

    /// Saves the current editor content to disk, preserving POSIX permissions.
    ///
    /// Delegates to ``FileOperations/saveFile(at:content:)`` which reads the
    /// file's existing permissions before writing, writes content atomically,
    /// then restores the original permissions. On success, updates
    /// ``originalContent`` to match ``fileContent``, clearing the dirty state.
    private func saveFile() {
        do {
            try FileOperations.saveFile(at: file.path, content: fileContent)
            originalContent = fileContent
        } catch {
            saveError = "Unable to save file. Please check permissions and try again."
            Self.logger.error("Failed to save file: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Delete

    /// Moves the current file to Trash and removes it from the app state.
    private func trashCurrentFile() {
        do {
            try FileOperations.trashFile(at: file.path)
            appState.removeFiles([file])
        } catch {
            deleteError = "Unable to move file to Trash. Please check permissions and try again."
            Self.logger.error("Failed to trash file: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Permanently deletes the current file and removes it from the app state.
    private func permanentlyDeleteCurrentFile() {
        do {
            try FileOperations.permanentlyDeleteFile(at: file.path)
            appState.removeFiles([file])
        } catch {
            deleteError = "Unable to delete file. Please check permissions and try again."
            Self.logger.error("Failed to permanently delete file: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Computed Properties

    /// Human-readable scope label showing "Global" or the project name.
    private var scopeLabel: String {
        if let project = file.project {
            return project
        }
        return file.scope == .global ? "Global" : "Project"
    }

    /// File size formatted with ByteCountFormatter.
    private var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file)
    }
}

#Preview("Editable") {
    FileDetailView(
        file: FileEntry(
            id: FileEntry.generateID(from: "/Users/demo/.claude/CLAUDE.md"),
            name: "CLAUDE.md",
            path: "/Users/demo/.claude/CLAUDE.md",
            displayName: "Global Instructions",
            category: .projectConfig,
            scope: .global,
            project: nil,
            size: 2048,
            modifiedDate: Date().addingTimeInterval(-3600),
            isReadOnly: false
        )
    )
    .frame(width: 600, height: 500)
    .environment(AppState())
}

#Preview("Read-Only") {
    FileDetailView(
        file: FileEntry(
            id: FileEntry.generateID(from: "/Users/demo/.claude/settings.json"),
            name: "settings.json",
            path: "/Users/demo/.claude/settings.json",
            displayName: "Global Settings",
            category: .settings,
            scope: .global,
            project: nil,
            size: 512,
            modifiedDate: Date().addingTimeInterval(-7200),
            isReadOnly: true
        )
    )
    .frame(width: 600, height: 500)
    .environment(AppState())
}
