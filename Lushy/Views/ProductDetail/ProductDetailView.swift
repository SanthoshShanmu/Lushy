import SwiftUI
import CoreData

struct ProductDetailView: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showingDeleteAlert = false
    
    var body: some View {
        ZStack {
            // Dreamy gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.lushyPink.opacity(0.1),
                    Color.lushyPurple.opacity(0.05),
                    Color.white
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    // Product header with dreamy styling
                    _PrettyProductHeader(viewModel: viewModel)
                    
                    // Usage info with soft cards
                    _PrettyUsageInfo(viewModel: viewModel)
                    
                    // Actions with bubbly buttons
                    _PrettyActionButtons(viewModel: viewModel)
                    
                    // Comments with soft styling
                    _PrettyCommentsSection(viewModel: viewModel)
                    
                    // Reviews with girly theme
                    _PrettyReviewsSection(viewModel: viewModel)
                    
                    // Bags & Tags with soft design
                    _PrettyBagsSection(viewModel: viewModel)
                    _PrettyTagsSection(viewModel: viewModel)
                    
                    // Soft delete option
                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "trash")
                                .font(.system(size: 14, weight: .medium))
                            Text("Remove from beauty bag")
                                .font(.footnote)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.secondary)
                        .padding(.vertical, 15)
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.gray.opacity(0.1))
                        )
                    }
                    .padding(.top, 10)
                    .padding(.horizontal)
                }
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Beauty Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Remove Product", systemImage: "trash")
                    }
                    
                    Button {
                        viewModel.toggleFavorite()
                    } label: {
                        Label(
                            viewModel.product.favorite ? "Remove from Favorites" : "Add to Favorites",
                            systemImage: viewModel.product.favorite ? "heart.slash" : "heart"
                        )
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.lushyPink)
                }
            }
        }
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("Remove Product"),
                message: Text("Are you sure you want to remove this beauty item? This action cannot be undone."),
                primaryButton: .destructive(Text("Remove")) {
                    viewModel.deleteProduct()
                    presentationMode.wrappedValue.dismiss()
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: Binding(get: { viewModel.showReviewForm }, set: { viewModel.showReviewForm = $0 })) {
            ReviewFormView(viewModel: viewModel)
        }
        .onAppear {
            // Always refresh from backend when this view appears
            viewModel.fetchBagsAndTags()
            viewModel.refreshRemoteDetail()
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

// MARK: - Pretty Product Header
struct _PrettyProductHeader: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Product image with soft shadow
            if let imageUrl = viewModel.product.imageUrl {
                HStack {
                    Spacer()
                    // Attempt to load from local file path
                    let fileURL = URL(fileURLWithPath: imageUrl)
                    if FileManager.default.fileExists(atPath: fileURL.path),
                       let uiImage = UIImage(contentsOfFile: fileURL.path) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 25))
                            .shadow(color: .lushyPink.opacity(0.2), radius: 15, x: 0, y: 8)
                    } else if let remoteURL = URL(string: imageUrl) {
                        AsyncImage(url: remoteURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 25)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.lushyPink.opacity(0.1), Color.lushyPurple.opacity(0.05)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 30))
                                        .foregroundColor(.lushyPink.opacity(0.3))
                                )
                        }
                        .frame(height: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 25))
                        .shadow(color: .lushyPink.opacity(0.2), radius: 15, x: 0, y: 8)
                    }
                    Spacer()
                }
            }
            
            // Product info with dreamy styling
            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.product.brand ?? "")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.lushyPurple)
                    .textCase(.uppercase)
                    .tracking(1)
                
                Text(viewModel.product.productName ?? "Unnamed Product")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                // Display metadata as styled tags
                HStack(spacing: 8) {
                    if let shade = viewModel.product.shade, !shade.isEmpty {
                        Text(shade)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.lushyPurple.opacity(0.2))
                            .foregroundColor(.lushyPurple)
                            .cornerRadius(12)
                    }
                    if viewModel.product.sizeInMl > 0 {
                        Text("\(String(format: "%.0f", viewModel.product.sizeInMl)) ml")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.lushyMint.opacity(0.2))
                            .foregroundColor(.lushyMint)
                            .cornerRadius(12)
                    }
                    if viewModel.product.spf > 0 {
                        Text("SPF \(viewModel.product.spf)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.lushyPeach.opacity(0.2))
                            .foregroundColor(.lushyPeach)
                            .cornerRadius(12)
                    }
                }
                
                // Expiry countdown
                if let days = viewModel.daysUntilExpiry {
                    Text(days > 0 ? "Expires in \(days) days" : "Expired")
                        .font(.subheadline)
                        .foregroundColor(days > 7 ? .green : (days > 0 ? .orange : .red))
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Pretty Usage Info
struct _PrettyUsageInfo: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    
    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.lushyPink)
                Text("Usage Stats")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal)
            
            HStack(spacing: 15) {
                _PrettyStatCard(
                    title: "Times Used",
                    value: "\(viewModel.product.timesUsed)",
                    icon: "wand.and.stars",
                    color: .lushyPink
                )
                
                _PrettyStatCard(
                    title: "Love Rating",
                    value: String(format: "%.1f", viewModel.rating),
                    icon: "heart.fill",
                    color: .lushyPurple
                )
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Pretty Stat Card
struct _PrettyStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.05), Color.white],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(color.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Pretty Action Buttons
struct _PrettyActionButtons: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    
    var body: some View {
        VStack(spacing: 15) {
            HStack(spacing: 15) {
                Button(action: { viewModel.toggleFavorite() }) {
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.product.favorite ? "heart.fill" : "heart")
                            .font(.system(size: 16, weight: .semibold))
                        Text(viewModel.product.favorite ? "Loved" : "Love It")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(viewModel.product.favorite ? .white : .lushyPink)
                    .padding(.vertical, 15)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                viewModel.product.favorite ?
                                    LinearGradient(colors: [.lushyPink, .lushyPurple], startPoint: .leading, endPoint: .trailing) :
                                    LinearGradient(colors: [.white, .white], startPoint: .leading, endPoint: .trailing)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(.lushyPink.opacity(0.3), lineWidth: viewModel.product.favorite ? 0 : 1.5)
                            ))
                }

                Button(action: { viewModel.incrementUsage() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Used It")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 15)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(colors: [.lushyMint, .lushyPeach], startPoint: .leading, endPoint: .trailing)
                            )
                    )
                }
            }
            .padding(.horizontal)
            
            Button(action: {
                viewModel.showReviewForm = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "star.bubble")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Write a Review")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.lushyPurple)
                .padding(.vertical, 15)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.lushyPurple.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.lushyPurple.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal)
            
            // Finish product button
            Button(action: { viewModel.markAsEmpty() }) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Finish Product")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.vertical, 15)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(colors: [.lushyPeach, .lushyMint], startPoint: .leading, endPoint: .trailing)
                        )
            )}
            .padding(.horizontal)
        }
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

// MARK: - Bags Section
private struct _PrettyBagsSection: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    @State private var showBagPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Beauty Bags")
                    .font(.headline)
                Spacer()
                Button(action: {
                    viewModel.fetchBagsAndTags()
                    showBagPicker = true
                }) {
                    Image(systemName: "plus")
                }
            }
            if viewModel.bagsForProduct().isEmpty {
                Text("Not in any bag.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(viewModel.bagsForProduct(), id: \.self) { bag in
                    HStack {
                        Image(systemName: bag.icon ?? "bag.fill")
                            .foregroundColor(Color(bag.color ?? "lushyPink"))
                        Text(bag.name ?? "Unnamed Bag")
                        Spacer()
                        Button(action: { viewModel.removeProductFromBag(bag) }) {
                            Image(systemName: "minus.circle")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .sheet(isPresented: $showBagPicker) {
            NavigationView {
                List {
                    // Only show each unique bag that the product isn't yet in
                    let available = viewModel.allBags.filter { bag in
                        !viewModel.bagsForProduct().contains(where: { $0.objectID == bag.objectID })
                    }
                    ForEach(available, id: \.self) { bag in
                        Button(action: {
                            viewModel.addProductToBag(bag)
                            showBagPicker = false
                        }) {
                            HStack {
                                Image(systemName: bag.icon ?? "bag.fill")
                                    .foregroundColor(Color(bag.color ?? "lushyPink"))
                                Text(bag.name ?? "Unnamed Bag")
                            }
                        }
                    }
                }
                .navigationTitle("Add to Bag")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Close") { showBagPicker = false }
                    }
                }
            }
        }
    }
}

// MARK: - Tags Section
private struct _PrettyTagsSection: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    @State private var showTagPicker = false
    @State private var newTagName = ""
    @State private var newTagColor = "blue"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tags")
                    .font(.headline)
                Spacer()
                Button(action: {
                    viewModel.fetchBagsAndTags()
                    showTagPicker = true
                }) {
                    Image(systemName: "plus")
                }
            }
            if viewModel.tagsForProduct().isEmpty {
                Text("No tags.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(viewModel.tagsForProduct(), id: \.self) { tag in
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(Color(tag.color ?? "blue"))
                                    .frame(width: 10, height: 10)
                                Text(tag.name ?? "")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                Button(action: { viewModel.removeTagFromProduct(tag) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(tag.color ?? "blue").opacity(0.15))
                            .cornerRadius(12)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .sheet(isPresented: $showTagPicker) {
            NavigationView {
                VStack {
                    List {
                        ForEach(viewModel.allTags, id: \.self) { tag in
                            Button(action: {
                                viewModel.addTagToProduct(tag)
                                showTagPicker = false
                            }) {
                                HStack {
                                    Circle()
                                        .fill(Color(tag.color ?? "blue"))
                                        .frame(width: 16, height: 16)
                                    Text(tag.name ?? "Unnamed Tag")
                                }
                            }
                        }
                    }
                    Divider()
                    VStack(spacing: 10) {
                        Text("Quick Create Tag")
                            .font(.headline)
                        HStack {
                            TextField("New Tag", text: $newTagName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            Picker("Color", selection: $newTagColor) {
                                ForEach(["lushyPink", "lushyPurple", "lushyMint", "lushyPeach", "blue", "green"], id: \.self) { color in
                                    Text(color.capitalized)
                                }
                            }
                            .frame(width: 80)
                            Button("Add") {
                                if !newTagName.isEmpty {
                                    CoreDataManager.shared.createProductTag(name: newTagName, color: newTagColor)
                                    viewModel.fetchBagsAndTags()
                                    newTagName = ""
                                    newTagColor = "blue"
                                }
                            }.disabled(newTagName.isEmpty)
                        }
                    }
                    .padding()
                }
                .navigationTitle("Add Tag")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Close") { showTagPicker = false }
                    }
                }
            }
        }
    }
}
