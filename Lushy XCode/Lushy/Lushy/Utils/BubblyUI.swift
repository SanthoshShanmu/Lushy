import SwiftUI

struct BubblyBackground: View {
    var body: some View {
        ZStack {
            // Enhanced gradient background with more feminine colors
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.lushyPink.opacity(0.25),
                    Color.lushyPurple.opacity(0.18),
                    Color.lushyMint.opacity(0.15),
                    Color.lushyPeach.opacity(0.12)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Floating blobs with enhanced gradients
            BlobShape()
                .fill(LinearGradient(
                    gradient: Gradient(colors: [Color.lushyPink.opacity(0.3), Color.lushyPurple.opacity(0.2)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 350, height: 200)
                .offset(x: -90, y: -200)
                .blur(radius: 3)
            
            BlobShape()
                .fill(LinearGradient(
                    gradient: Gradient(colors: [Color.lushyMint.opacity(0.25), Color.lushyPeach.opacity(0.2)]),
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                ))
                .frame(width: 200, height: 140)
                .offset(x: 130, y: -120)
                .blur(radius: 2)
            
            // Sparkle elements for feminine touch
            SparkleShape()
                .fill(Color.lushyPink.opacity(0.4))
                .frame(width: 20, height: 20)
                .offset(x: 100, y: -50)
            
            SparkleShape()
                .fill(Color.lushyPurple.opacity(0.3))
                .frame(width: 15, height: 15)
                .offset(x: -80, y: 100)
            
            SparkleShape()
                .fill(Color.lushyMint.opacity(0.35))
                .frame(width: 18, height: 18)
                .offset(x: 150, y: 200)
            
            // Soft circles
            Circle()
                .fill(RadialGradient(
                    gradient: Gradient(colors: [Color.lushyMint.opacity(0.2), Color.clear]),
                    center: .center,
                    startRadius: 0,
                    endRadius: 60
                ))
                .frame(width: 120, height: 120)
                .offset(x: 140, y: 350)
            
            Circle()
                .fill(RadialGradient(
                    gradient: Gradient(colors: [Color.lushyPeach.opacity(0.18), Color.clear]),
                    center: .center,
                    startRadius: 0,
                    endRadius: 40
                ))
                .frame(width: 80, height: 80)
                .offset(x: -130, y: 340)
        }
    }
}

// Enhanced blob shape with more organic curves
struct BlobShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.5, y: 0))
        path.addCurve(to: CGPoint(x: rect.width, y: rect.height * 0.35),
                      control1: CGPoint(x: rect.width * 0.85, y: 0),
                      control2: CGPoint(x: rect.width, y: rect.height * 0.15))
        path.addCurve(to: CGPoint(x: rect.width * 0.75, y: rect.height),
                      control1: CGPoint(x: rect.width, y: rect.height * 0.7),
                      control2: CGPoint(x: rect.width * 0.85, y: rect.height))
        path.addCurve(to: CGPoint(x: 0, y: rect.height * 0.65),
                      control1: CGPoint(x: rect.width * 0.35, y: rect.height),
                      control2: CGPoint(x: 0, y: rect.height * 0.85))
        path.addCurve(to: CGPoint(x: rect.width * 0.5, y: 0),
                      control1: CGPoint(x: 0, y: rect.height * 0.35),
                      control2: CGPoint(x: rect.width * 0.15, y: 0))
        path.closeSubpath()
        return path
    }
}

// MARK: - Sparkle Shape for decorative elements

struct SparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        // Create a 4-pointed star/sparkle
        let points = 8
        let outerRadius = radius
        let innerRadius = radius * 0.4
        
        for i in 0..<points {
            let angle = (Double(i) * .pi * 2 / Double(points)) - .pi / 2
            let isOuter = i % 2 == 0
            let currentRadius = isOuter ? outerRadius : innerRadius
            
            let x = center.x + CGFloat(cos(angle) * currentRadius)
            let y = center.y + CGFloat(sin(angle) * currentRadius)
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        path.closeSubpath()
        return path
    }
}

// MARK: - Heart Shape for love-themed elements

struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        
        // Start at bottom center
        path.move(to: CGPoint(x: width/2, y: height))
        
        // Left side of heart
        path.addCurve(
            to: CGPoint(x: 0, y: height/4),
            control1: CGPoint(x: width/2, y: height * 3/4),
            control2: CGPoint(x: 0, y: height/2)
        )
        
        path.addArc(
            center: CGPoint(x: width/4, y: height/4),
            radius: width/4,
            startAngle: Angle.radians(.pi),
            endAngle: Angle.radians(0),
            clockwise: false
        )
        
        // Right side of heart
        path.addArc(
            center: CGPoint(x: width * 3/4, y: height/4),
            radius: width/4,
            startAngle: Angle.radians(.pi),
            endAngle: Angle.radians(0),
            clockwise: false
        )
        
        path.addCurve(
            to: CGPoint(x: width/2, y: height),
            control1: CGPoint(x: width, y: height/2),
            control2: CGPoint(x: width/2, y: height * 3/4)
        )
        
        return path
    }
}

// MARK: - Flower Shape for botanical elements

struct FlowerShape: Shape {
    var petals: Int = 5
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 3
        
        for i in 0..<petals {
            let angle = Double(i) * 2 * .pi / Double(petals)
            let petalCenter = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )
            
            let petalPath = Path(ellipseIn: CGRect(
                x: petalCenter.x - radius/2,
                y: petalCenter.y - radius/3,
                width: radius,
                height: radius * 2/3
            ))
            
            path.addPath(petalPath)
        }
        
        // Add center circle
        path.addEllipse(in: CGRect(
            x: center.x - radius/4,
            y: center.y - radius/4,
            width: radius/2,
            height: radius/2
        ))
        
        return path
    }
}

// Enhanced bubbly card with more feminine styling
struct BubblyCard: ViewModifier {
    var cornerRadius: CGFloat = 24
    var shadowColor: Color = Color.lushyPink.opacity(0.15)
    
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(
                ZStack {
                    // Enhanced glassmorphism effect
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.8),
                                    Color.lushyPink.opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    
                    // Subtle border
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.lushyPink.opacity(0.3),
                                    Color.lushyPurple.opacity(0.2)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: shadowColor, radius: 15, x: 0, y: 8)
            .shadow(color: shadowColor.opacity(0.5), radius: 5, x: 0, y: 2)
    }
}

// Feminine button style
struct LushyFeminineButton: ViewModifier {
    var isPressed: Bool = false
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.lushyPink,
                        Color.lushyPurple.opacity(0.8)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.lushyPink.opacity(0.4), radius: 8, x: 0, y: 4)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
    }
}

// Extensions for easy use
extension View {
    func bubblyCard(cornerRadius: CGFloat = 24, shadowColor: Color = Color.lushyPink.opacity(0.15)) -> some View {
        self.modifier(BubblyCard(cornerRadius: cornerRadius, shadowColor: shadowColor))
    }
    
    func lushyFeminineButton(isPressed: Bool = false) -> some View {
        self.modifier(LushyFeminineButton(isPressed: isPressed))
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
