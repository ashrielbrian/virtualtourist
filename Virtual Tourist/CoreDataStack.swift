//
//  CoreDataStack.swift
//  Virtual Tourist
//
//  Created by Ashriel Brian Tang on 03/08/2017.
//  Copyright © 2017 Udacity. All rights reserved.
//

import CoreData

// MARK: Core Data Stack

struct CoreDataStack {
    
    // MARK: Properties
    
    private let model: NSManagedObjectModel
    internal let coordinator: NSPersistentStoreCoordinator
    private let modelURL: URL
    internal let dbURL: URL
    internal let persistingContext: NSManagedObjectContext
    internal let backgroundContext: NSManagedObjectContext
    let context: NSManagedObjectContext
    
    
    // MARK: Initializers
    
    init?(modelName: String) {
        
        // Assumes the model is in the main bundle
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "momd") else {
            print ("Unable to find \(modelName) in the main bundle")
            return nil
        }
        
        self.modelURL = modelURL
        
        // Try to create the model from the URL
        guard let model = NSManagedObjectModel(contentsOf: modelURL) else {
            print ("Unable to create model from \(modelURL)")
            return nil
        }
        
        self.model = model
        
        // Create the store coordinator
        coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        
        // Create a persistingContext (private queue) and a child (main queue)
        // Context to save (persist) data into the Store Coordinator
        persistingContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        persistingContext.persistentStoreCoordinator = coordinator
        
        // Context to show data to the UI
        context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.parent = persistingContext
        
        // Context to download data from the network
        backgroundContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        backgroundContext.parent = context
        
        // Add a SQLite store located in the documents folder
        let fileManager = FileManager.default
        
        guard let docURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print ("Unable to reach the documents folder")
            return nil
        }
        
        self.dbURL = docURL.appendingPathComponent("model.sqlite")
        
        // Options for migration
        let options = [NSInferMappingModelAutomaticallyOption: true, NSMigratePersistentStoresAutomaticallyOption: true]
        
        do {
            try addStoreCoordinator(NSSQLiteStoreType, configuration: nil, storeURL: dbURL, options: options  as [NSObject : AnyObject]?)
        } catch {
            print ("Unable to add store at \(dbURL)")
        }
        
    }
    
    // MARK: Utils
    func addStoreCoordinator(_ storeType: String, configuration: String?, storeURL: URL, options: [NSObject: AnyObject]? = nil) throws {
        
        try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: dbURL, options: options)
    }
}

// MARK: - CoreDataStack (Removing Data)
internal extension CoreDataStack {
    
    // Deletes all the objects in the DB - this won't delete the files. Then creates a new store coordinator to replace the destroyed one
    func dropAllData() throws {
        let options = [NSInferMappingModelAutomaticallyOption: true, NSMigratePersistentStoresAutomaticallyOption: true]
        try coordinator.destroyPersistentStore(at: dbURL, ofType: NSSQLiteStoreType, options: nil)
        try addStoreCoordinator(NSSQLiteStoreType, configuration: nil, storeURL: dbURL, options: options as [NSObject : AnyObject])
    }
}

// MARK: - CoreDataStack (Background Batch Processing)
extension CoreDataStack {
    
    // Runs the batch processing using the background context
    typealias Batch = (_ workerContext: NSManagedObjectContext) -> Void
    
    func performBackgroundBatchOperation(batchCompletionHandler: @escaping Batch) {
        
        backgroundContext.perform() {
            
            // Run the input closure handler, and send the backgroundContext as an argument
            batchCompletionHandler(self.backgroundContext)
            
            // Save it to the parent context - context in the main queue - so normal saving can work
            do {
                try self.backgroundContext.save()
            } catch {
                fatalError("Error while saving backgroundContext: \(error)")
            }
        }
    }
}

// MARK: - CoreDataStack (Saving Data)
extension CoreDataStack {
    
    func save() {
        
        print("SAVE PERFORMED ------ ")
        context.performAndWait() {
            
            if self.context.hasChanges {
                do {
                    try self.context.save()
                } catch {
                    fatalError("Error while saving mainContext: \(error)")
                }
                
                // Now saving in the background to the Data Store
                self.persistingContext.perform() {
                    do {
                        try self.persistingContext.save()
                        print("Pin saved!")
                    } catch {
                        fatalError("Error while saving persistingContext: \(error)")
                    }
                }
            }
        }
    }
    
}
    
