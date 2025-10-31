import SwiftUI

/// Design mode for switching between brutalist, glass, and hybrid aesthetics
public enum DesignMode: String, CaseIterable {
    case brutalist
    case glass
    case hybrid
    
    public var displayName: String {
        switch self {
        case .brutalist: return "Brutalist"
        case .glass: return "Glass"
        case .hybrid: return "Hybrid"
        }
    }
}

// MARK: - Environment Key
private struct DesignModeKey: EnvironmentKey {
    static let defaultValue: DesignMode = .glass
}

extension EnvironmentValues {
    public var designMode: DesignMode {
        get { self[DesignModeKey.self] }
        set { self[DesignModeKey.self] = newValue }
    }
}

extension View {
    /// Apply a design mode to this view and its children
    public func designMode(_ mode: DesignMode) -> some View {
        environment(\.designMode, mode)
    }
}
