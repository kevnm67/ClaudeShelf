import Foundation

/// The 9 categories used to classify Claude configuration files.
/// Categories are assigned by priority (lower number = higher priority)
/// during file scanning.
enum Category: String, CaseIterable, Identifiable, Sendable, Codable {
    case agents
    case debug
    case memory
    case projectConfig
    case settings
    case todos
    case plans
    case skills
    case other

    var id: String { rawValue }

    /// Human-readable display name for the category.
    var displayName: String {
        switch self {
        case .agents: "Agents"
        case .debug: "Debug"
        case .memory: "Memory"
        case .projectConfig: "Project Config"
        case .settings: "Settings"
        case .todos: "Todos"
        case .plans: "Plans"
        case .skills: "Skills"
        case .other: "Other"
        }
    }

    /// SF Symbol name for use in the sidebar and category lists.
    var sfSymbol: String {
        switch self {
        case .agents: "person.2"
        case .debug: "ladybug"
        case .memory: "brain"
        case .projectConfig: "doc.text"
        case .settings: "gearshape"
        case .todos: "checklist"
        case .plans: "map"
        case .skills: "star"
        case .other: "folder"
        }
    }

    /// Assignment priority during scanning. Lower number = higher priority.
    /// When a file could match multiple categories, the one with the
    /// lowest priority value wins.
    var priority: Int {
        switch self {
        case .agents: 1
        case .debug: 2
        case .memory: 3
        case .projectConfig: 4
        case .settings: 5
        case .todos: 6
        case .plans: 7
        case .skills: 8
        case .other: 9
        }
    }
}
