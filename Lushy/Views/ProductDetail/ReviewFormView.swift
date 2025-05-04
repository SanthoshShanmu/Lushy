import SwiftUI

struct ReviewFormView: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Rating")) {
                    HStack {
                        ForEach(1...5, id: \.self) { rating in
                            Image(systemName: rating <= viewModel.reviewRating ? "star.fill" : "star")
                                .foregroundColor(.yellow)
                                .font(.title)
                                .onTapGesture {
                                    viewModel.reviewRating = rating
                                }
                        }
                        
                        Spacer()
                        
                        Text("\(viewModel.reviewRating) / 5")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 5)
                }
                
                Section(header: Text("Review")) {
                    TextField("Title", text: $viewModel.reviewTitle)
                    
                    ZStack(alignment: .topLeading) {
                        if viewModel.reviewText.isEmpty {
                            Text("Share your experience with this product...")
                                .foregroundColor(.gray)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        
                        TextEditor(text: $viewModel.reviewText)
                            .frame(minHeight: 100)
                    }
                }
                
                Section {
                    Button(action: {
                        viewModel.submitReview()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Submit Review")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(Color.blue)
                    .disabled(viewModel.reviewTitle.isEmpty || viewModel.reviewText.isEmpty)
                }
            }
            .navigationTitle("Write a Review")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
