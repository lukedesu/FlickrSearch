//
//  FlickrSearcher.swift
//  flickrSearch
//
//  Created by Richard Turton on 31/07/2014.
//  Modified by John Difool on 10/01/2015.
//  Copyright (c) 2014 Razeware. All rights reserved.
//

import Foundation
import UIKit

let apiKey = "ecf021515187ae91b309e983ff2b9609"

struct FlickrSearchResults {
  let searchTerm : String
  let searchResults : [FlickrPhoto]
}

class FlickrPhoto : Equatable {
  var thumbnail : UIImage?
  var largeImage : UIImage?
  let photoID : String
  let farm : Int
  let server : String
  let secret : String
  
  init (photoID:String,farm:Int, server:String, secret:String) {
    self.photoID = photoID
    self.farm = farm
    self.server = server
    self.secret = secret
  }
  
  func flickrImageURL(size:String = "m") -> NSURL {
    return NSURL(string: "https://farm\(farm).staticflickr.com/\(server)/\(photoID)_\(secret)_\(size).jpg")!
  }
  
  func loadLargeImage(completion: (flickrPhoto:FlickrPhoto, error: NSError?) -> Void) {
    let loadURL = flickrImageURL("b")
    let loadRequest = NSURLRequest(URL:loadURL)
    let loadSession = NSURLSession.sharedSession()

    let task = loadSession.dataTaskWithRequest(loadRequest, completionHandler: {data, response, error in
    
        if error != nil {
          completion(flickrPhoto: self, error: error)
          return
        }
        
        if data != nil {
          let returnedImage = UIImage(data: data!)
          self.largeImage = returnedImage
          completion(flickrPhoto: self, error: nil)
          return
        }
        
        completion(flickrPhoto: self, error: nil)
    })
    task.resume()
  }
  
  func sizeToFillWidthOfSize(size:CGSize) -> CGSize {
    if thumbnail == nil {
      return size
    }
    
    let imageSize = thumbnail!.size
    var returnSize = size
    
    let aspectRatio = imageSize.width / imageSize.height
    
    returnSize.height = returnSize.width / aspectRatio
    
    if returnSize.height > size.height {
      returnSize.height = size.height
      returnSize.width = size.height * aspectRatio
    }
    
    return returnSize
  }
  
}

func == (lhs: FlickrPhoto, rhs: FlickrPhoto) -> Bool {
  return lhs.photoID == rhs.photoID
}

class Flickr {
  
  func searchFlickrForTerm(searchTerm: String, completion : (results: FlickrSearchResults?, error : NSError?) -> Void) {
    
    let searchURL = flickrSearchURLForSearchTerm(searchTerm)
    let searchRequest = NSURLRequest(URL: searchURL)
    let searchSession = NSURLSession.sharedSession()

    let task = searchSession.dataTaskWithRequest(searchRequest, completionHandler: {data, response, error in

      if error != nil {
        completion(results: nil,error: error)
        return
      }
      
      do {
        let resultsDictionary = try NSJSONSerialization.JSONObjectWithData(data!, options: []) as! NSDictionary
        
        
        switch (resultsDictionary["stat"] as! String) {
        case "ok":
            print("Results processed OK")
        case "fail":
            let APIError = NSError(domain: "FlickrSearch", code: 0, userInfo: [NSLocalizedFailureReasonErrorKey:resultsDictionary["message"]!])
            completion(results: nil, error: APIError)
            return
        default:
            let APIError = NSError(domain: "FlickrSearch", code: 0, userInfo: [NSLocalizedFailureReasonErrorKey:"Uknown API response"])
            completion(results: nil, error: APIError)
            return
        }
        
        let photosContainer = resultsDictionary["photos"] as! NSDictionary
        let photosReceived = photosContainer["photo"] as! [NSDictionary]
        
        let flickrPhotos : [FlickrPhoto] = photosReceived.map {
            photoDictionary in
            
            let photoID = photoDictionary["id"] as? String ?? ""
            let farm = photoDictionary["farm"] as? Int ?? 0
            let server = photoDictionary["server"] as? String ?? ""
            let secret = photoDictionary["secret"] as? String ?? ""
            
            let flickrPhoto = FlickrPhoto(photoID: photoID, farm: farm, server: server, secret: secret)
            
            let imageData = NSData(contentsOfURL: flickrPhoto.flickrImageURL())
            flickrPhoto.thumbnail = UIImage(data: imageData!)
            
            return flickrPhoto
        }
        
        dispatch_async(dispatch_get_main_queue(), {
            completion(results:FlickrSearchResults(searchTerm: searchTerm, searchResults: flickrPhotos), error: nil)
        })

    } catch let JSONError as NSError {
        completion(results: nil, error: JSONError)
        return
    }
    })
    task.resume()
  }
  
  private func flickrSearchURLForSearchTerm(searchTerm:String) -> NSURL {
    
    let escapedTerm = searchTerm.stringByAddingPercentEncodingWithAllowedCharacters(.URLQueryAllowedCharacterSet())!

    let URLString = "https://api.flickr.com/services/rest/?method=flickr.photos.search&api_key=\(apiKey)&text=\(escapedTerm)&per_page=20&format=json&nojsoncallback=1"
    return NSURL(string: URLString)!
  }
  
  
}
