//
//  FlickrClient.swift
//  Virtual Tourist
//
//  Created by Ashriel Brian Tang on 02/08/2017.
//  Copyright © 2017 Udacity. All rights reserved.
//

import UIKit
import MapKit

class FlickrClient: NSObject {
    
    let session = URLSession.shared
    let urlParameters = [
        FlickrConstants.FlickrParameterKeys.Format : FlickrConstants.FlickrParameterValues.ResponseFormat,
        FlickrConstants.FlickrParameterKeys.Method : FlickrConstants.FlickrParameterValues.SearchMethod,
        FlickrConstants.FlickrParameterKeys.APIKey : FlickrConstants.FlickrParameterValues.APIKey,
        FlickrConstants.FlickrParameterKeys.Extras : FlickrConstants.FlickrParameterValues.MediumURL,
        FlickrConstants.FlickrParameterKeys.SafeSearch : FlickrConstants.FlickrParameterValues.UseSafeSearch,
        FlickrConstants.FlickrParameterKeys.NoJSONCallback : FlickrConstants.FlickrParameterValues.DisableJSONCallback,
    ] as [String: AnyObject]
    
    class func sharedInstance() -> FlickrClient {
        struct Singleton {
            static var instance = FlickrClient()
        }
        return Singleton.instance
    }
    
    func getImages(withPageNumber: Int? = nil, location: CLLocationCoordinate2D, completionHandlerForGetImages: @escaping (_ success: Bool, _ errorString: String?,_ imagesURL: [String]?) -> Void) {
        
        print ("Hello getImages!!")
        var methodParameters = urlParameters
        var imagesURLs = [String]()
        
        // Preparing parameters
        if (withPageNumber != nil) {
            methodParameters[FlickrConstants.FlickrParameterKeys.Page] = withPageNumber as AnyObject
        }
        
        methodParameters[FlickrConstants.FlickrParameterKeys.BoundingBox] = self.bboxString(location: location) as AnyObject
        
        let url = flickrURLFromParameters(methodParameters)
        let request = URLRequest(url: url)
        print (url)
        
        let task = session.dataTask(with: request) {
            (data, response, error) in
            
            func sendError(_ error: String) {
                print (error)
                completionHandlerForGetImages(false, error, nil)
            }
            
            guard (error == nil) else {
                sendError("There was an error in the request to Flickr")
                return
            }
            
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200, statusCode <= 299 else {
                sendError("The status code did not return 2xx")
                return
            }
            
            guard let data = data else {
                sendError("No data returned from the request")
                return
            }
            
            self.convertDataWithCompletionHandler(data, completionHandlerForConvertData: {
                (parsedJSON, error) in
                
                guard (error == nil) else {
                    sendError("\(String(describing: error))")
                    return
                }
                
                if let parsedJSON = parsedJSON {
                    guard let photosDictionary = parsedJSON[FlickrConstants.FlickrResponseKeys.Photos] as? [String: AnyObject] else {
                        sendError("Could not find response key \(FlickrConstants.FlickrResponseKeys.Photos) in \(parsedJSON)")
                        return
                    }
                    
                    // Checks if the page number is random; if not, assigns a new random page number based on the response and reruns the request
                    if withPageNumber == nil {
                        guard let totalPages = photosDictionary[FlickrConstants.FlickrResponseKeys.Pages] as? Int else {
                            sendError("Could not find response key \(FlickrConstants.FlickrResponseKeys.Pages) in \(photosDictionary)")
                            return
                        }
                        
                        let pageNumber = min(totalPages, 16)
                        let newRandomPage = Int(arc4random_uniform(UInt32(pageNumber))) + 1
                        
                        print("------First time getImages()-------")
                        self.getImages(withPageNumber: newRandomPage, location: location, completionHandlerForGetImages: completionHandlerForGetImages)
                    } else {
                        
                        print ("------Second time getImages()-------")
                        
                        guard let photoDictionary = photosDictionary[FlickrConstants.FlickrResponseKeys.Photo] as? [[String: AnyObject]] else {
                            sendError("Could not find response key \(FlickrConstants.FlickrResponseKeys.Photo) in \(photosDictionary)")
                            return
                        }
                        
                        if photoDictionary.count != 0 {
                            let numOfPhotos = Int(arc4random_uniform(UInt32(photoDictionary.count)))
                            //let photosIndex = min(25, numOfPhotos)
                            
                            imagesURLs = self.arrayFromDictionary(minNumOfItems: 25, totalNumOfItems: numOfPhotos, appendFrom: photoDictionary, key: FlickrConstants.FlickrResponseKeys.MediumURL)
                            
                            completionHandlerForGetImages(true, nil, imagesURLs)
                            print("Here are the imagesURLs --- \(imagesURLs)")
                            
                            
                        } else {
                            sendError("There are no images for this location. Try again.")
                        }
                        
                    }
                }
                
            })
            
        }
        
        task.resume()
        
    }
}

extension FlickrClient {
    
    // MARK: - Network Utils
    func convertDataWithCompletionHandler(_ data: Data, completionHandlerForConvertData: (_ result: AnyObject?, _ error: NSError?) -> Void) {
        
        var parsedJSON: AnyObject? = nil
        
        do {
            parsedJSON = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as AnyObject
        } catch {
            let userInfo = [NSLocalizedDescriptionKey: "Could not parse JSON in \(data)"]
            completionHandlerForConvertData(nil, NSError(domain: "convertDataWithCompletionHandler", code: 1, userInfo: userInfo))
        }
        
        completionHandlerForConvertData(parsedJSON, nil)
    }
    
    internal func flickrURLFromParameters(_ parameters: [String: AnyObject]) -> URL {
        var components = URLComponents()
        components.scheme = FlickrConstants.Flickr.APIScheme
        components.host = FlickrConstants.Flickr.APIHost
        components.path = FlickrConstants.Flickr.APIPath
        components.queryItems = [URLQueryItem]()
        
        for (key, value) in parameters {
            let queryItem = URLQueryItem(name: key, value: "\(value)")
            components.queryItems?.append(queryItem)
        }
        
        return components.url!
    }
    
    // MARK: - Utils
    // Obtains the values of a specific key from an array of dictionaries, and appends it to an empty array. Number of values appended corresponds to the lower of the two input Ints
    func arrayFromDictionary(minNumOfItems: Int, totalNumOfItems: Int, appendFrom dictionaries: [[String: AnyObject]], key: String) -> [String]{
        
        var arrayOfItems = [String]()
        let minValue = min(minNumOfItems, totalNumOfItems)
        
        if minValue != 0 {
            for i in 1...minValue {
                let targetDictionary = dictionaries[i]
                arrayOfItems.append(targetDictionary[key] as! String)
            }
        }
        
        
        return arrayOfItems
    }
}


extension FlickrClient {
    // MARK: - Flickr Coordinates Configuration
    internal func bboxString(location: CLLocationCoordinate2D) -> String {
        
        let latitude = Double(location.latitude)
        let longitude = Double(location.longitude)
        
        var minLat = latitude - FlickrConstants.Flickr.SearchBBoxHalfWidth
        var maxLat = latitude + FlickrConstants.Flickr.SearchBBoxHalfWidth
        var minLong = longitude - FlickrConstants.Flickr.SearchBBoxHalfHeight
        var maxLong = longitude + FlickrConstants.Flickr.SearchBBoxHalfHeight
        
        if minLat < 0 {
            minLat = max(minLat, FlickrConstants.Flickr.SearchLatRange.0)
        } else if minLat > 0 {
            minLat = min(minLat, FlickrConstants.Flickr.SearchLatRange.1)
        }
        
        if maxLat < 0 {
            maxLat = max(maxLat, FlickrConstants.Flickr.SearchLatRange.0)
        } else if maxLat > 0 {
            maxLat = min(maxLat, FlickrConstants.Flickr.SearchLatRange.1)
        }
        
        if minLong < 0 {
            minLong = max(minLong, FlickrConstants.Flickr.SearchLonRange.0)
        } else if minLong > 0 {
            minLong = min(minLong, FlickrConstants.Flickr.SearchLonRange.1)
        }
        
        if maxLong < 0 {
            maxLong = max(maxLong, FlickrConstants.Flickr.SearchLonRange.0)
        } else if maxLong > 0 {
            maxLong = min(maxLong, FlickrConstants.Flickr.SearchLonRange.1)
        }
        
        return "\(minLong),\(minLat),\(maxLong),\(maxLat)"
        
    }
}
