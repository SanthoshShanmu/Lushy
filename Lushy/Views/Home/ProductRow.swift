import SwiftUI
import CoreData

struct ProductRow: View {
    let product: UserProduct
    
    var body: some View {
        HStack(spacing: 15) {
            // Product image
            ZStack {
                Circle()
                    .fill(Color.lushyCream)
                    .frame(width: 65, height: 65)
                
                if let imageUrlString = product.imageUrl,
                   let imageUrl = URL(string: imageUrlString) {
                    AsyncImage(url: imageUrl) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 55, height: 55)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 55, height: 55)
                                .clipShape(Circle())
                        case .failure:
                            Image(systemName: "photo")
                                .foregroundColor(.gray.opacity(0.7))
                                .frame(width: 55, height: 55)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "photo")
                        .foregroundColor(.gray.opacity(0.7))
                        .frame(width: 55, height: 55)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(product.productName ?? "Unknown Product")
                    .font(.headline)
                    .lineLimit(1)
                
                if let brand = product.brand {
                    Text(brand)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                HStack(spacing: 10) {
                    if product.vegan {
                        HStack(spacing: 2) {
                            Image(systemName: "leaf.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 10))
                            Text("Vegan")
                                .font(.system(size: 11))
                                .foregroundColor(.green)
                        }
                        .padding(.vertical, 2)
                        .padding(.horizontal, 8)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(10)
                    }
                    
                    if product.crueltyFree {
                        HStack(spacing: 2) {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.lushyPink)
                                .font(.system(size: 10))
                            Text("Cruelty-Free")
                                .font(.system(size: 11))
                                .foregroundColor(.lushyPink)
                        }
                        .padding(.vertical, 2)
                        .padding(.horizontal, 8)
                        .background(Color.lushyPink.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
            }
            
            Spacer()
            
            // Show days until expiry if available
            if let expireDate = product.expireDate {
                let daysComponent = Calendar.current.dateComponents([.day], from: Date(), to: expireDate)
                let days = max(0, daysComponent.day ?? 0) // Ensure non-negative values
                
                VStack(spacing: 2) {
                    if days > 0 {
                        Text("\(days)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(days < 14 ? .orange : .lushyPurple)
                        
                        Text("days")
                            .font(.system(size: 12))
                            .foregroundColor(days < 14 ? .orange : .lushyPurple)
                    } else {
                        Text("Expired")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(5)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(8)
                    }
                    
                    if product.favorite {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 14))
                            .padding(.top, 3)
                    }
                }
                .frame(width: 60)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
    }
}

// Add this at the end of your file to create a prettier version

struct PrettyProductRow: View {
    let product: UserProduct
    
    var body: some View {
        HStack(spacing: 15) {
            // Product image with prettier styling
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.lushyCream, Color.white]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 70, height: 70)
                    .shadow(color: Color.lushyPink.opacity(0.2), radius: 8, x: 0, y: 3)
                
                if let imageUrlString = product.imageUrl,
                   let imageUrl = URL(string: imageUrlString) {
                    AsyncImage(url: imageUrl) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 58, height: 58)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 58, height: 58)
                                .clipShape(Circle())
                        case .failure:
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                                .foregroundColor(.gray.opacity(0.7))
                                .frame(width: 58, height: 58)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 24))
                        .foregroundColor(.gray.opacity(0.7))
                        .frame(width: 58, height: 58)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(product.productName ?? "Unknown Product")
                    .font(.system(size: 17, weight: .medium))
                    .lineLimit(1)
                
                if let brand = product.brand {
                    Text(brand)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                // Bag and tag indicators
                HStack(spacing: 6) {
                    if let bags = product.bags as? Set<BeautyBag>, let bag = bags.first {
                        HStack(spacing: 3) {
                            Image(systemName: bag.icon ?? "bag.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color(bag.color ?? "lushyPink"))
                            Text(bag.name ?? "Bag")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(bag.color ?? "lushyPink").opacity(0.08))
                        .cornerRadius(8)
                    }
                    if let tags = product.tags as? Set<ProductTag>, !tags.isEmpty {
                        ForEach(Array(tags.prefix(2)), id: \.self) { tag in
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(Color(tag.color ?? "blue"))
                                    .frame(width: 7, height: 7)
                                Text(tag.name ?? "")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(tag.color ?? "blue").opacity(0.10))
                            .cornerRadius(8)
                        }
                    }
                }
                
                HStack(spacing: 10) {
                    if product.vegan {
                        HStack(spacing: 3) {
                            Image(systemName: "leaf.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 11))
                            Text("Vegan")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.green)
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 8)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.1))
                        )
                    }
                    
                    if product.crueltyFree {
                        HStack(spacing: 3) {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.lushyPink)
                                .font(.system(size: 11))
                            Text("Cruelty-Free")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.lushyPink)
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 8)
                        .background(
                            Capsule()
                                .fill(Color.lushyPink.opacity(0.1))
                        )
                    }
                }
            }
            
            Spacer()
            
            // Show days until expiry with prettier styling
            if let expireDate = product.expireDate {
                let daysComponent = Calendar.current.dateComponents([.day], from: Date(), to: expireDate)
                let days = max(0, daysComponent.day ?? 0) // Ensure non-negative values
                
                ZStack {
                    Circle()
                        .fill(days > 14 ? Color.lushyMint.opacity(0.2) :
                              days > 0 ? Color.lushyPeach.opacity(0.2) : Color.red.opacity(0.2))
                        .frame(width: 65, height: 65)
                    
                    VStack(spacing: 2) {
                        if days > 0 {
                            Text("\(days)")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(days < 14 ? .orange : .lushyPurple)
                            
                            Text("days")
                                .font(.system(size: 12))
                                .foregroundColor(days < 14 ? .orange : .lushyPurple)
                        } else {
                            Text("Expired")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red)
                                .cornerRadius(8)
                        }
                    }
                }
                .overlay(
                    product.favorite ?
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 14))
                        .background(
                            Circle()
                                .fill(Color.white)
                                .frame(width: 22, height: 22)
                        )
                        .offset(x: 0, y: -25)
                    : nil
                )
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
    }
}
