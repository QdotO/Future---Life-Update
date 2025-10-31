import SwiftUI

/// Example view demonstrating brutalist design system usage
///
/// This file shows how to use the new design system tokens, components, and modifiers
/// in your views. It's not meant to be part of the production code but serves as
/// documentation and reference for developers.
struct DesignSystemExamples: View {
    @State private var selectedDesignMode: DesignMode = .glass
    
    var body: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.lg) {
                // Design Mode Picker
                designModePicker
                
                // Brutalist Components
                brutalistSection
                
                // Glass Components
                glassSection
                
                // Color Tokens
                colorTokensSection
                
                // Spacing Examples
                spacingSection
            }
            .padding(SpacingTokens.md)
        }
        .designMode(selectedDesignMode)
    }
    
    // MARK: - Design Mode Picker
    
    private var designModePicker: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text("Design Mode")
                .font(AppTheme.Typography.sectionHeader)
            
            Picker("Design Mode", selection: $selectedDesignMode) {
                ForEach(DesignMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    // MARK: - Brutalist Section
    
    private var brutalistSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            Text("Brutalist Components")
                .font(AppTheme.Typography.sectionHeader)
            
            // Brutalist Card Example
            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                Text("Brutalist Card")
                    .font(AppTheme.Typography.bodyStrong)
                Text("Hard edges, bold borders, high contrast")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(ColorTokens.Semantic.foregroundSecondary.color)
            }
            .brutalistCard()
            
            // Brutalist Buttons
            Button("Primary Brutalist Button") {
                print("Tapped")
            }
            .buttonStyle(.brutalistPrimary)
            
            Button("Secondary Brutalist Button") {
                print("Tapped")
            }
            .buttonStyle(.brutalistSecondary)
        }
    }
    
    // MARK: - Glass Section
    
    private var glassSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            Text("Glass Components")
                .font(AppTheme.Typography.sectionHeader)
            
            // Glass Card Example
            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                Text("Glass Card")
                    .font(AppTheme.Typography.bodyStrong)
                Text("Soft edges, translucent material, subtle glow")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .glassCard()
            
            // Standard Buttons
            Button("Primary Glass Button") {
                print("Tapped")
            }
            .buttonStyle(.primaryProminent)
            
            Button("Secondary Glass Button") {
                print("Tapped")
            }
            .buttonStyle(.secondaryProminent)
        }
    }
    
    // MARK: - Color Tokens
    
    private var colorTokensSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            Text("Color Tokens")
                .font(AppTheme.Typography.sectionHeader)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: SpacingTokens.sm) {
                colorSwatch("Primary", ColorTokens.Accent.primary.color)
                colorSwatch("Red", ColorTokens.Accent.red.color)
                colorSwatch("Blue", ColorTokens.Accent.blue.color)
                colorSwatch("Green", ColorTokens.Accent.green.color)
                colorSwatch("Yellow", ColorTokens.Accent.yellow.color)
                colorSwatch("Orange", ColorTokens.Accent.orange.color)
            }
        }
    }
    
    private func colorSwatch(_ name: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(height: 60)
            Text(name)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Spacing Examples
    
    private var spacingSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            Text("Spacing Scale (8pt grid)")
                .font(AppTheme.Typography.sectionHeader)
            
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                spacingBar("Micro (4pt)", width: SpacingTokens.micro)
                spacingBar("XS (8pt)", width: SpacingTokens.xs)
                spacingBar("SM (12pt)", width: SpacingTokens.sm)
                spacingBar("MD (16pt)", width: SpacingTokens.md)
                spacingBar("LG (24pt)", width: SpacingTokens.lg)
                spacingBar("XL (32pt)", width: SpacingTokens.xl)
                spacingBar("XXL (48pt)", width: SpacingTokens.xxl)
            }
        }
    }
    
    private func spacingBar(_ label: String, width: CGFloat) -> some View {
        HStack(spacing: SpacingTokens.sm) {
            Text(label)
                .font(.caption2)
                .frame(width: 80, alignment: .leading)
            Rectangle()
                .fill(ColorTokens.Accent.primary.color)
                .frame(width: width * 4, height: 8) // Scaled for visibility
        }
    }
}

// MARK: - Preview

#Preview("Design System Examples") {
    DesignSystemExamples()
}

#Preview("Brutalist Mode") {
    DesignSystemExamples()
        .designMode(.brutalist)
}

#Preview("Glass Mode") {
    DesignSystemExamples()
        .designMode(.glass)
}
