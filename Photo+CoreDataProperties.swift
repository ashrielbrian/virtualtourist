//
//  Photo+CoreDataProperties.swift
//  Virtual Tourist
//
//  Created by Ashriel Brian Tang on 05/08/2017.
//  Copyright © 2017 Udacity. All rights reserved.
//

import Foundation
import CoreData


extension Photo {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Photo> {
        return NSFetchRequest<Photo>(entityName: "Photo")
    }

    @NSManaged public var imageData: NSData?
    @NSManaged public var pin: Pin?
    @NSManaged public var imageURL: String?

}
