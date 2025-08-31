import SwiftUI

struct ReviewFormView: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var isSubmitting = false

    var body: some View {
        NavigationView {
            ZStack {
                // Modern gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.lushyPink.opacity(0.1),
                        Color.lushyPurple.opacity(0.05),
                        Color.mossGreen.opacity(0.03)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header section
                        VStack(spacing: 16) {
                            // Product completion celebration
                            VStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.green)
                                
                                Text("Product Finished!")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                Text("Share your experience with \(viewModel.product.productName ?? "this product")")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .padding(.top, 20)
                        }
                        
                        // Review form
                        VStack(spacing: 24) {
                            // Rating section
                            VStack(spacing: 16) {
                                Text("How would you rate this product?")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                HStack(spacing: 8) {
                                    ForEach(1...5, id: \.self) { rating in
                                        Button(action: {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                viewModel.reviewRating = rating
                                            }
                                        }) {
                                            Image(systemName: rating <= viewModel.reviewRating ? "star.fill" : "star")
                                                .font(.title)
                                                .foregroundColor(rating <= viewModel.reviewRating ? .yellow : .gray.opacity(0.3))
                                                .scaleEffect(rating <= viewModel.reviewRating ? 1.1 : 1.0)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                
                                Text("\(viewModel.reviewRating) out of 5 stars")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                            
                            // Title field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Review Title")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                TextField("Give your review a title...", text: $viewModel.reviewTitle)
                                    .textFieldStyle(ModernTextFieldStyle())
                            }
                            
                            // Review text field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Your Review")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                ZStack(alignment: .topLeading) {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.ultraThinMaterial)
                                        .frame(minHeight: 120)
                                    
                                    if viewModel.reviewText.isEmpty {
                                        Text("Share your honest thoughts about this product...")
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 16)
                                            .padding(.top, 16)
                                    }
                                    
                                    TextEditor(text: $viewModel.reviewText)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 12)
                                        .background(Color.clear)
                                        .scrollContentBackground(.hidden)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 24)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                        )
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 20)
                    }
                }
            }
            .navigationTitle("Write Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.lushyPink)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        submitReviewAndNavigateHome()
                    }) {
                        if isSubmitting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Submit")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(.lushyPink)
                    .disabled(isSubmitDisabled)
                }
            }
            .interactiveDismissDisabled(true) // Prevent dismissing without submitting
        }
    }
    
    private var isSubmitDisabled: Bool {
        viewModel.reviewTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        viewModel.reviewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        isSubmitting
    }
    
    private func submitReviewAndNavigateHome() {
        guard !isSubmitDisabled else { return }
        
        isSubmitting = true
        
        // Submit the review
        viewModel.submitReview()
        
        // Small delay to ensure the review is processed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Dismiss this view
            presentationMode.wrappedValue.dismiss()
            
            // Navigate to root view (home/profile)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: NSNotification.Name("NavigateToHome"), object: nil)
            }
        }
    }
}

// Modern text field style
struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.lushyPink.opacity(0.2), lineWidth: 1)
            )
    }
}
