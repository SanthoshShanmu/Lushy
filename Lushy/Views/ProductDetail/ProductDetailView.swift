import SwiftUI
import CoreData

struct ProductDetailView: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showingDeleteAlert = false
    
    var body: some View {
        ZStack {
            Color.lushyBackground.opacity(0.3).edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    // Product header
                    _PrettyProductHeader(viewModel: viewModel)
                    
                    // Usage info
                    _PrettyUsageInfo(viewModel: viewModel)
                    
                    // Actions
                    _PrettyActionButtons(viewModel: viewModel)
                    
                    // Comments
                    _PrettyCommentsSection(viewModel: viewModel)
                    
                    // Reviews
                    _PrettyReviewsSection(viewModel: viewModel)
                }
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            
            // Add a back button with custom design
            ToolbarItem(placement: .principal) {
                Text("Product Details")
                    .font(.headline)
                    .foregroundColor(.lushyPurple)
            }
        }
        .sheet(isPresented: $viewModel.showReviewForm) {
            ReviewFormView(viewModel: viewModel)
        }
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("Delete Product"),
                message: Text("Are you sure you want to delete this product? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    presentationMode.wrappedValue.dismiss()
                },
                secondaryButton: .cancel()
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ProductDeleted"))) { notification in
            if let deletedID = notification.object as? NSManagedObjectID, 
               deletedID == viewModel.product.objectID {
                // Product was deleted, dismiss this view
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    // Utility functions used by multiple components
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func isExpiringSoon(_ date: Date) -> Bool {
        let now = Date()
        let twoWeeks = 14 * 24 * 60 * 60
        return date.timeIntervalSince(now) < Double(twoWeeks)
    }
}

// Create prettier components for product detail

private struct _PrettyProductHeader: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    
    var body: some View {
        VStack(alignment: .center, spacing: 15) {
            if let imageUrlString = viewModel.product.imageUrl,
               let imageUrl = URL(string: imageUrlString) {
                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 180, height: 180)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 180, height: 180)
                            .cornerRadius(20)
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    case .failure:
                        Image(systemName: "photo")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                            .frame(width: 180, height: 180)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                    .frame(width: 180, height: 180)
            }
            
            VStack(spacing: 5) {
                Text(viewModel.product.productName ?? "Unknown Product")
                    .font(.system(size: 24, weight: .bold))
                    .multilineTextAlignment(.center)
                
                if let brand = viewModel.product.brand {
                    Text(brand)
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 10)
            
            HStack(spacing: 20) {
                if viewModel.product.vegan {
                    VStack(spacing: 5) {
                        Image(systemName: "leaf.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 22))
                        
                        Text("Vegan")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 20)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(15)
                }
                
                if viewModel.product.crueltyFree {
                    VStack(spacing: 5) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.lushyPink)
                            .font(.system(size: 22))
                        
                        Text("Cruelty-Free")
                            .font(.caption)
                            .foregroundColor(.lushyPink)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 20)
                    .background(Color.lushyPink.opacity(0.1))
                    .cornerRadius(15)
                }
            }
            .padding(.top, 5)
            
            Button(action: {
                viewModel.toggleFavorite()
            }) {
                HStack(spacing: 10) {
                    Image(systemName: viewModel.product.favorite ? "star.fill" : "star")
                        .foregroundColor(viewModel.product.favorite ? .yellow : .gray)
                    
                    Text(viewModel.product.favorite ? "Remove from Favorites" : "Add to Favorites")
                        .font(.system(size: 16))
                        .foregroundColor(viewModel.product.favorite ? .yellow : .gray)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(viewModel.product.favorite ? Color.yellow : Color.gray, lineWidth: 1)
                )
            }
            .padding(.top, 10)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 5)
        )
        .padding(.horizontal)
    }
}

// MARK: - Usage Info Component
private struct _PrettyUsageInfo: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    @AppStorage("userRegion") private var userRegion: String = "GLOBAL"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Usage Information")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Purchased")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatDate(viewModel.product.purchaseDate ?? Date()))
                        .font(.subheadline)
                }
                
                Spacer()
                
                if let openDate = viewModel.product.openDate {
                    VStack(alignment: .leading) {
                        Text("Opened")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(formatDate(openDate))
                            .font(.subheadline)
                    }
                    
                    Spacer()
                }
                
                if let expireDate = viewModel.product.expireDate {
                    VStack(alignment: .leading) {
                        Text("Expires")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(formatDate(expireDate))
                            .font(.subheadline)
                            .foregroundColor(isExpiringSoon(expireDate) ? .orange : .primary)
                    }
                }
            }
            
            if let daysUntilExpiry = viewModel.daysUntilExpiry {
                if daysUntilExpiry > 0 {
                    HStack {
                        Spacer()
                        Text("\(daysUntilExpiry) days until expiry")
                            .font(.caption)
                            .padding(8)
                            .foregroundColor(daysUntilExpiry < 14 ? .orange : .blue)
                            .background(daysUntilExpiry < 14 ? Color.orange.opacity(0.2) : Color.blue.opacity(0.2))
                            .cornerRadius(8)
                        Spacer()
                    }
                } else {
                    HStack {
                        Spacer()
                        Text("Product has expired")
                            .font(.caption)
                            .padding(8)
                            .foregroundColor(.red)
                            .background(Color.red.opacity(0.2))
                            .cornerRadius(8)
                        Spacer()
                    }
                }
            }
            
            // Add compliance advisory section
            if viewModel.product.openDate != nil {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Compliance Information")
                        .font(.callout)
                        .fontWeight(.semibold)
                    
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        
                        Text(viewModel.complianceAdvisory)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Region selector
                    Menu {
                        Button("Global") { userRegion = "GLOBAL" }
                        Button("European Union") { userRegion = "EU" }
                        Button("United States") { userRegion = "US" }
                        Button("Japan") { userRegion = "JP" }
                    } label: {
                        HStack {
                            Text("Region: \(userRegion)")
                                .font(.caption)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.top, 2)
                }
                .padding(.top, 8)
                .padding(.bottom, 5)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func isExpiringSoon(_ date: Date) -> Bool {
        let now = Date()
        let twoWeeks = 14 * 24 * 60 * 60
        return date.timeIntervalSince(now) < Double(twoWeeks)
    }
}

// MARK: - Action Buttons Component
private struct _PrettyActionButtons: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    
    var body: some View {
        HStack {
            if viewModel.product.openDate == nil {
                Button(action: {
                    viewModel.markAsOpened()
                }) {
                    Label("Mark as Opened", systemImage: "seal.fill")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            } else {
                Button(action: {
                    viewModel.markAsEmpty()
                }) {
                    Label("Mark as Empty", systemImage: "trash.fill")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Comments Section Component
private struct _PrettyCommentsSection: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Comments")
                .font(.headline)
            
            commentsContent
            
            HStack {
                TextField("Add a comment", text: $viewModel.newComment)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                
                Button(action: {
                    viewModel.addComment()
                }) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.blue)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                .disabled(viewModel.newComment.isEmpty)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    @ViewBuilder
    private var commentsContent: some View {
        if let comments = viewModel.product.comments as? Set<Comment>, !comments.isEmpty {
            ForEach(Array(comments), id: \.self) { comment in
                CommentView(comment: comment)
            }
        } else {
            Text("No comments yet.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Reviews Section Component
private struct _PrettyReviewsSection: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reviews")
                .font(.headline)
            
            reviewsContent
            
            Button(action: {
                viewModel.showReviewForm = true
            }) {
                Label("Write a Review", systemImage: "pencil")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    @ViewBuilder
    private var reviewsContent: some View {
        if let reviews = viewModel.product.reviews as? Set<Review>, !reviews.isEmpty {
            ForEach(Array(reviews), id: \.self) { review in
                reviewRow(review)
            }
        } else {
            Text("No reviews yet.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func reviewRow(_ review: Review) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(review.title ?? "")
                    .font(.subheadline)
                    .fontWeight(.bold)
                
                Spacer()
                
                starRating(rating: Int(review.rating))
            }
            
            Text(review.text ?? "")
                .font(.caption)
                .padding(.top, 1)
            
            Text(formatDate(review.createdAt ?? Date()))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 2)
            
            Divider()
        }
        .padding(.bottom, 8)
    }
    
    private func starRating(rating: Int) -> some View {
        HStack {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .foregroundColor(.yellow)
                    .font(.caption)
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
