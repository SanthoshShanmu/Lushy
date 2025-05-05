import SwiftUI

struct SplashScreenView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var isAnimated = false
    @State private var showAppIcon = false
    @State private var showAppName = false
    @State private var showLoader = false
    
    // Add completion handler
    var completion: () -> Void
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.lushyPink, Color.lushyPurple]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            
            VStack {
                // App icon with animation
                if showAppIcon {
                    Image("AppLogo") // Make sure this exists in your assets
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 150, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                        .shadow(color: Color.black.opacity(0.2), radius: 10)
                        .scaleEffect(isAnimated ? 1.0 : 0.6)
                        .opacity(isAnimated ? 1.0 : 0)
                        .animation(.spring(response: 0.8, dampingFraction: 0.6), value: isAnimated)
                }
                
                if showAppName {
                    Text("Lushy")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .opacity(isAnimated ? 1.0 : 0.0)
                        .offset(y: isAnimated ? 0 : 20)
                        .animation(.easeInOut(duration: 0.6), value: isAnimated)
                }
                
                // Loading indicator
                if showLoader {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                        .padding(.top, 30)
                        .opacity(isAnimated ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 0.6), value: isAnimated)
                }
            }
        }
        .onAppear {
            // Sequence the animations with slight delays
            withAnimation {
                showAppIcon = true
            }
            
            // Start the animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation {
                    isAnimated = true
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    showAppName = true
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation {
                    showLoader = true
                }
            }
            
            // Complete after animation finishes (total of ~2.5 seconds)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                completion()
            }
        }
    }
}

// Preview provider for SwiftUI canvas
struct SplashScreenView_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreenView {
            // Empty completion for preview
        }
        .environmentObject(AuthManager.shared)
    }
}

struct SplashUIKitWrapper: UIViewControllerRepresentable {
    var onAnimationCompleted: () -> Void
    
    func makeUIViewController(context: Context) -> SplashAnimationViewController {
        let controller = SplashAnimationViewController()
        controller.onAnimationCompleted = onAnimationCompleted
        return controller
    }
    
    func updateUIViewController(_ uiViewController: SplashAnimationViewController, context: Context) {}
}