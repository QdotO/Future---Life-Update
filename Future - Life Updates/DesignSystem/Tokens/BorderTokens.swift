import Foundation

/// Border width and corner radius tokens
public enum BorderTokens {
    // MARK: - Border Widths
    public static let hairline: CGFloat = 0.5
    public static let thin: CGFloat = 1
    public static let standard: CGFloat = 2
    public static let thick: CGFloat = 3
    public static let extraThick: CGFloat = 4
    
    // MARK: - Corner Radius
    public enum CornerRadius {
        public static let sharp: CGFloat = 0
        public static let minimal: CGFloat = 4
        public static let small: CGFloat = 8
        public static let medium: CGFloat = 12
        public static let large: CGFloat = 16
        public static let xlarge: CGFloat = 24
        public static let circular: CGFloat = 999 // Effectively infinite
    }
}
