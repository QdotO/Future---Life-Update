#if canImport(UIKit)
import UIKit
#endif

enum Haptics {
    static func selection() {
        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    static func success() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }

    static func warning() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        #endif
    }

    static func error() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        #endif
    }

    #if os(iOS)
    static func impact(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    #else
    static func impact(style: Int = 0) {
        // No-op on non-iOS platforms
    }
    #endif
}
