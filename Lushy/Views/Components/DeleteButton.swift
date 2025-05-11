import SwiftUI

struct DeleteButton: View {
    var productName: String
    var action: () -> Void
    @State private var showingConfirmation = false
    
    var body: some View {
        Button(action: {
            showingConfirmation = true
        }) {
            Image(systemName: "trash")
                .foregroundColor(.red)
        }
        .confirmationDialog(
            "Delete \(productName)?",
            isPresented: $showingConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                action()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
    }
}