import SwiftUI

struct ProfileShareCardView: View {
    let profile: UserProfile
    let topProducts: [UserProductSummary]
    let userTags: [ProductTag]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Lushy branding
            VStack(spacing: 12) {
                // Lushy logo and title
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundColor(.lushyPink)
                    Text("Lushy")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.lushyPink)
                }
                
                Text("Beauty Journey")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            // User profile section
            VStack(spacing: 16) {
                // Profile image and basic info
                VStack(spacing: 12) {
                    // Profile image or initials
                    Group {
                        if let profileImageUrl = profile.profileImage,
                           !profileImageUrl.isEmpty {
                            AsyncImage(url: URL(string: "\(APIService.shared.staticBaseURL)\(profileImageUrl)")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                profileInitialsView
                            }
                        } else {
                            profileInitialsView
                        }
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.lushyPink, .lushyPurple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                    )
                    
                    // Name and username
                    VStack(spacing: 4) {
                        Text(profile.name)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("@\(profile.username)")
                            .font(.subheadline)
                            .foregroundColor(.lushyPink)
                    }
                    
                    // Bio (if available)
                    if let bio = profile.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal)
                    }
                }
                
                // User tags section
                if !userTags.isEmpty {
                    VStack(spacing: 8) {
                        Text("My Style")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 6) {
                            ForEach(Array(userTags.prefix(4)), id: \.objectID) { tag in
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color(tag.color ?? "lushyPink"))
                                        .frame(width: 8, height: 8)
                                    Text(tag.name ?? "Tag")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color(tag.color ?? "lushyPink").opacity(0.15))
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Top products section
                if !topProducts.isEmpty {
                    VStack(spacing: 12) {
                        Text("Top Products")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) {
                            ForEach(Array(topProducts.prefix(3)), id: \.id) { product in
                                VStack(spacing: 6) {
                                    // Product image placeholder
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(
                                            LinearGradient(
                                                colors: [.lushyPink.opacity(0.3), .lushyPurple.opacity(0.2)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 60, height: 60)
                                        .overlay(
                                            Image(systemName: "sparkles")
                                                .font(.title3)
                                                .foregroundColor(.lushyPink)
                                        )
                                    
                                    VStack(spacing: 2) {
                                        Text(product.name)
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                            .lineLimit(1)
                                        
                                        if let brand = product.brand {
                                            Text(brand)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    .frame(width: 60)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Stats section
                VStack(spacing: 8) {
                    Text("Beauty Stats")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 20) {
                        StatPill(
                            count: profile.products?.count ?? 0,
                            label: "Products",
                            color: .lushyMint
                        )
                        
                        StatPill(
                            count: profile.bags?.count ?? 0,
                            label: "Bags",
                            color: .lushyPurple
                        )
                        
                        StatPill(
                            count: profile.followers?.count ?? 0,
                            label: "Followers",
                            color: .lushyPink
                        )
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 20)
            
            // Footer with app info
            VStack(spacing: 8) {
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundColor(.lushyPink)
                    
                    Text("Join me on Lushy - Track your beauty journey")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundColor(.lushyPink)
                }
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: 300)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white,
                            Color.lushyPink.opacity(0.02),
                            Color.lushyPurple.opacity(0.01)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .lushyPink.opacity(0.15), radius: 12, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [.lushyPink.opacity(0.3), .lushyPurple.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
    
    private var profileInitialsView: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.lushyPink.opacity(0.8),
                        Color.lushyPurple.opacity(0.6),
                        Color.lushyMint.opacity(0.4)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Text(profile.name.prefix(1).uppercased())
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            )
    }
}

struct StatPill: View {
    let count: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
}