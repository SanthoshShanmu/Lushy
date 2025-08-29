import SwiftUI
import CoreData

struct PrettyProductRow: View {
    let product: UserProduct
    
    var body: some View {
        HStack(alignment: .center, spacing: 15) {
            // Product image with prettier styling - restructured for better alignment
            ZStack {
                // Background circle
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.lushyCream, Color.white]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 70, height: 70)
                    .shadow(color: Color.lushyPink.opacity(0.2), radius: 8, x: 0, y: 3)
                
                // Product image - centered within the circle
                Group {
                    if let imageUrlString = product.imageUrl,
                       let imageUrl = URL(string: imageUrlString) {
                        if imageUrl.isFileURL {
                            // Handle local file URL
                            if let data = try? Data(contentsOf: imageUrl), let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 58, height: 58)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "photo")
                                    .font(.system(size: 24))
                                    .foregroundColor(.gray.opacity(0.7))
                                    .frame(width: 58, height: 58)
                            }
                        } else {
                            AsyncImage(url: imageUrl) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(width: 58, height: 58)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
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
                        }
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 24))
                            .foregroundColor(.gray.opacity(0.7))
                            .frame(width: 58, height: 58)
                    }
                }
            }
            // REMOVED: Heart icon overlay since favorites are now handled at product level
            
            // Product information - properly aligned
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
                                    .fill(Color(tag.color ?? "lushyPink"))
                                    .frame(width: 7, height: 7)
                                Text(tag.name ?? "")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(tag.color ?? "lushyPink").opacity(0.10))
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
            
            // Right side with days and quantity - properly aligned
            VStack(alignment: .trailing, spacing: 8) {
                // Quantity badge positioned properly at the top right
                if product.quantity > 1 {
                    Text("×\(product.quantity)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.lushyPink)
                                .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                        )
                }
                
                // Show days until expiry with smaller text
                if let expireDate = product.expireDate {
                    let daysComponent = Calendar.current.dateComponents([.day], from: Date(), to: expireDate)
                    let days = max(0, daysComponent.day ?? 0)
                    
                    VStack(spacing: 2) {
                        if days > 0 {
                            Text("\(days)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(days < 14 ? .orange : .lushyPurple)
                            Text("days")
                                .font(.system(size: 11))
                                .foregroundColor(days < 14 ? .orange : .lushyPurple)
                        } else {
                            Text("Expired")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.red)
                                .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(days > 14 ? Color.mossGreen.opacity(0.15) :
                                  days > 0 ? Color.lushyPeach.opacity(0.15) : Color.red.opacity(0.15))
                    )
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
    }
}

#Preview {
    let context = CoreDataManager.shared.viewContext
    let sampleProduct = UserProduct(context: context)
    sampleProduct.productName = "Sample Product"
    sampleProduct.brand = "Sample Brand"
    
    return PrettyProductRow(product: sampleProduct)
}