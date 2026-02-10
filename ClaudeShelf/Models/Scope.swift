import Foundation

/// Whether a Claude configuration file is global (user-level) or
/// project-scoped.
enum Scope: String, Sendable, Codable {
    case global
    case project
}
