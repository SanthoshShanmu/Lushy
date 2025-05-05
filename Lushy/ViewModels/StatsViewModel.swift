// Create a new view model for tracking usage statistics

import Foundation
import CoreData
import Combine

class StatsViewModel: ObservableObject {
    @Published var finishedProducts: [UserProduct] = []
    
    private var cancellables = Set<AnyCancellable>()
    private let managedObjectContext = CoreDataManager.shared.viewContext
    
    init() {
        fetchFinishedProducts()
        
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.fetchFinishedProducts()
            }
            .store(in: &cancellables)
    }
    
    func fetchFinishedProducts() {
        let request: NSFetchRequest<UserProduct> = UserProduct.fetchRequest()
        request.predicate = NSPredicate(format: "isFinished == YES")
        request.sortDescriptors = [NSSortDescriptor(key: "finishDate", ascending: false)]
        
        do {
            finishedProducts = try managedObjectContext.fetch(request)
        } catch {
            print("Error fetching finished products: \(error)")
        }
    }
    
    // Calculate average usage time
    func averageUsageTime() -> String {
        let products = finishedProducts.filter { $0.openDate != nil && $0.finishDate != nil }
        
        if products.isEmpty { return "N/A" }
        
        let totalDays = products.reduce(0) { result, product in
            guard let openDate = product.openDate,
                  let finishDate = product.value(forKey: "finishDate") as? Date else {
                return result
            }
            
            let days = Calendar.current.dateComponents([.day], from: openDate, to: finishDate).day ?? 0
            return result + days
        }
        
        let average = Double(totalDays) / Double(products.count)
        return String(format: "%.1f days", average)
    }
}