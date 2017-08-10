//
//  Pin+CoreDataClass.swift
//  Virtual Tourist
//
//  Created by Ashriel Brian Tang on 05/08/2017.
//  Copyright © 2017 Udacity. All rights reserved.
//

import Foundation
import CoreData


public class Pin: NSManagedObject {
    
    convenience init(latitude: Double, longitude: Double, context: NSManagedObjectContext) {
        if let ent = NSEntityDescription.entity(forEntityName: "Pin", in: context) {
            self.init(entity: ent, insertInto: context)
            self.latitude = latitude
            self.longitude = longitude
        } else {
            fatalError("Failed to create a Pin object")
        }
    }
}
