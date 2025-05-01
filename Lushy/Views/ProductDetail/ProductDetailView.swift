import SwiftUI

struct ProductDetailView: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showingDeleteAlert = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Break up into smaller components within the same file
                _ProductHeaderView(viewModel: viewModel)
                _UsageInfoView(viewModel: viewModel)
                _ActionButtonsView(viewModel: viewModel)
                _CommentsSection(viewModel: viewModel)
                _ReviewsSection(viewModel: viewModel)
            }
            .padding()
        }
        .navigationTitle("Product Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
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
                    // Handle delete
                    presentationMode.wrappedValue.dismiss()
                },
                secondaryButton: .cancel()
            )
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

// MARK: - Product Header Component
private struct _ProductHeaderView: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    
    var body: some View {
        HStack(alignment: .top) {
            if let imageUrlString = viewModel.product.imageUrl, let imageUrl = URL(string: imageUrlString) {
                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 120, height: 120)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 120)
                            .cornerRadius(8)
                    case .failure:
                        Image(systemName: "photo")
                            .frame(width: 120, height: 120)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .foregroundColor(.gray)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.product.productName ?? "Unknown Product")
                    .font(.title3)
                    .fontWeight(.bold)
                
                if let brand = viewModel.product.brand {
                    Text(brand)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    if viewModel.product.vegan {
                        Label("Vegan", systemImage: "leaf.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.vertical, 2)
                            .padding(.horizontal, 8)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    if viewModel.product.crueltyFree {
                        Label("Cruelty-Free", systemImage: "heart.fill")
                            .font(.caption)
                            .foregroundColor(.pink)
                            .padding(.vertical, 2)
                            .padding(.horizontal, 8)
                            .background(Color.pink.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    viewModel.toggleFavorite()
                }) {
                    Label(
                        viewModel.product.favorite ? "Remove from Favorites" : "Add to Favorites",
                        systemImage: viewModel.product.favorite ? "star.fill" : "star"
                    )
                    .font(.caption)
                    .foregroundColor(viewModel.product.favorite ? .yellow : .blue)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// MARK: - Usage Info Component
private struct _UsageInfoView: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    
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
private struct _ActionButtonsView: View {
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
private struct _CommentsSection: View {
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
private struct _ReviewsSection: View {
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
