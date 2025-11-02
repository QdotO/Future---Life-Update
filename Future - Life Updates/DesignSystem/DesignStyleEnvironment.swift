import SwiftUI

private struct AppDesignStyleKey: EnvironmentKey {
    static let defaultValue: AppTheme.DesignStyle = .liquid
}

extension EnvironmentValues {
    var designStyle: AppTheme.DesignStyle {
        get { self[AppDesignStyleKey.self] }
        set { self[AppDesignStyleKey.self] = newValue }
    }
}

extension View {
    func designStyle(_ style: AppTheme.DesignStyle) -> some View {
        environment(\.designStyle, style)
    }
}
