import UIKit
import SwiftUI
import CoreData

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Initialize services first
        let _ = AuthService.shared
        let _ = SyncService.shared
        let _ = NotificationService.shared
        
        // Handle URL context if present
        if let urlContext = connectionOptions.urlContexts.first {
            handleUrl(urlContext.url)
        }
        
        // Handle notification response
        if let response = connectionOptions.notificationResponse {
            handleNotificationResponse(response)
        }
    }
    
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        // Handle universal links
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = userActivity.webpageURL {
            handleUrl(url)
        }
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        // Handle URL schemes
        if let url = URLContexts.first?.url {
            handleUrl(url)
        }
    }
    
    private func handleUrl(_ url: URL) {
        // Parse URL and handle accordingly
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return }
        
        // Handle different paths
        switch components.path {
        case "/product":
            // Extract product info from query parameters
            if let barcode = components.queryItems?.first(where: { $0.name == "barcode" })?.value {
                NotificationCenter.default.post(name: NSNotification.Name("OpenProductDetail"), object: barcode)
            }
        case "/wishlist":
            NotificationCenter.default.post(name: NSNotification.Name("OpenWishlist"), object: nil)
        default:
            break
        }
    }
    
    private func handleNotificationResponse(_ response: UNNotificationResponse) {
        // Extract the product barcode from notification
        let userInfo = response.notification.request.content.userInfo
        if let productId = userInfo["productId"] as? String {
            NotificationService.shared.lastOpenedProductId = productId
        }
    }
}
