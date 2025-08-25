import SwiftUI

// MARK: - Enhanced Lushy Button Styles

struct LushyButtonStyle: ButtonStyle {
    var variant: ButtonVariant = .primary
    var size: ButtonSize = .medium
    
    enum ButtonVariant {
        case primary, secondary, accent, outline, destructive
    }
    
    enum ButtonSize {
        case small, medium, large
        
        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
            case .medium: return EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
            case .large: return EdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24)
            }
        }
        
        var fontSize: CGFloat {
            switch self {
            case .small: return 14
            case .medium: return 16
            case .large: return 18
            }
        }
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size.fontSize, weight: .semibold, design: .rounded))
            .foregroundColor(foregroundColor)
            .padding(size.padding)
            .background(backgroundGradient)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(borderGradient, lineWidth: borderWidth)
            )
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowOffsetY)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
    
    private var foregroundColor: Color {
        switch variant {
        case .primary, .accent, .destructive: return .white
        case .secondary: return .lushyPurple
        case .outline: return .lushyPink
        }
    }
    
    private var backgroundGradient: LinearGradient {
        switch variant {
        case .primary:
            return LinearGradient(
                gradient: Gradient(colors: [Color.lushyPink, Color.lushyPurple.opacity(0.8)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .secondary:
            return LinearGradient(
                gradient: Gradient(colors: [Color.lushyCream, Color.white.opacity(0.8)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .accent:
            return LinearGradient(
                gradient: Gradient(colors: [Color.mossGreen, Color.lushyPeach.opacity(0.8)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .outline:
            return LinearGradient(
                gradient: Gradient(colors: [Color.clear]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .destructive:
            return LinearGradient(
                gradient: Gradient(colors: [Color.red.opacity(0.8), Color.pink.opacity(0.6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var borderGradient: LinearGradient {
        switch variant {
        case .outline:
            return LinearGradient(
                gradient: Gradient(colors: [Color.lushyPink, Color.lushyPurple.opacity(0.8)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                gradient: Gradient(colors: [Color.white.opacity(0.3)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var borderWidth: CGFloat {
        variant == .outline ? 2 : 1
    }
    
    private var shadowColor: Color {
        switch variant {
        case .primary: return Color.lushyPink.opacity(0.4)
        case .secondary: return Color.lushyCream.opacity(0.3)
        case .accent: return Color.mossGreen.opacity(0.4)
        case .outline: return Color.lushyPink.opacity(0.2)
        case .destructive: return Color.red.opacity(0.3)
        }
    }
    
    private var shadowRadius: CGFloat {
        switch size {
        case .small: return 6
        case .medium: return 8
        case .large: return 10
        }
    }
    
    private var shadowOffsetY: CGFloat {
        switch size {
        case .small: return 3
        case .medium: return 4
        case .large: return 5
        }
    }
}

// MARK: - Floating Action Button Style

struct FloatingActionButtonStyle: ButtonStyle {
    var color: Color = .lushyPink
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 56, height: 56)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [color, color.opacity(0.8)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: color.opacity(0.4), radius: 12, x: 0, y: 6)
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Icon Button Style

struct IconButtonStyle: ButtonStyle {
    var size: CGFloat = 44
    var backgroundColor: Color = Color.lushyPink.opacity(0.1)
    var foregroundColor: Color = .lushyPink
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.4, weight: .medium))
            .foregroundColor(foregroundColor)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(backgroundColor)
                    .overlay(
                        Circle()
                            .stroke(foregroundColor.opacity(0.2), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Tag Button Style

struct TagButtonStyle: ButtonStyle {
    var isSelected: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundColor(isSelected ? .white : .lushyPurple)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(
                        isSelected ?
                        LinearGradient(
                            gradient: Gradient(colors: [Color.lushyPink, Color.lushyPurple.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ) :
                        LinearGradient(
                            gradient: Gradient(colors: [Color.lushyCream.opacity(0.5)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                isSelected ? Color.clear : Color.lushyPink.opacity(0.3),
                                lineWidth: 1
                            )
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Card Button Style

struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.8),
                                Color.lushyPink.opacity(0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.lushyPink.opacity(0.2), lineWidth: 1)
                    )
            )
            .shadow(color: Color.lushyPink.opacity(0.1), radius: 8, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Bounce Button Style
struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.8 : 1.0)
            .animation(
                Animation.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0),
                value: configuration.isPressed
            )
    }
}

// MARK: - Extension for easy use

extension View {
    func lushyButtonStyle(_ variant: LushyButtonStyle.ButtonVariant = .primary, size: LushyButtonStyle.ButtonSize = .medium) -> some View {
        self.buttonStyle(LushyButtonStyle(variant: variant, size: size))
    }
    
    func floatingActionButton(color: Color = .lushyPink) -> some View {
        self.buttonStyle(FloatingActionButtonStyle(color: color))
    }
    
    func iconButton(size: CGFloat = 44, backgroundColor: Color = Color.lushyPink.opacity(0.1), foregroundColor: Color = .lushyPink) -> some View {
        self.buttonStyle(IconButtonStyle(size: size, backgroundColor: backgroundColor, foregroundColor: foregroundColor))
    }
    
    func tagButton(isSelected: Bool = false) -> some View {
        self.buttonStyle(TagButtonStyle(isSelected: isSelected))
    }
    
    func cardButton() -> some View {
        self.buttonStyle(CardButtonStyle())
    }
    
    func bounceButtonStyle() -> some View {
        self.buttonStyle(BounceButtonStyle())
    }
}
