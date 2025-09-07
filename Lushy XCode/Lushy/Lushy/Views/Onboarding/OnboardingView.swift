import SwiftUI

struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    @State private var currentPage = 0
    @State private var animateContent = false
    @State private var showFloatingElements = false
    @State private var showSwipeHint = true
    
    let onboardingPages = [
        OnboardingPage(
            title: "Welcome to Lushy!",
            subtitle: "Your personal beauty journey starts here",
            description: "Track, organize, and discover your beauty products like never before",
            imageName: "sparkles.rectangle.stack.fill",
            gradientColors: [.lushyPink, .lushyPurple],
            animationType: .sparkle
        ),
        OnboardingPage(
            title: "Scan & Discover",
            subtitle: "Quick product entry",
            description: "Simply scan barcodes or manually add products to build your personalized beauty collection",
            imageName: "barcode.viewfinder",
            gradientColors: [.lushyPurple, .mossGreen],
            animationType: .scan
        ),
        OnboardingPage(
            title: "Organize with Beauty Bags",
            subtitle: "Your collections, your way",
            description: "Create custom beauty bags to organize products by routine, season, or any way you like",
            imageName: "bag.fill",
            gradientColors: [.mossGreen, .lushyPeach],
            animationType: .bounce
        ),
        OnboardingPage(
            title: "Track Your Journey",
            subtitle: "Never miss an expiry date",
            description: "Monitor usage, track expiry dates, and get smart insights about your beauty habits",
            imageName: "chart.bar.fill",
            gradientColors: [.lushyPeach, .lushyPink],
            animationType: .pulse
        ),
        OnboardingPage(
            title: "Connect & Share",
            subtitle: "Beauty community",
            description: "Follow friends, discover new products, and share your beauty journey with the community",
            imageName: "person.3.fill",
            gradientColors: [.lushyPink, .lushyPurple],
            animationType: .wave
        )
    ]
    
    var body: some View {
        ZStack {
            // Dynamic background gradient
            LinearGradient(
                gradient: Gradient(colors: onboardingPages[currentPage].gradientColors),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.8), value: currentPage)
            
            // Floating decorative elements
            if showFloatingElements {
                ForEach(0..<6, id: \.self) { index in
                    FloatingElement(
                        delay: Double(index) * 0.3,
                        duration: 3.0 + Double(index) * 0.5
                    )
                }
            }
            
            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button("Skip") {
                        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                        withAnimation(.spring()) {
                            showOnboarding = false
                        }
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.8))
                    .padding()
                }
                
                Spacer()
                
                // Main content area with swipe gesture
                TabView(selection: $currentPage) {
                    ForEach(0..<onboardingPages.count, id: \.self) { index in
                        OnboardingPageView(
                            page: onboardingPages[index],
                            animateContent: animateContent
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.6), value: currentPage)
                .onChange(of: currentPage) { _, _ in
                    // Reset animations when page changes
                    animateContent = false
                    showSwipeHint = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        animateContent = true
                    }
                }
                
                // Swipe hint for first page
                if currentPage == 0 && showSwipeHint {
                    HStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Text("Swipe to continue")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                                .offset(x: animateContent ? 5 : 0)
                                .animation(
                                    .easeInOut(duration: 1.0)
                                    .repeatForever(autoreverses: true),
                                    value: animateContent
                                )
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.2))
                        )
                        .opacity(showSwipeHint ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 0.5).delay(2.0), value: showSwipeHint)
                        Spacer()
                    }
                    .padding(.top, 10)
                }
                
                Spacer()
                
                // Bottom controls
                VStack(spacing: 24) {
                    // Page indicator
                    HStack(spacing: 8) {
                        ForEach(0..<onboardingPages.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? Color.white : Color.white.opacity(0.4))
                                .frame(width: index == currentPage ? 12 : 8, height: index == currentPage ? 12 : 8)
                                .scaleEffect(index == currentPage ? 1.2 : 1.0)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: currentPage)
                        }
                    }
                    .padding(.bottom, 8)
                    
                    // Action button
                    Button(action: {
                        if currentPage < onboardingPages.count - 1 {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                currentPage += 1
                                animateContent = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    animateContent = true
                                }
                            }
                        } else {
                            // Mark onboarding as completed and close
                            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                            withAnimation(.spring()) {
                                showOnboarding = false
                            }
                        }
                    }) {
                        HStack {
                            Text(currentPage < onboardingPages.count - 1 ? "Continue" : "Get Started")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            if currentPage < onboardingPages.count - 1 {
                                Image(systemName: "arrow.right")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                        .foregroundColor(onboardingPages[currentPage].gradientColors[0])
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                        )
                    }
                    .scaleEffect(animateContent ? 1.0 : 0.9)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateContent)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            animateContent = true
            showFloatingElements = true
            // Hide swipe hint after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                withAnimation(.easeOut(duration: 0.5)) {
                    showSwipeHint = false
                }
            }
        }
    }
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    let animateContent: Bool
    
    var body: some View {
        VStack(spacing: 32) {
            // Icon with animation
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 140, height: 140)
                    .scaleEffect(animateContent ? 1.0 : 0.8)
                    .opacity(animateContent ? 1.0 : 0.0)
                
                Image(systemName: page.imageName)
                    .font(.system(size: 60, weight: .medium))
                    .foregroundColor(.white)
                    .scaleEffect(animateContent ? 1.0 : 0.5)
                    .rotationEffect(.degrees(animateContent ? 0 : -10))
                    .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2), value: animateContent)
                
                // Add specific animations based on type
                if animateContent {
                    switch page.animationType {
                    case .sparkle:
                        ForEach(0..<3, id: \.self) { index in
                            Image(systemName: "sparkle")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                                .offset(
                                    x: [30, -30, 0][index],
                                    y: [-30, 30, -45][index]
                                )
                                .scaleEffect(animateContent ? 1.0 : 0.0)
                                .animation(.spring().delay(Double(index) * 0.1 + 0.5), value: animateContent)
                        }
                    case .scan:
                        // Removed scan line animation - just show clean icon
                        EmptyView()
                    case .bounce:
                        // Removed bouncing dot animation - just show clean icon
                        EmptyView()
                    case .pulse:
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            .frame(width: 160, height: 160)
                            .scaleEffect(animateContent ? 1.2 : 1.0)
                            .opacity(animateContent ? 0.0 : 1.0)
                            .animation(.easeOut(duration: 2.0).repeatForever(autoreverses: false), value: animateContent)
                    case .wave:
                        // Removed wave dots animation - just show clean icon
                        EmptyView()
                    }
                }
            }
            .animation(.spring(response: 0.8, dampingFraction: 0.6), value: animateContent)
            
            // Text content
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .offset(y: animateContent ? 0 : 20)
                    .opacity(animateContent ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.6).delay(0.3), value: animateContent)
                
                Text(page.subtitle)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .offset(y: animateContent ? 0 : 20)
                    .opacity(animateContent ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.6).delay(0.4), value: animateContent)
                
                Text(page.description)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 20)
                    .offset(y: animateContent ? 0 : 20)
                    .opacity(animateContent ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.6).delay(0.5), value: animateContent)
            }
        }
        .padding(.horizontal, 32)
    }
}

struct FloatingElement: View {
    let delay: Double
    let duration: Double
    @State private var animate = false
    
    var body: some View {
        Image(systemName: ["sparkle", "heart.fill", "star.fill"].randomElement() ?? "sparkle")
            .font(.caption)
            .foregroundColor(.white.opacity(0.3))
            .offset(
                x: animate ? CGFloat.random(in: -150...150) : CGFloat.random(in: -50...50),
                y: animate ? CGFloat.random(in: -200...200) : CGFloat.random(in: -100...100)
            )
            .scaleEffect(animate ? 0.5 : 1.0)
            .opacity(animate ? 0.0 : 1.0)
            .animation(
                .easeInOut(duration: duration)
                .repeatForever(autoreverses: true)
                .delay(delay),
                value: animate
            )
            .onAppear {
                animate = true
            }
    }
}

struct OnboardingPage {
    let title: String
    let subtitle: String
    let description: String
    let imageName: String
    let gradientColors: [Color]
    let animationType: AnimationType
    
    enum AnimationType {
        case sparkle, scan, bounce, pulse, wave
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(showOnboarding: .constant(true))
    }
}