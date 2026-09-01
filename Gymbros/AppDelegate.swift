import GoogleSignIn
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        GoogleCredentialProvider.configure()
        // Rehydrate any prior Google session held in the keychain. Harmless if
        // there is none; Supabase remains the source of truth for our session.
        if AppConstants.GoogleSignIn.isConfigured {
            GIDSignIn.sharedInstance.restorePreviousSignIn()
        }

        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run {
            DeepLinkCoordinator.shared.handleNotificationUserInfo(
                response.notification.request.content.userInfo
            )
        }
    }
}
