//
//  LocationManager.swift
//  Roam
//
//  Created by Joshua Johnson on 3/10/25.
//

/*
 Got this from:
 https://www.andyibanez.com/posts/using-corelocation-with-swiftui/
 CLLocationManagerDelegate is a protocol - updates users location
 */
import CoreLocation


class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    // creates instance of CLLocationManager
    private var locationManager = CLLocationManager()
    
    // optional location property - this lets UI know when its value changes
    // can be nil so needs to be handled accordingly
    @Published var location: CLLocation?
    
    // initializer
    override init() {
        // calls super's initializer (NSObject)
        super.init()
        
        // dont understand tbh lol
        self.locationManager.delegate = self
        
        // Sets desired accuracy for location updates
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        // requests permission to use location services
        self.locationManager.requestWhenInUseAuthorization()
        
        // starts updating the users location
        self.locationManager.startUpdatingLocation()
    }
    
    // this gets called when the location manager gets an updated location
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // unwraps last location
        guard let location = locations.last else { return }
        self.location = location
    }
    
    // called when authorization changes
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self.locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            self.locationManager.startUpdatingLocation()
        case .restricted, .denied:
            // Handle restriction or denial
            break
        default:
            // catch all statement
            break
        }
    }
}
