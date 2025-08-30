import SwiftUI
import CoreImage.CIFilterBuiltins

struct ProfileShareOptionsView: View {
    @ObservedObject var viewModel: ProfileSharingViewModel
    @Environment(\.presentationMode) var presentationMode
    let onShare: ([Any]) -> Void
    
    @State private var showingProfileCard = false
    @State private var profileCardImage: UIImage?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.lushyPink.opacity(0.05),
                        Color.lushyPurple.opacity(0.03),
                        Color.white
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Profile preview card
                        if let userProfile = viewModel.userProfile {
                            ProfileShareCardView(
                                profile: userProfile,
                                topProducts: viewModel.topProducts,
                                userTags: viewModel.userTags
                            )
                            .padding(.horizontal, 20)
                            .onAppear {
                                generateProfileCardImage()
                            }
                        }
                        
                        // Sharing options
                        VStack(spacing: 16) {
                            Text("Choose sharing format")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .padding(.top, 20)
                            
                            // Share as Link
                            ShareFormatCard(
                                icon: "link",
                                title: "Share Link",
                                subtitle: "Share a link to your profile",
                                color: .lushyPink,
                                action: {
                                    viewModel.shareProfileLink { items in
                                        onShare(items)
                                        presentationMode.wrappedValue.dismiss()
                                    }
                                }
                            )
                            
                            // Share as Image
                            ShareFormatCard(
                                icon: "photo",
                                title: "Share Image",
                                subtitle: "Share your profile as an image",
                                color: .lushyPurple,
                                action: {
                                    if let image = profileCardImage {
                                        onShare([image])
                                        presentationMode.wrappedValue.dismiss()
                                    }
                                }
                            )
                            
                            // Share QR Code
                            ShareFormatCard(
                                icon: "qrcode",
                                title: "Share QR Code",
                                subtitle: "Generate a QR code for your profile",
                                color: .mossGreen,
                                action: {
                                    viewModel.shareQRCode { items in
                                        onShare(items)
                                        presentationMode.wrappedValue.dismiss()
                                    }
                                }
                            )
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Share Profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Back") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .onAppear {
            viewModel.loadProfileData()
        }
    }
    
    private func generateProfileCardImage() {
        // Generate an image from the profile card view
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let userProfile = viewModel.userProfile {
                let cardView = ProfileShareCardView(
                    profile: userProfile,
                    topProducts: viewModel.topProducts,
                    userTags: viewModel.userTags
                )
                .frame(width: 320, height: 500)
                
                let renderer = ImageRenderer(content: cardView)
                if let image = renderer.uiImage {
                    profileCardImage = image
                }
            }
        }
    }
}

struct ShareFormatCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(color)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(color.opacity(0.15))
                    )
                
                // Text content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.8))
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}