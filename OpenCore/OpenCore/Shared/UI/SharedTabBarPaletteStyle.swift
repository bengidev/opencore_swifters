import SwiftUI
import UIKit

/// Applies the monochrome palette to the hosting `UITabBar` instance (not global `appearance()`).
struct SharedTabBarPaletteStyle: UIViewControllerRepresentable {
    let palette: SharedOpenCorePalette

    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.apply(palette: palette)
    }

    final class Controller: UIViewController {
        private var palette: SharedOpenCorePalette?

        func apply(palette: SharedOpenCorePalette) {
            self.palette = palette
            styleTabBarIfNeeded()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            styleTabBarIfNeeded()
        }

        private func styleTabBarIfNeeded() {
            guard let palette else { return }

            DispatchQueue.main.async { [weak self] in
                guard let self, let tabBar = self.findTabBar() else { return }
                Self.style(tabBar: tabBar, palette: palette)
            }
        }

        private func findTabBar() -> UITabBar? {
            if let tabBar = tabBarController?.tabBar {
                return tabBar
            }

            var current: UIViewController? = self
            while let viewController = current {
                if let tabBarController = viewController as? UITabBarController {
                    return tabBarController.tabBar
                }
                if let tabBar = viewController.tabBarController?.tabBar {
                    return tabBar
                }
                current = viewController.parent
            }

            return nil
        }

        private static func style(tabBar: UITabBar, palette: SharedOpenCorePalette) {
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

            tabBar.tintColor = UIColor(palette.textPrimary)
            tabBar.unselectedItemTintColor = UIColor(palette.textTertiary)
            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = appearance
        }
    }
}
