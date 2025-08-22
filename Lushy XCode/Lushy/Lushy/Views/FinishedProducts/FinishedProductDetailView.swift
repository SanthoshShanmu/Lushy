import SwiftUI

// Specialized view for finished products that shows read-only details
struct FinishedProductDetailView: View {
    let product: UserProduct
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with finished indicator
                finishedProductHeader
                
                // Product details
                productDetailsSection
                
                // Usage summary
                usageSummarySection
                
                // Reviews section
                reviewsSection
                
                // Tags and bags (read-only)
                associationsSection
            }
            .padding()
        }
        .navigationTitle("Finished Product")
        .navigationBarTitleDisplayMode(.inline)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.green.opacity(0.1),
                    Color.white
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
    
    private var finishedProductHeader: some View {
        VStack(spacing: 16) {
            // Product image
            if let imageUrl = product.imageUrl {
                AsyncImage(url: URL(string: imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 15))
            }
            
            VStack(spacing: 8) {
                // Finished indicator
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                    Text("Product Finished")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                
                // Product name and brand
                Text(product.productName ?? "Unknown Product")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                if let brand = product.brand, !brand.isEmpty {
                    Text(brand.uppercased())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .tracking(1)
                }
                
                // Finish date
                if let finishDate = product.finishDate {
                    Text("Completed on \(DateFormatter.medium.string(from: finishDate))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var productDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Product Details")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                if let shade = product.shade, !shade.isEmpty {
                    detailRow(label: "Shade", value: shade)
                }
                
                if product.sizeInMl > 0 {
                    detailRow(label: "Size", value: "\(String(format: "%.0f", product.sizeInMl)) ml")
                }
                
                if product.spf > 0 {
                    detailRow(label: "SPF", value: "\(product.spf)")
                }
                
                if let pao = product.periodsAfterOpening, !pao.isEmpty {
                    detailRow(label: "PAO", value: pao)
                }
                
                if let purchaseDate = product.purchaseDate {
                    detailRow(label: "Purchased", value: DateFormatter.medium.string(from: purchaseDate))
                }
                
                if let openDate = product.openDate {
                    detailRow(label: "Opened", value: DateFormatter.medium.string(from: openDate))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var usageSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Usage Summary")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                // Usage duration
                if let openDate = product.openDate,
                   let finishDate = product.finishDate {
                    let days = Calendar.current.dateComponents([.day], from: openDate, to: finishDate).day ?? 0
                    detailRow(label: "Usage Duration", value: usageDurationText(days: days))
                }
                
                // Usage count if available
                if product.timesUsed > 0 {
                    detailRow(label: "Times Used", value: "\(product.timesUsed)")
                }
                
                // Favorite status
                if product.favorite {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.lushyPink)
                        Text("This was one of your favorites")
                            .font(.subheadline)
                            .foregroundColor(.lushyPink)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Review")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let reviews = product.reviews as? Set<Review>, let review = reviews.first {
                VStack(alignment: .leading, spacing: 8) {
                    // Star rating
                    HStack {
                        ForEach(1...5, id: \.self) { index in
                            Image(systemName: index <= review.rating ? "star.fill" : "star")
                                .foregroundColor(.yellow)
                        }
                        Spacer()
                        if let createdAt = review.createdAt {
                            Text(DateFormatter.medium.string(from: createdAt))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let title = review.title, !title.isEmpty {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    if let text = review.text, !text.isEmpty {
                        Text(text)
                            .font(.body)
                    }
                }
            } else {
                Text("No review added")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var associationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Bags
            VStack(alignment: .leading, spacing: 8) {
                Text("Beauty Bags")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if let bags = product.bags as? Set<BeautyBag>, !bags.isEmpty {
                    ForEach(Array(bags), id: \.self) { bag in
                        HStack {
                            Image(systemName: bag.icon ?? "bag.fill")
                                .foregroundColor(Color(bag.color ?? "lushyPink"))
                            Text(bag.name ?? "Unnamed Bag")
                                .font(.subheadline)
                        }
                    }
                } else {
                    Text("Not in any bag")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            
            // Tags
            VStack(alignment: .leading, spacing: 8) {
                Text("Tags")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if let tags = product.tags as? Set<ProductTag>, !tags.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                        ForEach(Array(tags), id: \.self) { tag in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color(tag.color ?? "lushyPink"))
                                    .frame(width: 8, height: 8)
                                Text(tag.name ?? "Tag")
                                    .font(.caption)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color(tag.color ?? "lushyPink").opacity(0.2))
                            )
                        }
                    }
                } else {
                    Text("No tags")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
    
    private func usageDurationText(days: Int) -> String {
        if days < 7 {
            return "\(days) day\(days == 1 ? "" : "s")"
        } else if days < 30 {
            let weeks = days / 7
            return "\(weeks) week\(weeks == 1 ? "" : "s")"
        } else if days < 365 {
            let months = days / 30
            return "\(months) month\(months == 1 ? "" : "s")"
        } else {
            let years = days / 365
            return "\(years) year\(years == 1 ? "" : "s")"
        }
    }
}