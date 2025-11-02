import SwiftUI

#if os(iOS)
    import UIKit

    /// Applies brutalist-inspired styling to UIKit navigation surfaces that wrap SwiftUI stacks and tab views.
    enum BrutalistNavigationAppearance {
        static func apply() {
            configureTabBar()
            configureNavigationBar()
            configureToolBar()
        }

        private static func configureTabBar() {
            let backgroundColor = UIColor(AppTheme.BrutalistPalette.background)
            let foregroundColor = UIColor(AppTheme.BrutalistPalette.foreground)
            let accentColor = UIColor(AppTheme.BrutalistPalette.accent)
            let borderColor = UIColor(AppTheme.BrutalistPalette.border)

            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = backgroundColor
            appearance.shadowImage = borderImage(
                color: borderColor, height: AppTheme.BrutalistBorder.standard)
            appearance.shadowColor = borderColor

            configure(
                tabItemAppearance: appearance.stackedLayoutAppearance, foreground: foregroundColor,
                accent: accentColor)
            configure(
                tabItemAppearance: appearance.inlineLayoutAppearance, foreground: foregroundColor,
                accent: accentColor)
            configure(
                tabItemAppearance: appearance.compactInlineLayoutAppearance,
                foreground: foregroundColor, accent: accentColor)

            UITabBar.appearance().standardAppearance = appearance
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = appearance
            }
            UITabBar.appearance().tintColor = accentColor
            UITabBar.appearance().unselectedItemTintColor = foregroundColor
        }

        private static func configure(
            tabItemAppearance: UITabBarItemAppearance, foreground: UIColor, accent: UIColor
        ) {
            tabItemAppearance.normal.iconColor = foreground
            tabItemAppearance.selected.iconColor = accent

            let baseAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .semibold),
                .kern: 0.75,
            ]

            tabItemAppearance.normal.titleTextAttributes = baseAttributes.merging([
                .foregroundColor: foreground
            ]) { $1 }

            tabItemAppearance.selected.titleTextAttributes = baseAttributes.merging([
                .foregroundColor: accent
            ]) { $1 }
        }

        private static func configureNavigationBar() {
            let backgroundColor = UIColor(AppTheme.BrutalistPalette.background)
            let foregroundColor = UIColor(AppTheme.BrutalistPalette.foreground)
            let accentColor = UIColor(AppTheme.BrutalistPalette.accent)
            let borderColor = UIColor(AppTheme.BrutalistPalette.border)

            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = backgroundColor
            appearance.shadowImage = borderImage(
                color: borderColor, height: AppTheme.BrutalistBorder.standard)
            appearance.shadowColor = borderColor

            appearance.titleTextAttributes = [
                .font: UIFont.monospacedSystemFont(ofSize: 17, weight: .semibold),
                .foregroundColor: foregroundColor,
                .kern: 0.5,
            ]

            appearance.largeTitleTextAttributes = [
                .font: UIFont.monospacedSystemFont(ofSize: 28, weight: .bold),
                .foregroundColor: foregroundColor,
                .kern: 0.4,
            ]

            let buttonAppearance = UIBarButtonItemAppearance(style: .plain)
            buttonAppearance.normal.titleTextAttributes = [
                .font: UIFont.monospacedSystemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: foregroundColor,
                .kern: 0.4,
            ]
            buttonAppearance.highlighted.titleTextAttributes = [
                .font: UIFont.monospacedSystemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: accentColor,
                .kern: 0.4,
            ]
            appearance.buttonAppearance = buttonAppearance
            appearance.doneButtonAppearance = buttonAppearance
            appearance.backButtonAppearance = buttonAppearance

            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
            if #available(iOS 16.0, *) {
                UINavigationBar.appearance().compactScrollEdgeAppearance = appearance
            }
            UINavigationBar.appearance().tintColor = accentColor
        }

        private static func configureToolBar() {
            let backgroundColor = UIColor(AppTheme.BrutalistPalette.background)
            let borderColor = UIColor(AppTheme.BrutalistPalette.border)

            let appearance = UIToolbarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = backgroundColor
            appearance.shadowImage = borderImage(
                color: borderColor, height: AppTheme.BrutalistBorder.standard)
            appearance.shadowColor = borderColor

            UIToolbar.appearance().standardAppearance = appearance
            if #available(iOS 15.0, *) {
                UIToolbar.appearance().compactAppearance = appearance
                UIToolbar.appearance().scrollEdgeAppearance = appearance
            }
        }

        private static func borderImage(color: UIColor, height: CGFloat) -> UIImage {
            let size = CGSize(width: 1, height: height)
            UIGraphicsBeginImageContextWithOptions(size, false, 0)
            defer { UIGraphicsEndImageContext() }

            color.setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
            return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        }
    }

#endif
