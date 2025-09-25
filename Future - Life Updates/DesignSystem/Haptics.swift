import UIKit

enum Haptics {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    static func impact(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
