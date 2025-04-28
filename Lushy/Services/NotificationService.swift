import Foundation
import UserNotifications
import Combine

class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    // Property to track the product ID from the last notification
    @Published var lastOpenedProductId: String?
    
    private init() {}
    
    // Request permission for notifications
    func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Error requesting notification permission: \(error.localizedDescription)")
            }
        }
    }
    
    // Schedule expiry notification
    func scheduleExpiryNotification(for product: UserProduct) {
        guard let expireDate = product.expireDate else {
            print("No expiry date for product")
            return
        }
        
        // Schedule notification 7 days before expiry
        let notificationDate = Calendar.current.date(byAdding: .day, value: -7, to: expireDate)
        
        guard let notificationDate = notificationDate, notificationDate > Date() else {
            print("Notification date is in the past")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Product Expiring Soon"
        content.body = "\(product.productName ?? "Your product") will expire soon. Time to consider a replacement!"
        content.sound = .default
        
        // Add product ID to the notification
        content.userInfo = ["productId": product.barcode ?? ""]
        
        // Create trigger based on date
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: notificationDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        // Create request with a unique identifier
        let identifier = "expiry-\(product.barcode ?? UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        // Add request to notification center
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("Expiry notification scheduled for \(notificationDate)")
            }
        }
    }
    
    // Cancel notification for a specific product
    func cancelNotification(for product: UserProduct) {
        guard let barcode = product.barcode else { return }
        
        let identifier = "expiry-\(barcode)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}