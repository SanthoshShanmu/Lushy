import SwiftUI
import StoreKit
import CoreImage.CIFilterBuiltins

class ProfileSharingViewModel: ObservableObject {
    @Published var userProfile: UserProfile?
    @Published var topProducts: [UserProductSummary] = []
    @Published var userTags: [ProductTag] = []
    @Published var isLoading = false
    
    private let context = CIContext()
    
    func loadProfileData() {
        guard let userId = AuthService.shared.userId else { return }
        
        isLoading = true
        
        // Load user profile
        APIService.shared.fetchUserProfile(userId: userId) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let wrapper):
                    self?.userProfile = wrapper.user
                    self?.topProducts = Array((wrapper.user.products ?? []).prefix(3))
                case .failure(let error):
                    print("Failed to load profile: \(error)")
                }
            }
        }
        
        // Load user tags
        userTags = CoreDataManager.shared.fetchProductTags()
    }
    
    func shareProfileLink(completion: @escaping ([Any]) -> Void) {
        guard let profile = userProfile else { return }
        
        let profileURL = "https://lushy.app/profile/\(profile.username)"
        let shareText = "Check out my beauty journey on Lushy! 💄✨\n\n@\(profile.username) - \(profile.name)\n\(profileURL)"
        
        completion([shareText])
    }
    
    func shareQRCode(completion: @escaping ([Any]) -> Void) {
        guard let profile = userProfile else { return }
        
        let profileURL = "https://lushy.app/profile/\(profile.username)"
        
        if let qrCodeImage = generateQRCode(from: profileURL) {
            let shareText = "Scan this QR code to view my Lushy profile! 💄✨"
            completion([shareText, qrCodeImage])
        } else {
            // Fallback to text sharing
            shareProfileLink(completion: completion)
        }
    }
    
    func inviteFriends(completion: @escaping ([Any]) -> Void) {
        let appURL = "https://apps.apple.com/app/lushy"
        let inviteText = "Hey! 👋 I've been using Lushy to track my beauty products and it's amazing! 💄✨\n\nYou can organize your makeup, skincare, and beauty products, track usage, get expiry reminders, and discover new products.\n\nDownload it here: \(appURL)\n\n#BeautyTracker #Lushy"
        
        completion([inviteText])
    }
    
    func rateApp() {
        // Use new AppStore API for iOS 18+ and fallback for older versions
        if #available(iOS 18.0, *) {
            Task { @MainActor in
                if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                    AppStore.requestReview(in: scene)
                }
            }
        } else {
            // Fallback for iOS 17 and earlier
            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
            }
        }
    }
    
    private func generateQRCode(from string: String) -> UIImage? {
        let data = Data(string.utf8)
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"
        
        if let outputImage = filter.outputImage {
            // Scale up the QR code for better quality
            let scaleX = 200 / outputImage.extent.size.width
            let scaleY = 200 / outputImage.extent.size.height
            let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            
            if let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        
        return nil
    }
}