import SwiftUI

struct LushyButtonStyle: ButtonStyle {
    var backgroundColor: Color = .lushyPink
    var foregroundColor: Color = .white
    var isLarge: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(isLarge ? 16 : 12)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(backgroundColor)
                    
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        .blur(radius: 0.5)
                }
            )
            .foregroundColor(foregroundColor)
            .font(.system(size: isLarge ? 18 : 16, weight: .semibold))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .shadow(color: backgroundColor.opacity(0.3), radius: 10, x: 0, y: 5)
            .animation(.spring(), value: configuration.isPressed)
    }
}

struct LushyIconButtonStyle: ButtonStyle {
    var backgroundColor: Color = .lushyPink
    var foregroundColor: Color = .white
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(12)
            .background(
                Circle()
                    .fill(backgroundColor)
                    .shadow(color: backgroundColor.opacity(0.3), radius: 5, x: 0, y: 3)
            )
            .foregroundColor(foregroundColor)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(), value: configuration.isPressed)
    }
}

// Card style for lists
struct LushyCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            .padding(.horizontal)
            .padding(.vertical, 6)
    }
}

extension View {
    func lushyCard() -> some View {
        modifier(LushyCardStyle())
    }
}
