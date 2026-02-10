import Foundation

/// The output of a completed file scan operation.
struct ScanResult: Sendable {
    /// All Claude configuration files discovered during the scan.
    let files: [FileEntry]

    /// When the scan completed.
    let scanDate: Date

    /// How long the scan took, in seconds.
    let duration: TimeInterval

    /// Non-fatal errors encountered during scanning (e.g., permission denied
    /// on specific directories).
    let errors: [String]
}
