import Foundation
import CoreData

// MARK: - Event Types Extension
extension UsageJourneyEvent {
    enum EventType: String, CaseIterable {
        case purchase = "purchase"
        case open = "open"
        case usage = "usage"
        case thought = "thought"
        case review = "review"
        case halfEmpty = "halfEmpty"
        case finished = "finished"
        
        var displayName: String {
            switch self {
            case .purchase: return "Purchased"
            case .open: return "Opened"
            case .usage: return "Used"
            case .thought: return "Thought"
            case .review: return "Review"
            case .halfEmpty: return "Half Empty"
            case .finished: return "Finished"
            }
        }
        
        var icon: String {
            switch self {
            case .purchase: return "bag.fill"
            case .open: return "lock.open.fill"
            case .usage: return "checkmark.circle.fill"
            case .thought: return "bubble.left.fill"
            case .review: return "star.fill"
            case .halfEmpty: return "drop.halffull"
            case .finished: return "checkmark.circle.fill"
            }
        }
    }
    
    var eventTypeEnum: EventType? {
        guard let eventType = eventType else { return nil }
        return EventType(rawValue: eventType)
    }
    
    convenience init(context: NSManagedObjectContext, type: EventType, text: String?, title: String?, rating: Int16, date: Date = Date()) {
        self.init(context: context)
        self.eventType = type.rawValue
        self.text = text
        self.title = title
        self.rating = rating
        self.createdAt = date
    }
}