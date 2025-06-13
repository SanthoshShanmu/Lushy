import SwiftUI

struct BubblyBackground: View {
    var body: some View {
        ZStack {
            // Main gradient background
            LinearGradient(
                gradient: Gradient(colors: [Color.lushyPink.opacity(0.18), Color.lushyPurple.opacity(0.13), Color.lushyMint.opacity(0.10)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Floating blobs
            BlobShape()
                .fill(Color.lushyPink.opacity(0.22))
                .frame(width: 320, height: 180)
                .offset(x: -80, y: -180)
                .blur(radius: 2)
            BlobShape()
                .fill(Color.lushyPurple.opacity(0.18))
                .frame(width: 180, height: 120)
                .offset(x: 120, y: -100)
                .blur(radius: 1)
            Circle()
                .fill(Color.lushyMint.opacity(0.13))
                .frame(width: 120, height: 120)
                .offset(x: 140, y: 320)
                .blur(radius: 1)
            Circle()
                .fill(Color.lushyPeach.opacity(0.10))
                .frame(width: 80, height: 80)
                .offset(x: -120, y: 320)
                .blur(radius: 1)
        }
    }
}

struct BlobShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.5, y: 0))
        path.addCurve(to: CGPoint(x: rect.width, y: rect.height * 0.3),
                      control1: CGPoint(x: rect.width * 0.8, y: 0),
                      control2: CGPoint(x: rect.width, y: rect.height * 0.1))
        path.addCurve(to: CGPoint(x: rect.width * 0.7, y: rect.height),
                      control1: CGPoint(x: rect.width, y: rect.height * 0.7),
                      control2: CGPoint(x: rect.width * 0.8, y: rect.height))
        path.addCurve(to: CGPoint(x: 0, y: rect.height * 0.7),
                      control1: CGPoint(x: rect.width * 0.4, y: rect.height),
                      control2: CGPoint(x: 0, y: rect.height * 0.9))
        path.addCurve(to: CGPoint(x: rect.width * 0.5, y: 0),
                      control1: CGPoint(x: 0, y: rect.height * 0.4),
                      control2: CGPoint(x: rect.width * 0.2, y: 0))
        path.closeSubpath()
        return path
    }
}

struct BubblyCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(
                ZStack {
                    // Glassmorphism effect
                    BlurView(style: .systemUltraThinMaterial)
                        .clipShape(BlobShape())
                    BlobShape()
                        .stroke(Color.lushyPink.opacity(0.13), lineWidth: 2)
                }
            )
            .clipShape(BlobShape())
            .shadow(color: Color.lushyPink.opacity(0.10), radius: 12, x: 0, y: 6)
    }
}

extension View {
    func bubblyCard() -> some View {
        self.modifier(BubblyCard())
    }
}

// UIKit blur wrapper for glassmorphism
struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}
