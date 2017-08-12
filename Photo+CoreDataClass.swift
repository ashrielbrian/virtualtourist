//
//  Photo+CoreDataClass.swift
//  Virtual Tourist
//
//  Created by Ashriel Brian Tang on 05/08/2017.
//  Copyright © 2017 Udacity. All rights reserved.
//

import Foundation
import CoreData


public class Photo: NSManagedObject {

    convenience init(data: Data? = nil, url: String, context: NSManagedObjectContext){
        if let ent = NSEntityDescription.entity(forEntityName: "Photo", in: context) {
            self.init(entity: ent, insertInto: context)
            self.imageData = data as? NSData
            self.imageURL = url
        } else {
            fatalError("Unable to find Entity name!")
        }
    }
}
