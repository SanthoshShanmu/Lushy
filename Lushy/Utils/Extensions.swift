import SwiftUI
import Combine

// MARK: - View Extensions

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
    
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
    
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // MARK: - Lushy Typography Extensions
    
    func lushyTitle() -> some View {
        self.font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    gradient: Gradient(colors: [Color.lushyPink, Color.lushyPurple]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }
    
    func lushyHeadline() -> some View {
        self.font(.system(size: 22, weight: .semibold, design: .rounded))
            .foregroundColor(.lushyPurple)
    }
    
    func lushySubheadline() -> some View {
        self.font(.system(size: 18, weight: .medium, design: .rounded))
            .foregroundColor(.lushyPink)
    }
    
    func lushyBody() -> some View {
        self.font(.system(size: 16, weight: .regular, design: .rounded))
            .foregroundColor(.primary)
            .lineSpacing(2)
    }
    
    func lushyCaption() -> some View {
        self.font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundColor(.secondary)
    }
    
    func lushySmallText() -> some View {
        self.font(.system(size: 12, weight: .regular, design: .rounded))
            .foregroundColor(.secondary)
    }
    
    // MARK: - Lushy Visual Effects
    
    func lushyGlow(color: Color = .lushyPink, radius: CGFloat = 10) -> some View {
        self.shadow(color: color.opacity(0.3), radius: radius, x: 0, y: 0)
            .shadow(color: color.opacity(0.1), radius: radius * 2, x: 0, y: 0)
    }
    
    func lushyShadow(color: Color = .lushyPink, radius: CGFloat = 8, y: CGFloat = 4) -> some View {
        self.shadow(color: color.opacity(0.15), radius: radius, x: 0, y: y)
            .shadow(color: color.opacity(0.05), radius: radius * 0.5, x: 0, y: y * 0.5)
    }
    
    func shimmering() -> some View {
        self.overlay(
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color.white.opacity(0.4),
                            Color.clear
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .rotationEffect(.degrees(45))
                .scaleEffect(x: 0.1, y: 1)
                .animation(
                    Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: false),
                    value: UUID()
                )
        )
        .clipped()
    }
    
    func feminineCardStyle() -> some View {
        self.padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.9),
                                Color.lushyPink.opacity(0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
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
                    )
            )
            .lushyShadow()
    }
    
    func sparkleOverlay() -> some View {
        self.overlay(
            ZStack {
                SparkleShape()
                    .fill(Color.lushyPink.opacity(0.6))
                    .frame(width: 8, height: 8)
                    .offset(x: -20, y: -15)
                
                SparkleShape()
                    .fill(Color.lushyPurple.opacity(0.4))
                    .frame(width: 6, height: 6)
                    .offset(x: 25, y: -10)
                
                SparkleShape()
                    .fill(Color.lushyMint.opacity(0.5))
                    .frame(width: 10, height: 10)
                    .offset(x: 15, y: 20)
            }
        )
    }
    
    func bounceAnimation() -> some View {
        self.scaleEffect(1.0)
            .animation(
                Animation.easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true),
                value: UUID()
            )
    }
    
    func pulseAnimation() -> some View {
        self.scaleEffect(1.0)
            .opacity(1.0)
            .animation(
                Animation.easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true),
                value: UUID()
            )
    }
}

// Helper shape for rounded corners on specific sides
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Date Extensions

extension Date {
    func adding(days: Int) -> Date {
        return Calendar.current.date(byAdding: .day, value: days, to: self)!
    }
    
    func adding(months: Int) -> Date {
        return Calendar.current.date(byAdding: .month, value: months, to: self)!
    }
    
    func startOfDay() -> Date {
        return Calendar.current.startOfDay(for: self)
    }
    
    func daysFrom(_ date: Date) -> Int {
        let calendar = Calendar.current
        let date1 = calendar.startOfDay(for: self)
        let date2 = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.day], from: date2, to: date1)
        return components.day ?? 0
    }
    
    var formattedBeautyStyle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: self)
    }
    
    var timeAgoDisplay: String {
        let now = Date()
        let components = Calendar.current.dateComponents([.minute, .hour, .day, .weekOfYear], from: self, to: now)
        
        if let weeks = components.weekOfYear, weeks > 0 {
            return weeks == 1 ? "1 week ago" : "\(weeks) weeks ago"
        } else if let days = components.day, days > 0 {
            return days == 1 ? "1 day ago" : "\(days) days ago"
        } else if let hours = components.hour, hours > 0 {
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        } else if let minutes = components.minute, minutes > 0 {
            return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago"
        } else {
            return "Just now"
        }
    }
}

// Add these formatters to the existing Extensions.swift file:
extension DateFormatter {
    static let medium: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    static let shortWithTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
    
    static let lushyStyle: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()
}

// MARK: - String Extensions

extension String {
    func extractMonths() -> Int? {
        let pattern = "(\\d+)\\s*[Mm]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        
        let nsString = self as NSString
        if let match = regex.firstMatch(in: self, range: NSRange(location: 0, length: nsString.length)) {
            if let range = Range(match.range(at: 1), in: self) {
                return Int(self[range])
            }
        }
        return nil
    }
    
    var trimmed: String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var isValidURL: Bool {
        if let url = URL(string: self), UIApplication.shared.canOpenURL(url) {
            return true
        }
        return false
    }
    
    var beautified: String {
        return self.replacingOccurrences(of: "_", with: " ")
                  .replacingOccurrences(of: "-", with: " ")
                  .capitalized
    }
    
    func truncated(to length: Int, trailing: String = "...") -> String {
        return self.count > length ? String(self.prefix(length)) + trailing : self
    }
}

// MARK: - Color Extensions

extension Color {
    // Keep only the hex utility function
    static func fromHex(_ hex: String) -> Color {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        return Color(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
    
    // Lushy color variations
    var softened: Color {
        return self.opacity(0.7)
    }
    
    var muted: Color {
        return self.opacity(0.4)
    }
    
    var subtle: Color {
        return self.opacity(0.2)
    }
    
    static var lushyGradientPrimary: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [Color.lushyPink, Color.lushyPurple]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var lushyGradientSecondary: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [Color.lushyMint, Color.lushyPeach]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var lushyGradientNeutral: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [Color.lushyCream, Color.white]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Publisher Extensions

extension Publisher where Output == Never, Failure == Never {
    static func empty() -> AnyPublisher<Output, Failure> {
        return Empty().eraseToAnyPublisher()
    }
}

extension Publisher {
    func asResult() -> AnyPublisher<Result<Output, Failure>, Never> {
        return self
            .map { Result.success($0) }
            .catch { Just(Result.failure($0)) }
            .eraseToAnyPublisher()
    }
}
