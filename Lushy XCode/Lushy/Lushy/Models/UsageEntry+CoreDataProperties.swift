import Foundation
import CoreData


extension UsageEntry {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UsageEntry> {
        return NSFetchRequest<UsageEntry>(entityName: "UsageEntry")
    }

    @NSManaged public var backendId: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var notes: String?
    @NSManaged public var usageAmount: Double
    @NSManaged public var usageType: String
    @NSManaged public var userId: String
    @NSManaged public var userProduct: UserProduct?

}

extension UsageEntry : Identifiable {

}