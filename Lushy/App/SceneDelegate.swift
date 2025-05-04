import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Create the SwiftUI view that provides the window contents
        let contentView = ContentView()
                        .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)
        
        // Use a UIHostingController as window root view controller
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIHostingController(rootView: contentView)
            self.window = window
            window.makeKeyAndVisible()
        }
        
        // Handle any URL context that was passed to the app on launch
        if let userActivity = connectionOptions.userActivities.first ?? session.stateRestorationActivity {
            self.scene(scene, continue: userActivity)
        }
        
        // Handle URL if the app was launched from a URL
        if let url = connectionOptions.urlContexts.first?.url {
            handleURL(url)
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
            handleURL(url)
        }
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        // Handle URL schemes
        if let url = URLContexts.first?.url {
            handleURL(url)
        }
    }
    
    private func handleURL(_ url: URL) {
        // Here you would parse the URL to extract information
        // For example, if it's a deep link to a product
        guard url.scheme == "lushy" else { return }
        
        // Example: lushy://product/BARCODE
        if url.host == "product", 
           let barcode = url.pathComponents.last,
           !barcode.isEmpty {
            // Find the root view controller
            if let rootViewController = window?.rootViewController,
               let tabBarController = rootViewController.children.first as? UITabBarController {
                // Switch to the home tab
                tabBarController.selectedIndex = 0
                
                // Post notification to navigate to the specific product
                NotificationCenter.default.post(name: Notification.Name("NavigateToProduct"), object: nil, userInfo: ["barcode": barcode])
            }
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
