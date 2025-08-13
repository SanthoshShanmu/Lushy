import SwiftUI

struct ReviewFormView: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        // Check if user has already reviewed this product
        if viewModel.hasUserReviewed {
            VStack(spacing: 20) {
                Text("Review Already Submitted")
                    .lushyTitle()
                Text("You have already reviewed this product. Only one review per product is allowed.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                }
                .neumorphicButtonStyle()
            }
            .padding()
        } else {
            ZStack {
                Color.clear.pastelBackground()
                VStack(spacing: 24) {
                    Text("Write a Review")
                        .lushyTitle()
                    VStack(spacing: 20) {
                        // Rating stars
                        HStack(spacing: 12) {
                            ForEach(1...5, id: \.self) { rating in
                                Image(systemName: rating <= viewModel.reviewRating ? "star.fill" : "star")
                                    .foregroundColor(.yellow)
                                    .font(.title2)
                                    .onTapGesture { viewModel.reviewRating = rating }
                            }
                            Spacer()
                            Text("\(viewModel.reviewRating) / 5")
                                .foregroundColor(.secondary)
                        }
                        // Review title
                        TextField("Title", text: $viewModel.reviewTitle)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                        // Review text
                        ZStack(alignment: .topLeading) {
                            if viewModel.reviewText.isEmpty {
                                Text("Share your experience...")
                                    .foregroundColor(.gray)
                                    .padding(14)
                            }
                            TextEditor(text: $viewModel.reviewText)
                                .frame(minHeight: 100)
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                    .glassCard(cornerRadius: 20)
                    // Action buttons
                    HStack(spacing: 16) {
                        Button("Submit Review") {
                            viewModel.submitReview()
                            presentationMode.wrappedValue.dismiss()
                        }
                        .neumorphicButtonStyle()
                        .disabled(viewModel.reviewTitle.isEmpty || viewModel.reviewText.isEmpty)
                        Button("Skip & Finish") {
                            CoreDataManager.shared.markProductAsFinished(id: viewModel.product.objectID)
                            presentationMode.wrappedValue.dismiss()
                        }
                        .neumorphicButtonStyle()
                    }
                    .padding(.horizontal)
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.lushyPink)
                }
                .padding(20)
            }
        }
    }
}
