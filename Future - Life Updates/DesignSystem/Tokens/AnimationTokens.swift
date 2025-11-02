import SwiftUI

/// Animation timing and easing tokens
public enum AnimationTokens {
    // MARK: - Duration
    public enum Duration {
        public static let instant: Double = 0.1
        public static let fast: Double = 0.15
        public static let normal: Double = 0.25
        public static let slow: Double = 0.35
        public static let deliberate: Double = 0.5
    }
    
    // MARK: - Easing
    public static let linear = Animation.linear
    public static let easeIn = Animation.easeIn
    public static let easeOut = Animation.easeOut
    public static let easeInOut = Animation.easeInOut
    public static let spring = Animation.spring(response: 0.3, dampingFraction: 0.7)
    
    // MARK: - Common Animations
    public static let buttonPress = Animation.linear(duration: Duration.fast)
    public static let modalPresent = Animation.easeOut(duration: Duration.normal)
    public static let modalDismiss = Animation.easeIn(duration: Duration.fast)
    public static let stateChange = Animation.easeOut(duration: Duration.normal)
    public static let listItem = Animation.easeOut(duration: Duration.fast)
}
