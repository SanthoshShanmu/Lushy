import Foundation
import UserNotifications
import Combine

class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    // Property to track the product ID from the last notification
    @Published var lastOpenedProductId: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        requestNotificationPermission()
    }
    
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
        
        let productName = product.productName ?? "Your product"
        let productId = product.objectID.uriRepresentation().absoluteString
        
        // First handle local notifications
        scheduleLocalNotification(
            identifier: productId,
            title: "Product Expiring Soon",
            body: "\(productName) will expire in 7 days.",
            date: notificationDate
        )
        
        // Then sync with backend if user is authenticated
        syncWithBackendNotifications(product: product, notificationDate: notificationDate)
    }
    
    private func scheduleLocalNotification(identifier: String, title: String, body: String, date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling local notification: \(error)")
            } else {
                print("Local notification scheduled for \(date)")
            }
        }
    }
    
    private func syncWithBackendNotifications(product: UserProduct, notificationDate: Date) {
        // Only sync if user is authenticated
        guard AuthService.shared.isAuthenticated,
              let userId = AuthService.shared.userId else {
            return
        }
        
        // Prepare notification data
        let productId = product.objectID.uriRepresentation().absoluteString
        let productName = product.productName ?? "Product"
        let notificationData: [String: Any] = [
            "productId": productId,
            "userId": userId,
            "title": "\(productName) is expiring soon!",
            "message": "Your \(productName) will expire in 7 days. Consider using it up or getting a replacement.",
            "scheduledFor": notificationDate.timeIntervalSince1970
        ]
        
        // Create API request
        let urlString = "\(APIService.shared.baseURL)/notifications/schedule"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: notificationData)
        } catch {
            print("Error encoding notification data: \(error)")
            return
        }
        
        URLSession.shared.dataTaskPublisher(for: request)
            .map { $0.data }
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Error syncing notification to backend: \(error)")
                }
            }, receiveValue: { _ in
                print("Successfully synced notification with backend")
            })
            .store(in: &cancellables)
    }
    
    // Cancel notification for a specific product
    func cancelNotification(for product: UserProduct) {
        if product.barcode != nil {
            let identifier = product.objectID.uriRepresentation().absoluteString
            
            // Cancel local notification
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
            
            // Cancel backend notification if authenticated
            if AuthService.shared.isAuthenticated,
               let token = AuthService.shared.token {
                let urlString = "\(APIService.shared.baseURL)/notifications/\(identifier)"
                guard let url = URL(string: urlString) else { return }
                
                var request = URLRequest(url: url)
                request.httpMethod = "DELETE"
                request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                
                URLSession.shared.dataTask(with: request) { _, _, _ in
                    print("Notification cancellation request sent to backend")
                }.resume()
            }
        }
    }
}
