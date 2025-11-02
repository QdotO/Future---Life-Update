import SwiftUI

// Shared platform-specific View helpers used across creation/edit flows
extension View {
    @ViewBuilder
    func platformNumericKeyboard() -> some View {
        #if os(iOS)
            self.keyboardType(.decimalPad)
        #else
            self
        #endif
    }

    @ViewBuilder
    func platformTextField() -> some View {
        #if os(iOS)
            self.textFieldStyle(.roundedBorder)
        #else
            self.textFieldStyle(.plain)
        #endif
    }
}
