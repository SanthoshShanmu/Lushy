//
//  Review+CoreDataProperties.swift
//  Lushy
//
//  Created by Karoline Herleiksplass on 01/05/2025.
//
//

import Foundation
import CoreData


extension Review {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Review> {
        return NSFetchRequest<Review>(entityName: "Review")
    }

    @NSManaged public var createdAt: Date?
    @NSManaged public var rating: Int16
    @NSManaged public var text: String?
    @NSManaged public var title: String?
    @NSManaged public var userProduct: UserProduct?

}

extension Review : Identifiable {

}
