import Foundation
import os

/// Exports Claude configuration files as a zip archive.
enum ExportService {
    private static let logger = Logger(subsystem: "com.claudeshelf.app", category: "ExportService")

    /// Creates a zip archive of the given files at the destination path.
    ///
    /// Files are staged in a temporary directory with collision-safe naming
    /// (prefixed with project name if available). Uses `/usr/bin/ditto` for
    /// zip creation (no external dependencies required).
    ///
    /// - Parameters:
    ///   - files: The files to include in the archive.
    ///   - destination: The path where the zip file will be created.
    /// - Throws: If staging or zip creation fails.
    static func exportAsZip(files: [FileEntry], to destination: String) async throws {
        guard !files.isEmpty else {
            throw ExportError.noFiles
        }

        let fm = FileManager.default
        let stagingDir = fm.temporaryDirectory.appendingPathComponent(
            "ClaudeShelf-export-\(UUID().uuidString)"
        )

        defer {
            try? fm.removeItem(at: stagingDir)
        }

        try fm.createDirectory(at: stagingDir, withIntermediateDirectories: true)

        // Stage files with collision-safe naming
        var usedNames = Set<String>()
        for file in files {
            var name = file.name
            if let project = file.project {
                name = "\(project)_\(name)"
            }

            // Handle name collisions
            var finalName = name
            var counter = 1
            while usedNames.contains(finalName) {
                let ext = (name as NSString).pathExtension
                let base = (name as NSString).deletingPathExtension
                finalName = ext.isEmpty ? "\(base)_\(counter)" : "\(base)_\(counter).\(ext)"
                counter += 1
            }
            usedNames.insert(finalName)

            let source = URL(fileURLWithPath: file.path)
            let dest = stagingDir.appendingPathComponent(finalName)
            try fm.copyItem(at: source, to: dest)
        }

        // Create zip using ditto
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--sequesterRsrc", stagingDir.path, destination]

        let pipe = Pipe()
        process.standardError = pipe

        try process.run()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                    let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    logger.error("ditto failed: \(errorMsg, privacy: .public)")
                    continuation.resume(throwing: ExportError.zipCreationFailed)
                }
            }
        }

        logger.info("Exported \(files.count) files to zip archive")
    }

    /// Generates a default filename for the export archive.
    static func defaultFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "ClaudeShelf-export-\(formatter.string(from: Date())).zip"
    }

    enum ExportError: LocalizedError {
        case noFiles
        case zipCreationFailed

        var errorDescription: String? {
            switch self {
            case .noFiles:
                return "No files selected for export."
            case .zipCreationFailed:
                return "Failed to create the zip archive. Please try again."
            }
        }
    }
}
