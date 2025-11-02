import SwiftUI

// MARK: - Brutalist Card Modifier
public struct BrutalistCardModifier: ViewModifier {
    let borderWidth: CGFloat
    let cornerRadius: CGFloat
    let padding: CGFloat
    
    public init(
        borderWidth: CGFloat = BorderTokens.standard,
        cornerRadius: CGFloat = BorderTokens.CornerRadius.minimal,
        padding: CGFloat = SpacingTokens.Semantic.cardPadding
    ) {
        self.borderWidth = borderWidth
        self.cornerRadius = cornerRadius
        self.padding = padding
    }
    
    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(ColorTokens.Semantic.surfaceBase.color)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(ColorTokens.Semantic.borderDefault.color, lineWidth: borderWidth)
            )
    }
}

// MARK: - Glass Card Modifier
public struct GlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let padding: CGFloat
    
    public init(
        cornerRadius: CGFloat = BorderTokens.CornerRadius.large,
        padding: CGFloat = SpacingTokens.Semantic.cardPadding
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
    }
    
    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(ColorTokens.Glass.border.color, lineWidth: BorderTokens.thin)
            )
            .shadow(
                color: ColorTokens.Glass.shadow.color,
                radius: 20,
                x: 0,
                y: 0
            )
    }
}

// MARK: - View Extensions
extension View {
    /// Apply brutalist card styling
    public func brutalistCard(
        borderWidth: CGFloat = BorderTokens.standard,
        cornerRadius: CGFloat = BorderTokens.CornerRadius.minimal,
        padding: CGFloat = SpacingTokens.Semantic.cardPadding
    ) -> some View {
        modifier(BrutalistCardModifier(borderWidth: borderWidth, cornerRadius: cornerRadius, padding: padding))
    }
    
    /// Apply glass card styling
    public func glassCard(
        cornerRadius: CGFloat = BorderTokens.CornerRadius.large,
        padding: CGFloat = SpacingTokens.Semantic.cardPadding
    ) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}
