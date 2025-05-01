import SwiftUI
import CoreData

struct ProductRow: View {
    let product: UserProduct
    
    var body: some View {
        HStack {
            // Product image
            if let imageUrlString = product.imageUrl, let imageUrl = URL(string: imageUrlString) {
                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 50, height: 50)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                            .cornerRadius(8)
                    case .failure:
                        Image(systemName: "photo")
                            .frame(width: 50, height: 50)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Image(systemName: "photo")
                    .frame(width: 50, height: 50)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(product.productName ?? "Unknown Product")
                    .font(.headline)
                
                if let brand = product.brand {
                    Text(brand)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    if product.vegan {
                        Label("Vegan", systemImage: "leaf.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    
                    if product.crueltyFree {
                        Label("Cruelty-Free", systemImage: "heart.fill")
                            .font(.caption)
                            .foregroundColor(.pink)
                    }
                }
            }
            
            Spacer()
            
            // Show days until expiry if available
            if let expireDate = product.expireDate {
                let days = Calendar.current.dateComponents([.day], from: Date(), to: expireDate).day ?? 0
                
                if days > 0 {
                    Text("\(days) days")
                        .font(.caption)
                        .foregroundColor(days < 14 ? .orange : .blue)
                        .padding(5)
                        .background(days < 14 ? Color.orange.opacity(0.2) : Color.blue.opacity(0.2))
                        .cornerRadius(5)
                } else {
                    Text("Expired")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(5)
                        .background(Color.red.opacity(0.2))
                        .cornerRadius(5)
                }
            }
            
            if product.favorite {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
            }
        }
        .padding(.vertical, 4)
    }
}
