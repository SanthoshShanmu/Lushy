import SwiftUI

// MARK: - Core Color Palette
enum LushyPalette {
    static let pink = Color.lushyPink
    static let purple = Color.lushyPurple
    static let mint = Color.lushyMint
    static let peach = Color.lushyPeach
    static let cream = Color.lushyCream

    static var gradientPrimary: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [pink, purple]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var gradientSecondary: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [mint, peach]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var gradientNeutral: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [cream, Color.white]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Background Modifiers
struct PastelBackground: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            LushyPalette.gradientNeutral
                .ignoresSafeArea()
            content
        }
    }
}

// MARK: - Glassmorphic Card Style
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 20
    var borderOpacity: Double = 0.2

    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(borderOpacity), lineWidth: 1)
            )
    }
}

// MARK: - Neumorphic Button Style
struct NeumorphicButton: ButtonStyle {
    var color: Color = .white
    var cornerRadius: CGFloat = 16
    var depth: CGFloat = 4

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(color)
            .cornerRadius(cornerRadius)
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.1 : 0.2), radius: depth, x: configuration.isPressed ? depth/2 : -depth/2, y: configuration.isPressed ? depth/2 : -depth/2)
            .shadow(color: Color.white.opacity(configuration.isPressed ? 0.7 : 0.8), radius: depth, x: configuration.isPressed ? -depth/2 : depth/2, y: configuration.isPressed ? -depth/2 : depth/2)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

// MARK: - View Extensions
extension View {
    func pastelBackground() -> some View { modifier(PastelBackground()) }
    func glassCard(cornerRadius: CGFloat = 20) -> some View { modifier(GlassCard(cornerRadius: cornerRadius)) }
    func neumorphicButtonStyle() -> some View { buttonStyle(NeumorphicButton()) }
}
