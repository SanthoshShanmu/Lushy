import SwiftUI

struct CommentView: View {
    let comment: Comment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(comment.text ?? "")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            
            Text(formatDate(comment.createdAt ?? Date()))
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider()
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
