//
//  Comment+CoreDataProperties.swift
//  Lushy
//
//  Created by Karoline Herleiksplass on 01/05/2025.
//
//

import Foundation
import CoreData


extension Comment {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Comment> {
        return NSFetchRequest<Comment>(entityName: "Comment")
    }

    @NSManaged public var createdAt: Date?
    @NSManaged public var text: String?
    @NSManaged public var userProduct: UserProduct?

}

extension Comment : Identifiable {

}
