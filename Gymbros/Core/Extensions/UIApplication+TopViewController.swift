import UIKit

extension UIApplication {
    /// The view controller to present system sheets from (Google Sign-In, etc.).
    ///
    /// Walks the key window's root and follows presented / nav / tab / split
    /// containers to whatever is actually on screen.
    @MainActor
    var topViewController: UIViewController? {
        let keyWindow = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }

        return keyWindow?.rootViewController.map(Self.topMost(of:))
    }

    @MainActor
    private static func topMost(of viewController: UIViewController) -> UIViewController {
        if let presented = viewController.presentedViewController {
            return topMost(of: presented)
        }
        if let nav = viewController as? UINavigationController,
           let visible = nav.visibleViewController {
            return topMost(of: visible)
        }
        if let tab = viewController as? UITabBarController,
           let selected = tab.selectedViewController {
            return topMost(of: selected)
        }
        if let split = viewController as? UISplitViewController,
           let last = split.viewControllers.last {
            return topMost(of: last)
        }
        return viewController
    }
}
