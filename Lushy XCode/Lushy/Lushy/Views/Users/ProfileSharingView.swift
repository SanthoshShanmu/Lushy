import SwiftUI
import CoreImage.CIFilterBuiltins

struct ProfileSharingView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel = ProfileSharingViewModel()
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var showingShareOptions = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
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
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 40))
                                .foregroundColor(.lushyPink)
                            Text("Share & Connect")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Text("Share your beauty journey and invite friends")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        
                        // Main sharing options
                        VStack(spacing: 20) {
                            // Share Profile
                            ShareOptionCard(
                                icon: "person.crop.circle.badge.plus",
                                title: "Share Profile",
                                subtitle: "Share your beauty profile with friends",
                                color: .lushyPink,
                                action: {
                                    showingShareOptions = true
                                }
                            )
                            
                            // Invite Friends
                            ShareOptionCard(
                                icon: "person.2.badge.plus",
                                title: "Invite Friends",
                                subtitle: "Invite friends to join Lushy",
                                color: .lushyPurple,
                                action: {
                                    viewModel.inviteFriends { items in
                                        shareItems = items
                                        showingShareSheet = true
                                    }
                                }
                            )
                            
                            // Rate App
                            ShareOptionCard(
                                icon: "star.fill",
                                title: "Rate Lushy",
                                subtitle: "Rate us on the App Store",
                                color: .mossGreen,
                                action: {
                                    viewModel.rateApp()
                                }
                            )
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
        .sheet(isPresented: $showingShareOptions) {
            ProfileShareOptionsView(viewModel: viewModel) { items in
                shareItems = items
                showingShareSheet = true
            }
        }
    }
}

struct ShareOptionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(color)
                }
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: color.opacity(0.1), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Share sheet wrapper
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ProfileSharingView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileSharingView()
    }
}