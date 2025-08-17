import Foundation
import CoreData
import Combine

class UsageJourneyViewModel: ObservableObject {
    @Published var events: [UsageJourneyEvent] = []
    @Published var newThoughtText = ""
    @Published var isLoading = false
    @Published var showingCustomDateSheet = false
    @Published var customThoughtDate = Date()
    
    let product: UserProduct  // Changed from private to public
    private var cancellables = Set<AnyCancellable>()
    private let managedObjectContext = CoreDataManager.shared.viewContext
    
    init(product: UserProduct) {
        self.product = product
        fetchEvents()
        
        // Subscribe to Core Data changes
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.fetchEvents()
            }
            .store(in: &cancellables)
    }
    
    func fetchEvents() {
        let request: NSFetchRequest<UsageJourneyEvent> = UsageJourneyEvent.fetchRequest()
        request.predicate = NSPredicate(format: "userProduct == %@", product)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        
        do {
            events = try managedObjectContext.fetch(request)
        } catch {
            print("Error fetching usage journey events: \(error)")
        }
    }
    
    func addThought() {
        addThought(withDate: Date())
    }
    
    func addThought(withDate date: Date) {
        guard !newThoughtText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        createEvent(type: "thought", text: newThoughtText, date: date)
        newThoughtText = ""
    }
    
    private func createEvent(type: String, text: String?, date: Date) {
        let event = UsageJourneyEvent(context: managedObjectContext)
        event.userProduct = product
        event.eventType = type
        event.text = text
        event.createdAt = date
        
        do {
            try managedObjectContext.save()
            fetchEvents()
        } catch {
            print("Error creating journey event: \(error)")
        }
    }
    
    // Create automatic events for existing product data
    func createInitialEvents() {
        let existingEvents = events
        
        // Create purchase event if needed
        if let purchaseDate = product.purchaseDate,
           !existingEvents.contains(where: { $0.eventType == UsageJourneyEvent.EventType.purchase.rawValue }) {
            createEvent(type: "purchase", text: nil, date: purchaseDate)
        }
        
        // Create open event if needed
        if let openDate = product.openDate,
           !existingEvents.contains(where: { $0.eventType == UsageJourneyEvent.EventType.open.rawValue }) {
            createEvent(type: "open", text: nil, date: openDate)
        }
        
        // Create finished event if needed
        if product.isFinished,
           !existingEvents.contains(where: { $0.eventType == UsageJourneyEvent.EventType.finished.rawValue }) {
            createEvent(type: "finished", text: nil, date: product.finishDate ?? Date())
        }
        
        // Convert existing comments to thoughts
        if let comments = product.comments as? Set<Comment> {
            for comment in comments {
                if !existingEvents.contains(where: { 
                    $0.eventType == UsageJourneyEvent.EventType.thought.rawValue && 
                    $0.text == comment.text 
                }) {
                    createEvent(type: "thought", text: comment.text, date: comment.createdAt ?? Date())
                }
            }
        }
        
        // Convert existing reviews to review events
        if let reviews = product.reviews as? Set<Review> {
            for review in reviews {
                if !existingEvents.contains(where: { 
                    $0.eventType == UsageJourneyEvent.EventType.review.rawValue && 
                    $0.title == review.title 
                }) {
                    CoreDataManager.shared.addUsageJourneyEventNew(
                        to: product.objectID,
                        type: .review,
                        text: review.text,
                        title: review.title,
                        rating: Int16(review.rating),
                        date: review.createdAt ?? Date()
                    )
                }
            }
        }
    }
}