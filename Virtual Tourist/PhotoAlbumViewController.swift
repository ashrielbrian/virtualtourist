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

    // MARK: - Properties Declaration
    @IBOutlet weak var newCollectionButton: UIButton!
    @IBOutlet weak var photosCollectionView: UICollectionView!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    
    var pin = Pin()
    let delegate = AppDelegate.sharedInstance()
    let flickrClientHandler = FlickrClient.sharedInstance()
    
    var selectedIndexPath = [IndexPath]()
    var insertedIndexPath: [IndexPath]!
    var deletedIndexPath: [IndexPath]!
    var updatedIndexPath: [IndexPath]!
    
    let newCollectionButtonTitle = "New Collection"
    let deleteButtonTitle = "Delete Selected Photos"
    
    // MARK: Initialising FetchedResultsController
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
        
        fetchedResultsController.delegate = self
        photosCollectionView.delegate = self
        photosCollectionView.dataSource = self
        
        let stack = delegate.stack
        let pinLocation = CLLocation(latitude: pin.latitude, longitude: pin.longitude)
        
        // Show the pin on the MapView
        presentPin(location: pinLocation)
        configureFlowLayout()
        
        do {
            try fetchedResultsController.performFetch()
        } catch let error {
            print ("There was error making the fetch request: \(error.localizedDescription)")
        }
        
        let fetchedObjects = fetchedResultsController.fetchedObjects
        
        if fetchedObjects?.count == 0 {
            
            loadPhotosFromFlickr(location: pinLocation, completionHandlerForLoadPhotos: { 
                // Once the photos have been downloaded from Flickr and save to Store and show on the collection view
                
                stack.save()
                performUIUpdatesOnMain {
                    self.photosCollectionView.reloadData()
                }
                
            })
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

                self.saveURLToCoreData(imagesURL, self.pin, completionHandlerForSaveURL: { 
                    completionHandlerForLoadPhotos()
                })
                
            } else {
                print ("Network request to Flickr failed. Try again later.")
            }
        }
    }
    
    func saveURLToCoreData(_ imagesURL: [String], _ pin: Pin, completionHandlerForSaveURL: @escaping () -> Void) {
        
        /* download picture and save INSIDE performBackgroundBatchOperation */
        let stack = self.delegate.stack
        
        DispatchQueue.main.async {
            for eachURL in imagesURL {
                let photo = Photo(url: eachURL, context: stack.context)
                photo.pin = pin
            }
        }
        
        completionHandlerForSaveURL()
    }
    
    @IBAction func newCollection(_ sender: Any) {
        delete()
    }
}

// MARK: - Delete Photos
extension PhotoAlbumViewController {
    
    // When deleting, obtain objects through the fetchedResultsController
    func deleteSelectedPhotos() {
        let stack = delegate.stack
        
        for indexPath in selectedIndexPath {
            stack.context.delete(fetchedResultsController.object(at: indexPath) as! Photo)
        }
        
        stack.save()
        // Empties the selectedIndexPath array, to ensure it does not double count in future calls
        selectedIndexPath = []
        
        performUIUpdatesOnMain {
            self.photosCollectionView.reloadData()
        }
    }
    
    func deleteAllPhotos() {
        let stack = delegate.stack
        
        for object in fetchedResultsController.fetchedObjects! {
            stack.context.delete(object as! Photo)
        }
    }
    
    func delete() {
        let currentTitle = newCollectionButton.titleLabel?.text
        
        // Check if the current button title is "Delete selected photos" or "New Collection"
        switch currentTitle! {
            
        case newCollectionButtonTitle:
            deleteAllPhotos()
            let pinLocation = CLLocation(latitude: pin.latitude, longitude: pin.longitude)
            loadPhotosFromFlickr(location: pinLocation, completionHandlerForLoadPhotos: { 
                (imagesURL) in
                
                performUIUpdatesOnMain {
                    self.photosCollectionView.reloadData()
                }
            })

        case deleteButtonTitle:
            deleteSelectedPhotos()
            self.newCollectionButton.setTitle(newCollectionButtonTitle, for: .normal)
        
        default:
            break
        }
    }
    
}

// MARK: - MapKit
extension PhotoAlbumViewController {
    
    func presentPin(location: CLLocation) {
        let annotation = MKPointAnnotation()
        annotation.coordinate = location.coordinate
        
        let span = MKCoordinateSpanMake(1, 1)
        let region = MKCoordinateRegionMake(location.coordinate, span)
        
        performUIUpdatesOnMain {
            self.mapView.setRegion(region, animated: true)
            self.mapView.addAnnotation(annotation)
        }
    }
}

// MARK: - Collection View
extension PhotoAlbumViewController: UICollectionViewDelegate {
    
    func configureFlowLayout() {
        let space: CGFloat = 3.0
        let dimension = (self.view.frame.size.width - (2 * space))/4.0
        
        self.flowLayout.minimumInteritemSpacing = space
        self.flowLayout.minimumLineSpacing = space
        self.flowLayout.itemSize = CGSize(width: dimension, height: dimension)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath)
        
        // Fade out the cell and change the button title
        cell?.alpha = 0.5
        self.newCollectionButton.setTitle(deleteButtonTitle, for: .normal)
        self.selectedIndexPath.append(indexPath)
    }
}

extension PhotoAlbumViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return fetchedResultsController.sections![0].numberOfObjects
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "photoViewCell", for: indexPath) as! PhotoCollectionViewCell
        
        cell.showActivityIndicator()
        
        let photoToLoad = fetchedResultsController.object(at: indexPath) as! Photo
        
        if let imageData = photoToLoad.imageData {
            
            print ("There's image data alright!! ---- ")
            performUIUpdatesOnMain {
                cell.hideActivityIndicator()
                cell.photoImage.image = UIImage(data: imageData as Data)
            }
        } else {
            
            flickrClientHandler.getImageDataFrom(url: photoToLoad.imageURL!, completionHandlerForGetImageData: { (imageData) in
                
                performUIUpdatesOnMain {
                    cell.hideActivityIndicator()
                    cell.photoImage.image = UIImage(data: imageData)
                    photoToLoad.imageData = imageData as NSData
                }
                
                self.delegate.stack.save()
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
            print ("inserted new index path: \(String(describing: newIndexPath))")
            break
        
        case .delete:
            deletedIndexPath.append(indexPath!)
            print ("deleted an index path: \(String(describing: indexPath))")
            break
            
        case .update:
            updatedIndexPath.append(indexPath!)
            print ("Updated an index path: \(String(describing: indexPath))")
            break
        
        default:
            break
        }
    }
    
    // When the FRC receives a notification from the coordinator on a change within the context, this method is called to update the UI collection view
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
            
        }, completion:
            { (success) in
                if success {
                    self.insertedIndexPath = []
                    self.deletedIndexPath = []
                    self.updatedIndexPath = []
                }
        })
        
    }
}

