//
//  MapViewController.swift
//  oldNYC-iOS
//
//  Created by Orian Breaux and Christina Leuci.
//  Copyright © 2016 OldNYC. All rights reserved.
//

import UIKit
import CoreLocation
import Mapbox
import SwiftyJSON

class MapViewController: UIViewController,
                         MGLMapViewDelegate,
                         CLLocationManagerDelegate {

    private var foregroundNotification : NSObjectProtocol!
    
    var mapView : MGLMapView!
    var lastTappedLocationData = [[String : Any]]()
    var lastTappedLocationName : String = ""
    let locationManager = CLLocationManager()

    @IBOutlet weak var mapBrandingLogo: UIImageView!
    @IBOutlet weak var menuButton : UIButton!
    @IBAction func tappedMenuButton(sender: AnyObject) {
        performSegueWithIdentifier("toMenu", sender: nil)
    }
    @IBOutlet weak var centerOnUserButton : UIButton!
    @IBAction func tappedCenterOnUserbutton(sender: UIButton) {
        
        let fromCamera = mapView.camera
        
        let toCamera = MGLMapCamera(lookingAtCenterCoordinate: (mapView.userLocation?.coordinate)!, fromDistance: fromCamera.altitude, pitch: 0, heading: 0)

        mapView.setCamera(toCamera, withDuration: 0.5, animationTimingFunction: CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear), completionHandler: {() -> Void in self.mapView.setUserTrackingMode(.Follow, animated:false)})
    }
    
    override func viewWillAppear(animated: Bool) {
        self.navigationController?.setNavigationBarHidden(true, animated:false)
        self.navigationController?.navigationBar.barStyle = UIBarStyle.Black
        self.navigationController?.navigationBar.tintColor = UIColor.whiteColor()
    }
    
    override func viewDidAppear(animated: Bool) {
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView = MGLMapView(frame: view.bounds, styleURL: MGLStyle.lightStyleURL())
        mapView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        
        // Configure map settings.
        mapView.showsUserLocation = true
        mapView.logoView.hidden = true
        mapView.attributionButton.hidden = true
        mapView.scrollEnabled = true
        mapView.rotateEnabled = false
        mapView.pitchEnabled = false
        
        // Set the map's center coordinate over NYC.
        let startingLocation:CLLocation = CLLocation(latitude: 40.71356, longitude: -73.99084)
        mapView.setCenterCoordinate(CLLocationCoordinate2D(latitude: startingLocation.coordinate.latitude, longitude: startingLocation.coordinate.longitude), zoomLevel:12, animated:false)
        mapView.minimumZoomLevel = 10
        mapView.maximumZoomLevel = 18
        
        view.addSubview(mapView)
        view.bringSubviewToFront(menuButton)
        view.bringSubviewToFront(mapBrandingLogo)
        
        mapView.delegate = self
        
        
        // Place marker annotations on map.
        generateMarkersFromJSON()
        
        locationManager.requestWhenInUseAuthorization()
        
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            locationManager.startUpdatingLocation()
        }
        
        if CLLocationManager.authorizationStatus() == .AuthorizedWhenInUse {
            foregroundNotification = NSNotificationCenter.defaultCenter().addObserverForName(UIApplicationWillEnterForegroundNotification, object: nil, queue: NSOperationQueue.mainQueue()) {
                [unowned self] notification in
                
                print("app is in foreground")
                
                
                if let currentCoordinates : CLLocationCoordinate2D = self.locationManager.location?.coordinate {
                    print(currentCoordinates)
                    self.isUserInNYC(currentCoordinates, completion: { (answer) in
                        if answer == true {
                            print(currentCoordinates)
                            self.centerOnUserLocation(currentCoordinates)
                            self.view.bringSubviewToFront(self.centerOnUserButton)
                        } else if answer == false {
                            self.view.sendSubviewToBack(self.centerOnUserButton)
                        }
                    })
                }
            }
        }
    }
    
    override func viewWillDisappear(animated: Bool) {
        self.navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
    
    deinit {
        // make sure to remove the observer when this view controller is dismissed/deallocated
        NSNotificationCenter.defaultCenter().removeObserver(foregroundNotification)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        if status == .AuthorizedWhenInUse || status == .AuthorizedAlways {
            let currentCoordinates : CLLocationCoordinate2D = manager.location!.coordinate
            //let currentCoordinates = CLLocationCoordinate2D(latitude: 40.761850, longitude: -73.887072)
            
            self.isUserInNYC(currentCoordinates, completion: { (answer) in
                if answer == true {
                    self.centerOnUserLocation(currentCoordinates)
                    self.view.bringSubviewToFront(self.centerOnUserButton)
                } else if answer == false {
                    self.view.sendSubviewToBack(self.centerOnUserButton)
                }
            })
        }
    }
    
    
//********** FUNCTIONS FOR GENERATING MAP UI **********//
    
    // Read markers.json, and generate markers for each coordinate.
    func generateMarkersFromJSON() {
        if let path = NSBundle.mainBundle().pathForResource("markers", ofType: "json") {
            do {
                let data = try NSData(contentsOfURL: NSURL(fileURLWithPath: path), options: NSDataReadingOptions.DataReadingMappedIfSafe)
                let jsonObj = JSON(data: data)
                if jsonObj != JSON.null {

                    // Create markers for each item.
                    for item in jsonObj["markers"].arrayValue {
                        let lat = item["latitude"].double
                        let lon = item["longitude"].double
                        let title = item["marker_title"].stringValue
                        placeMarker(lat!, lon: lon!, title: title)
                    }
                    
                } else {
                    print("could not get json from file")
                }
            } catch let error as NSError {
                print(error.localizedDescription)
            }
        } else {
            print("Invalid filename/path.")
        }
    }
    
    // Creates a marker annotation for the given lat and lon.
    func placeMarker(lat: Double, lon: Double, title: String) {
        let marker = MGLPointAnnotation()
        marker.coordinate = CLLocationCoordinate2DMake(lat, lon)
        marker.title = title
        
        mapView.addAnnotation(marker)
    }
    
    // Define and use custom marker style
    func mapView(mapView: MGLMapView, imageForAnnotation annotation: MGLAnnotation) -> MGLAnnotationImage? {
        var annotationImage = mapView.dequeueReusableAnnotationImageWithIdentifier("LocationMarker")
        
        if annotationImage == nil {
            let image = UIImage(named: "LocationMarker")
            annotationImage = MGLAnnotationImage(image: image!, reuseIdentifier: "LocationMarker")
        }
        
        return annotationImage
    }
    
    // When user taps on marker annotation, retrieve image information for given location.
    func mapView(mapView: MGLMapView, didSelectAnnotation annotation: MGLAnnotation) {
        let tappedLat = String(format:"%2.6f", annotation.coordinate.latitude)
        let tappedLon = String(format:"%2.6f", annotation.coordinate.longitude)
        
        lastTappedLocationName = annotation.title!!

        let jsonPath = "by-location/" + tappedLat + tappedLon
        
        if let path = NSBundle.mainBundle().pathForResource(jsonPath, ofType: "json") {
            do {
                let data = try NSData(contentsOfURL: NSURL(fileURLWithPath: path), options: NSDataReadingOptions.DataReadingMappedIfSafe)
                let jsonObj = JSON(data: data)
                if jsonObj != JSON.null {
                    
                    self.setLastTappedLocationData(jsonObj)
                    self.performSegueWithIdentifier("toGallery", sender: self)
                    
                } else {
                    print("could not get json from file")
                }
            } catch let error as NSError {
                print(error.localizedDescription)
            }
        } else {
            print("Invalid filename/path.")
        }
        
        mapView.deselectAnnotation(annotation, animated: false)
    }
    
    func mapView(mapView: MGLMapView, didDeselectAnnotation annotation: MGLAnnotation) {
    }
    
    func getLastTappedLocationData() -> [[String : Any]] {
        return lastTappedLocationData
    }
    
    func setLastTappedLocationData(jsonObj : JSON) {
        self.lastTappedLocationData.removeAll()
        
        // For each image in location's JSON data, save attributes into dictionary.
        for (key,subJson):(String,JSON) in jsonObj {
            var dict = [String : Any]()
            
            dict["photoID"] = key
            dict["width"] = subJson["width"].double
            dict["height"] = subJson["width"].double
            dict["image_url"] = subJson["image_url"].stringValue
            dict["thumb_url"] = subJson["thumb_url"].stringValue
            dict["title"] = subJson["title"].stringValue
            
            if(subJson["date"].stringValue == ""){
                dict["date"] = "No Date"
            } else {
                dict["date"] = subJson["date"].stringValue
            }
            
            dict["folder"] = subJson["folder"].stringValue
            dict["description"] = subJson["text"].stringValue
            dict["rotation"] = subJson["rotation"].double
            
            self.lastTappedLocationData.append(dict)
        }
        
        // Sort "image" elements in lastTappedLocationData by year
        lastTappedLocationData.sortInPlace{ ($0["date"] as? String) < ($1["date"] as? String) }
    }
    
    func isUserInNYC(currentCoordinates: CLLocationCoordinate2D, completion: (answer: Bool?) -> Void) {
        let location = CLLocation(latitude: currentCoordinates.latitude, longitude: currentCoordinates.longitude)
        let geocoder = CLGeocoder()
        
//        print("-> Finding user address...")
        
        geocoder.reverseGeocodeLocation(location, completionHandler: {(placemarks, error)->Void in
            var placemark:CLPlacemark!
            
            if error == nil && placemarks!.count > 0 {
                placemark = placemarks![0] as CLPlacemark
                
//                print("Locality:" + placemark.locality!)
//                print(placemark.administrativeArea)
//                print("subAdmin:" + placemark.subAdministrativeArea!)
//                print("subLocality:" + placemark.subLocality!)
//                print(placemark.ocean)
//                print(placemark.inlandWater)
                
                if (placemark.locality == "New York" && placemark.inlandWater == nil) {
                    completion(answer: true)
                } else {
                    completion(answer: false)
                }
            }
        })
    }
    
    func centerOnUserLocation(currentCoordinates: CLLocationCoordinate2D) {
        let fromCamera = self.mapView.camera
        let toCamera = MGLMapCamera(lookingAtCenterCoordinate: currentCoordinates, fromDistance: fromCamera.altitude, pitch: 0, heading: 0)
        
        self.mapView.setCamera(toCamera, withDuration: 0.75, animationTimingFunction: CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear), completionHandler: {() -> Void in
            self.mapView.setZoomLevel(14, animated: true)
            
            //self.mapView.setUserTrackingMode(.Follow, animated:false)
        })
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender:AnyObject!){
        if (segue.identifier == "toGallery"){
            let svc = segue.destinationViewController as! PhotoGalleryViewController;
            svc.lastTappedLocationDataPassed = self.lastTappedLocationData
            svc.lastTappedLocationName = self.lastTappedLocationName
            let backItem = UIBarButtonItem()
            backItem.title = ""
            navigationItem.backBarButtonItem = backItem
        }
    }
    
    override func shouldPerformSegueWithIdentifier(identifier: String, sender: AnyObject!) -> Bool {
        if identifier == "toGallery"{
            if (self.lastTappedLocationData.isEmpty == true){
                return false
            }
        }
        return true
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true;
    }
}