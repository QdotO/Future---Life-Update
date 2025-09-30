import SwiftUI

// MARK: - Platform-Appropriate TextField Styling

extension View {
    /// Applies platform-appropriate TextField styling for better visibility and UX
    /// - On macOS: Adds background and border for clear visibility
    /// - On iOS: Uses plain style as cards provide sufficient context
    func platformAdaptiveTextField() -> some View {
        #if os(macOS)
        self
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
        #else
        self
            .textFieldStyle(.plain)
        #endif
    }
    
    /// Applies minimal platform-appropriate TextField styling for inline contexts
    /// - On macOS: Adds subtle background for visibility
    /// - On iOS: Uses plain style
    func platformMinimalTextField() -> some View {
        #if os(macOS)
        self
            .textFieldStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor).opacity(0.5))
            )
        #else
        self
            .textFieldStyle(.plain)
        #endif
    }
}

// MARK: - macOS-Native TextField Style (Optional Alternative)

#if os(macOS)
struct macOSNativeTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
    }
}

extension TextFieldStyle where Self == macOSNativeTextFieldStyle {
    static var macOSNative: macOSNativeTextFieldStyle {
        macOSNativeTextFieldStyle()
    }
}
#endif
