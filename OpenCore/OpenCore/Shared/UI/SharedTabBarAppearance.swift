import SwiftUI
import UIKit

/// Applies OpenCore's monochrome palette to the system tab bar.
@MainActor
enum SharedTabBarAppearance {
    static func apply(palette: SharedOpenCorePalette) {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        let item = UITabBarItemAppearance()
        item.normal.iconColor = UIColor(palette.textTertiary)
        item.normal.titleTextAttributes = [.foregroundColor: UIColor(palette.textTertiary)]
        item.selected.iconColor = UIColor(palette.textPrimary)
        item.selected.titleTextAttributes = [.foregroundColor: UIColor(palette.textPrimary)]

        appearance.stackedLayoutAppearance = item
        appearance.inlineLayoutAppearance = item
        appearance.compactInlineLayoutAppearance = item
        appearance.selectionIndicatorTintColor = UIColor(palette.surfaceSubtle)

        let tabBar = UITabBar.appearance()
        tabBar.tintColor = UIColor(palette.textPrimary)
        tabBar.unselectedItemTintColor = UIColor(palette.textTertiary)
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
    }
}
