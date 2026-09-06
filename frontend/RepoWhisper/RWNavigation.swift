import Foundation

enum RWNavigation: Int, CaseIterable, Identifiable {
    case search
    case repositories
    case indexing
    case live
    case settings

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .search: "Ask"
        case .repositories: "Repositories"
        case .indexing: "Indexing"
        case .live: "Live Assist"
        case .settings: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .search: "sparkles"
        case .repositories: "folder"
        case .indexing: "arrow.triangle.2.circlepath"
        case .live: "waveform"
        case .settings: "slider.horizontal.3"
        }
    }
}
