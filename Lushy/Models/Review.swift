import Foundation

struct Review: Identifiable, Codable {
    let id: UUID
    let rating: Int  // 1-5 stars
    let title: String
    let text: String
    let date: Date
    
    init(id: UUID = UUID(), rating: Int, title: String, text: String, date: Date = Date()) {
        self.id = id
        self.rating = rating
        self.title = title
        self.text = text
        self.date = date
    }
}