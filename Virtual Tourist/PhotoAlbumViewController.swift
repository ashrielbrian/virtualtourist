//
//  PhotoAlbumViewController.swift
//  Virtual Tourist
//
//  Created by Ashriel Brian Tang on 29/07/2017.
//  Copyright © 2017 Udacity. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import CoreData

class PhotoAlbumViewController: UIViewController {

    @IBOutlet weak var newCollectionButton: UIButton!
    @IBOutlet weak var photosCollectionView: UICollectionView!
    
    var pin = Pin()
    let delegate = AppDelegate.sharedInstance()
    let flickrClientHandler = FlickrClient.sharedInstance()
    
    var insertedIndexPath: [IndexPath]!
    var deletedIndexPath: [IndexPath]!
    var updatedIndexPath: [IndexPath]!
    
    lazy var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult> = {
        
        // Create a fetch request to specify what objects this fetchedResultsController tracks
        let fr = NSFetchRequest<NSFetchRequestResult>(entityName: "Photo")
        fr.sortDescriptors = [NSSortDescriptor(key: "imageURL", ascending: true)]
        
        // Specifies to the fr that only photos associated with the tapped pin should be fetched
        fr.predicate = NSPredicate(format: "pin = %@", self.pin)
        
        // Returns the FRC
        return NSFetchedResultsController(fetchRequest: fr, managedObjectContext: self.delegate.stack.context, sectionNameKeyPath: nil, cacheName: nil)
        
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print ("PhotoAlbumVC: the pin latitude selected - \(pin.latitude)")
        
        fetchedResultsController.delegate = self
        photosCollectionView.delegate = self
        photosCollectionView.dataSource = self
        
        let stack = delegate.stack
        let pinLocation = CLLocation(latitude: pin.latitude, longitude: pin.longitude)
        
        do {
            try fetchedResultsController.performFetch()
        } catch let error {
            print ("There was error making the fetch request: \(error.localizedDescription)")
        }
        
        let fetchedObjects = fetchedResultsController.fetchedObjects
        
        if fetchedObjects?.count == 0 {
            
            loadPhotosFromFlickr(location: pinLocation, completionHandlerForLoadPhotos: { 
                // Once the photos have been downloaded from Flickr and saved to the backgroundContext, save to Store and show on the collection view
                performUIUpdatesOnMain {
                    stack.save()
                    self.photosCollectionView.reloadData()
                }
                
            })
            /*
            flickrClientHandler.getImages(location: pinLocation.coordinate) {
                
                (success, errorString, imagesURL) in
                print("BEFORE SUCCESS")
                if success {
                    guard (errorString == nil) else {
                        print ("Error found in network request.")
                        return
                    }
                    
                    guard let imagesURL = imagesURL else{
                        print ("No images returned")
                        return
                    }
                    
                    // With the array of media files obtained, begin a background batch operation to download the data, and save it to CoreData
                    self.downloadAndConvertImages(imagesURL, self.pin) {
                        stack.save()
                        performUIUpdatesOnMain {
                            self.photosCollectionView.reloadData()

                        }
                    }
                    
                } else {
                    print ("Network request to Flickr failed. Try again later.")
                }
                
            }
            */
        }
        
        
        
    }

    func loadPhotosFromFlickr(location: CLLocation, completionHandlerForLoadPhotos: @escaping () -> Void) {
        
        // getImages to obtain the image URLs; downloadAndConvertImages to download the imageData and save them to Core Data
        flickrClientHandler.getImages(location: location.coordinate) {
            (success, errorString, imagesURL) in
            if success {
                guard (errorString == nil) else {
                    print ("Error found in network request.")
                    return
                }
                
                guard let imagesURL = imagesURL else{
                    print ("No images returned")
                    return
                }
                
                // With the array of media files obtained, begin a background batch operation to download the data, and save it to CoreData
                self.downloadAndConvertImages(imagesURL, self.pin) {
                    completionHandlerForLoadPhotos()
                }
                
            } else {
                print ("Network request to Flickr failed. Try again later.")
            }
            
        }
        
    }
    
    func downloadAndConvertImages(_ imagesURL: [String], _ pin: Pin, completionHandlerForDownloadConvert: @escaping () -> Void) {
        
        
        /* download picture and save INSIDE performBackgroundBatchOperation */
        let stack = self.delegate.stack
        stack.performBackgroundBatchOperation ( batchCompletionHandler: {
            (workerContext) in
         
            for eachURL in imagesURL {
                if let url = URL(string: eachURL) {
                    let imageData = try? Data(contentsOf: url)
                        if let imageData = imageData {
                            let photo = Photo(data: imageData, url: eachURL, context: workerContext)
                            photo.pin = pin
                            print ("saved photo \(eachURL)")
                        }
                }
            }
            completionHandlerForDownloadConvert()
        })
    }
    
    @IBAction func newCollection(_ sender: Any) {
        self.delegate.stack.save()
    }
}

// MARK: - Fetched Results Controller & Collection View
extension PhotoAlbumViewController: UICollectionViewDelegate {
    
    
    
}

extension PhotoAlbumViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return fetchedResultsController.sections![0].numberOfObjects
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "photoViewCell", for: indexPath) as! PhotoCollectionViewCell
        let pinLocation = CLLocation(latitude: self.pin.latitude, longitude: self.pin.longitude)
        
        cell.photoActivityIndicator.startAnimating()
        cell.photoActivityIndicator.hidesWhenStopped = true
        
        let photoToLoad = fetchedResultsController.object(at: indexPath) as! Photo
        
        if let imageData = photoToLoad.imageData {
            print ("There's image data alright!! ---- ")
            performUIUpdatesOnMain {
                cell.photoImage.image = UIImage(data: imageData as Data)
                cell.photoActivityIndicator.stopAnimating()
            }
        } else {
            loadPhotosFromFlickr(location: pinLocation, completionHandlerForLoadPhotos: { 
                print ("But there are no images in Core Data... ------")
                
                
            })
        }
        
        return cell
    }
    
}

extension PhotoAlbumViewController: NSFetchedResultsControllerDelegate {
    
    // Initialises a new set of arrays of IndexPaths prior to changing Core Data content
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        
        insertedIndexPath = [IndexPath]()
        deletedIndexPath = [IndexPath]()
        updatedIndexPath = [IndexPath]()
    }
    
    /* - The controller will call this function when it detects a changed object in Core Data. If it is a new object to be inserted, it will append that index path to insertedIndexPath, and so on
     - The UI changes applied on the collection view is performed separately by controllerDidChangeContent
    */
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        switch type {
            
        case .insert:
            insertedIndexPath.append(newIndexPath!)
            print ("inserted new index path")
        
        case .delete:
            deletedIndexPath.append(newIndexPath!)
            print ("deleted an index path")
            
        case .update:
            updatedIndexPath.append(newIndexPath!)
            print ("Updated an index path")
        
        default:
            break
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        
        photosCollectionView.performBatchUpdates({ 
            
            for indexPath in self.insertedIndexPath {
                self.photosCollectionView.insertItems(at: [indexPath as IndexPath])
            }
            
            for indexPath in self.deletedIndexPath {
                self.photosCollectionView.deleteItems(at: [indexPath as IndexPath])
            }
            
            for indexPath in self.updatedIndexPath {
                self.photosCollectionView.reloadItems(at: [indexPath as IndexPath])
            }
            
        }, completion: nil)
        
    }
}

