import SwiftUI

struct IconSelectorView: View {
    @Binding var selectedIcon: String
    let icons: [String]
    let onIconSelected: (String) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    // Separate system icons and emojis
    private var systemIcons: [String] {
        icons.filter { $0.count > 1 }
    }
    
    private var emojiIcons: [String] {
        icons.filter { $0.count == 1 }
    }
    
    // Grid layout configuration
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
    private let emojiColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)
    
    var body: some View {
        NavigationView {
            ZStack {
                // Beautiful gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.lushyPink.opacity(0.06),
                        Color.lushyPurple.opacity(0.03),
                        Color.lushyCream.opacity(0.2),
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
                            Text("Choose Icon")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.lushyPink, .lushyPurple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            Text("Select an icon or emoji for your beauty bag")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        
                        // System Icons Section
                        if !systemIcons.isEmpty {
                            VStack(spacing: 20) {
                                HStack {
                                    Text("System Icons")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                                
                                LazyVGrid(columns: columns, spacing: 16) {
                                    ForEach(systemIcons, id: \.self) { icon in
                                        IconButton(
                                            icon: icon,
                                            isSelected: selectedIcon == icon,
                                            isEmoji: false
                                        ) {
                                            selectedIcon = icon
                                            onIconSelected(icon)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                        
                        // Emoji Icons Section
                        if !emojiIcons.isEmpty {
                            VStack(spacing: 20) {
                                HStack {
                                    Text("Emoji Icons")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                                
                                LazyVGrid(columns: emojiColumns, spacing: 12) {
                                    ForEach(emojiIcons, id: \.self) { emoji in
                                        IconButton(
                                            icon: emoji,
                                            isSelected: selectedIcon == emoji,
                                            isEmoji: true
                                        ) {
                                            selectedIcon = emoji
                                            onIconSelected(emoji)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                        
                        // Preview Section
                        VStack(spacing: 16) {
                            Text("Preview")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            ZStack {
                                Circle()
                                    .fill(Color.lushyPink.opacity(0.15))
                                    .frame(width: 80, height: 80)
                                
                                if selectedIcon.count == 1 {
                                    // Emoji
                                    Text(selectedIcon)
                                        .font(.system(size: 36))
                                } else {
                                    // System icon
                                    Image(systemName: selectedIcon)
                                        .font(.system(size: 32, weight: .medium))
                                        .foregroundColor(.lushyPink)
                                }
                            }
                            .shadow(color: .lushyPink.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.lushyPink)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.lushyPink)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Icon Button Component
private struct IconButton: View {
    let icon: String
    let isSelected: Bool
    let isEmoji: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: isEmoji ? 12 : 16)
                    .fill(isSelected ? Color.lushyPink.opacity(0.15) : Color.white.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: isEmoji ? 12 : 16)
                            .stroke(
                                isSelected ? Color.lushyPink : Color.gray.opacity(0.2),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                    .frame(width: isEmoji ? 50 : 70, height: isEmoji ? 50 : 70)
                
                // Icon/Emoji
                if isEmoji {
                    Text(icon)
                        .font(.system(size: 24))
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(isSelected ? .lushyPink : .primary)
                }
                
                // Selection indicator
                if isSelected {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.lushyPink)
                                .background(Circle().fill(.white))
                                .offset(x: 4, y: -4)
                        }
                        Spacer()
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Preview
struct IconSelectorView_Previews: PreviewProvider {
    static var previews: some View {
        IconSelectorView(
            selectedIcon: .constant("bag.fill"),
            icons: [
                "bag.fill", "case.fill", "suitcase.fill", "sparkles", "heart.fill",
                "💄", "✨", "🌸", "💅", "🎀", "💖"
            ],
            onIconSelected: { _ in }
        )
    }
}