import Foundation

/// Spacing tokens based on 8pt grid system
public enum SpacingTokens {
    /// Base unit: 8pt grid
    private static let baseUnit: CGFloat = 8
    
    // MARK: - Spacing Scale
    public static let micro: CGFloat = baseUnit * 0.5  // 4pt
    public static let xs: CGFloat = baseUnit           // 8pt
    public static let sm: CGFloat = baseUnit * 1.5     // 12pt
    public static let md: CGFloat = baseUnit * 2       // 16pt
    public static let lg: CGFloat = baseUnit * 3       // 24pt
    public static let xl: CGFloat = baseUnit * 4       // 32pt
    public static let xxl: CGFloat = baseUnit * 6      // 48pt
    public static let xxxl: CGFloat = baseUnit * 8     // 64pt
    
    // MARK: - Semantic Spacing
    public enum Semantic {
        public static let screenEdge: CGFloat = SpacingTokens.md        // 16pt
        public static let cardPadding: CGFloat = SpacingTokens.lg       // 24pt
        public static let sectionSpacing: CGFloat = SpacingTokens.xl    // 32pt
        public static let elementSpacing: CGFloat = SpacingTokens.sm    // 12pt
        public static let tightSpacing: CGFloat = SpacingTokens.xs      // 8pt
        public static let touchTargetMinimum: CGFloat = 44              // iOS HIG minimum
    }
}
