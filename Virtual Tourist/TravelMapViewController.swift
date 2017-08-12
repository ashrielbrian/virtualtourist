//
//  TravelMapViewController.swift
//  Virtual Tourist
//
//  Created by Ashriel Brian Tang on 29/07/2017.
//  Copyright © 2017 Udacity. All rights reserved.
//

import UIKit
import MapKit
import CoreData


// TO-DO: Review the AppDelegate/shared instance/stack (Core Data) usages in this VC once completed. Make sure you understand it!
class TravelMapViewController: UIViewController, MKMapViewDelegate {

    @IBOutlet weak var mapView: MKMapView!
    
    let delegate = AppDelegate.sharedInstance()
    let flickrClientHandler = FlickrClient.sharedInstance()
    var pinsArray = [Pin]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.delegate = self
        
        // Setting up the Long Press gesture recognizer, and attaching it to the MapView
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(addAnnotationOnMap))
        longPress.minimumPressDuration = 1.5
        mapView.addGestureRecognizer(longPress)
        
        loadPins()
    }
    
    // MARK: Fetch all the pins from Core Data, and store it in the pinsArray
    func loadPins() {
        var annotations = [MKPointAnnotation]()
        let fr = NSFetchRequest<NSFetchRequestResult>(entityName: "Pin")
        fr.sortDescriptors = [NSSortDescriptor(key: "latitude", ascending: true)]
        
        do {
            pinsArray = try delegate.stack.context.fetch(fr) as! [Pin]
        } catch let err{
            print (err.localizedDescription)
        }
        
        for pin in pinsArray {
            let annotation = MKPointAnnotation()
            let coordinate = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
            annotation.coordinate = coordinate
            
            annotations.append(annotation)
        }
        
        mapView.addAnnotations(annotations)
    }
    
    func addAnnotationOnMap(_ gestureRecognizer: UIGestureRecognizer) {
        
        let stack = delegate.stack
        // If the Long Press has begun registering to the GestureRecognizer (i.e. after 1.5 seconds)
        if gestureRecognizer.state == UIGestureRecognizerState.began {
            
            // Converting the tapped Long Press into coordinates MapView can use
            let touchPoint = gestureRecognizer.location(in: mapView)
            let touchCoordinate = mapView.convert(touchPoint, toCoordinateFrom: mapView)
            
            // Initialising the Annotation point and placing it on the map
            let annotation = MKPointAnnotation()
            annotation.coordinate = touchCoordinate
            
            mapView.addAnnotation(annotation)
            
            // TO-DO: the moment the pin is dropped, begin downloading the stuff to do
            DispatchQueue.main.async {
                let pin = Pin(latitude: touchCoordinate.latitude, longitude: touchCoordinate.longitude, context: stack.context)
                self.pinsArray.append(pin)
            }
            
            print("Here's the pinsArray: \(String(describing: pinsArray))")

        }
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        
        // MKAnnotationView is set to false to ensure the annotation view does NOT pop-out on tap
        view.setSelected(false, animated: true)
        
        for pin in pinsArray {
            if pin.latitude == view.annotation?.coordinate.latitude && pin.longitude == view.annotation?.coordinate.longitude {
                goToLocationPhotoAlbum(pin: pin)
            } else {
                print ("Pin not found in Core Data.")
            }
        }
        
        
        // Unselects the current annotation on transitioning to the next VC; this ensures the same pin can be reselected upon return from the PhotoAlbumVC
        mapView.deselectAnnotation(view.annotation, animated: true)
    }
    
    func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
        view.setSelected(false, animated: true)
        
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let reuseID = "pin"
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseID) as? MKPinAnnotationView
        
        // If the pinView is new
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseID)
            pinView?.pinTintColor = UIColor.blue
            pinView?.animatesDrop = true
            pinView?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: nil))
            
            pinView?.setSelected(true, animated: true)
        }
        
        return pinView
    }
    
    private func goToLocationPhotoAlbum(pin: Pin){
        let controller = storyboard?.instantiateViewController(withIdentifier: "PhotoAlbumViewController") as! PhotoAlbumViewController
        controller.pin = pin
        navigationController?.pushViewController(controller, animated: true)
    }

    
}

