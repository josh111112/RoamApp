# SwiftUI Core Location Tutorial

## Overview
This project is focused on using CoreLocation, Google Places API, and Firebase.
Adding CoreLocation features to your iOS apps is a pretty seamless process. Let's run you through the process.

## Getting Started
- You will need Xcode 16 or higher.
- You will also need to create a Firebase account if you would like to store your data, you can make it here https://firebase.google.com.
- Lastly, we will be using Google Places API (new) and their nearby search feature https://developers.google.com/maps/documentation/places/ios-sdk/nearby-search.


## Steps

1. ### Adding permissions

Once you've created your empty project in Xcode you will need to go to Settings -> info. Press the + next to Bundle name, and insert Privacy - Location When In Use Usage Description. Once you've done that there will be a string value to the right that asks for the text that displays to the user when asking permission. This is basically telling the user why you need their permission, make sure this is convincing because if they say no you won't be able to get their location. 

2. ### Creating an account in Firebase and Google Places API (new)

Firebase has a very in depth guide on how to get started with creating an account. https://firebase.google.com/docs/ios/setup

**We are using Firestore Database and Storage**

Google has good documentation for creating a Google Cloud project. https://developers.google.com/maps/documentation/places/ios-sdk/cloud-setup

**Once you have your account set up you will want to enable Places API (new)**

They will give you an API key which I will show you where to store later.

3. ### Setting up Firebase in your project

After creating your Firebase project, download the `GoogleService-Info.plist` file and add it to your project by dragging it into your Xcode project navigator.

Next, add the Firebase dependencies to your project using Swift Package Manager:
1. Go to File -> Add Packages...
2. Enter the Firebase iOS SDK URL: https://github.com/firebase/firebase-ios-sdk
3. Select the Firebase products you need: FirebaseFirestore and FirebaseStorage

4. ### Setting up Google Places SDK

Add the Google Places SDK to your project using Swift Package Manager:
1. Go to File -> Add Packages...
2. Enter the Google Places SDK URL: https://github.com/googlemaps/google-maps-ios-utils
3. Select the GooglePlaces package

5. ### Initialize Firebase and Google Places in your app

Create a new Swift file for your app's main entry point (e.g., RoamApp.swift) and initialize Firebase and Google Places:

```swift
import SwiftUI
import FirebaseCore
import GooglePlaces

@main
struct RoamApp: App {
    
    init() {
        // Initialize Firebase
        FirebaseApp.configure()
        
        // Initialize Google Places with your API key
        GMSPlacesClient.provideAPIKey("YOUR_API_KEY_HERE")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(LocationManager())
                .environmentObject(LocationViewModel())
        }
    }
}
```

6. ### Creating the Location Manager

Create a `LocationManager.swift` file to handle location services:

```swift
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    // CLLocationManager instance
    private var locationManager = CLLocationManager()
    
    // Published property that will notify UI when location changes
    @Published var location: CLLocation?
    
    override init() {
        super.init()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.requestWhenInUseAuthorization()
        self.locationManager.startUpdatingLocation()
    }
    
    // Called when new locations are available
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.location = location
    }
    
    // Handle changes in authorization status
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
            break
        }
    }
}
```

7. ### Creating data models

Create a `LocationData.swift` file for your location data model:

```swift
import Foundation

struct LocationData: Identifiable {
    var id: UUID
    var name: String?
    var latitude: Double
    var longitude: Double
    var date: Date
    var imageUrl: String?
}
```

Create a `LocationViewModel.swift` file to store and manage location data:

```swift
import Foundation
import Combine

class LocationViewModel: ObservableObject {
    @Published var locations: [LocationData] = []
}
```

8. ### Creating a Firebase Helper

Create a `FireBaseHelper.swift` file to handle interactions with Firebase:

```swift
import FirebaseFirestore
import Foundation
import GooglePlaces
import FirebaseStorage
import SwiftUI

let db = Firestore.firestore()
let storage = Storage.storage()
var listener: ListenerRegistration? = nil

// Add location to Firestore
func addLocation(location: LocationData) async {
    do {
        try await db.collection("locations").document(location.id.uuidString).setData([
            "name": location.name ?? "error getting name",
            "latitude": location.latitude,
            "longitude": location.longitude,
            "date": location.date,
            "imageUrl": location.imageUrl as Any
        ])
        print("Location added successfully")
    } catch {
        print("Error adding location: \(error)")
    }
}

// Upload image to Firebase Storage
func uploadImage(image: UIImage, locationId: UUID) async -> String? {
    guard let imageData = image.jpegData(compressionQuality: 0.7) else {
        print("Failed to convert image to data")
        return nil
    }
    
    let storageRef = storage.reference().child("images/\(locationId.uuidString).jpg")
    
    return await withCheckedContinuation { continuation in
        storageRef.putData(imageData, metadata: nil) { metadata, error in
            if let error = error {
                print("Error uploading image: \(error.localizedDescription)")
                continuation.resume(returning: nil)
                return
            }
            
            storageRef.downloadURL { url, error in
                if let error = error {
                    print("Error getting download URL: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                
                if let downloadURL = url {
                    print("Image uploaded successfully: \(downloadURL.absoluteString)")
                    continuation.resume(returning: downloadURL.absoluteString)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

// Start real-time listener for location updates
func startListener(viewModel: LocationViewModel) {
    listener = db.collection("locations")
        .addSnapshotListener { querySnapshot, error in
            guard let documents = querySnapshot?.documents else {
                print("Error fetching documents: \(error!)")
                return
            }
            var parsedLocations = [LocationData]()
            for document in documents {
                let id = document.documentID
                let data = document.data()
                let name = data["name"] as? String ?? ""
                let latitude = data["latitude"] as? Double ?? 0.0   
                let longitude = data["longitude"] as? Double ?? 0.0
                let timestamp = data["date"] as? Timestamp
                let date = timestamp?.dateValue() ?? Date()
                let imageUrl = data["imageUrl"] as? String
                
                let item = LocationData(
                    id: UUID(uuidString: id) ?? UUID(), 
                    name: name, 
                    latitude: latitude, 
                    longitude: longitude, 
                    date: date,
                    imageUrl: imageUrl
                )
                parsedLocations.append(item)
            }
            
            Task { @MainActor in 
                viewModel.locations = parsedLocations
            }
        }
}

// Stop real-time listener
func stopListener() {
    if let l = listener {
        l.remove()
    }
}

// Delete location and its image from Firebase
func deleteLocation(location: LocationData) async {
    do {
        try await db.collection("locations").document(location.id.uuidString).delete()
        
        // Delete the image if it exists
        if let imageUrl = location.imageUrl {
            let storageRef = storage.reference(forURL: imageUrl)
            try await storageRef.delete()
        }
    } catch {
        print("Error deleting location: \(error)")
    }
}
```

9. ### Creating the main views

Create a `ContentView.swift` file as the container for your app's views:

```swift
import SwiftUI

struct ContentView: View {
    @State private var goToAddView = false
    @State private var goToMemoryView = false
    @State private var goToHomeView = true
    
    var body: some View {
        ZStack {
            if goToHomeView {
                HomeView(goToAddView: $goToAddView, goToMemoryView: $goToMemoryView, goToHomeView: $goToHomeView)
            } else if goToAddView {
                AddView(goToAddView: $goToAddView, goToMemoryView: $goToMemoryView, goToHomeView: $goToHomeView)
            } else if goToMemoryView {
                MemoryView(goToAddView: $goToAddView, goToMemoryView: $goToMemoryView, goToHomeView: $goToHomeView)
            }
        }
    }
}
```

10. ### Home View with Map

Create a `HomeView.swift` file to display a map with location markers:

```swift
import SwiftUI
import MapKit

struct HomeView: View {
    @Binding var goToAddView: Bool
    @Binding var goToMemoryView: Bool
    @Binding var goToHomeView: Bool
    
    @EnvironmentObject var viewModel: LocationViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            Map() {
                ForEach(viewModel.locations) { locationObj in
                    Marker(locationObj.name ?? "error getting name", coordinate: CLLocationCoordinate2D(
                        latitude: locationObj.latitude,
                        longitude: locationObj.longitude
                    ))
                }
            }
            .edgesIgnoringSafeArea(.bottom)
            
            // Navigation Bar
            HStack {
                Button(action: {
                    goToHomeView = true
                    goToAddView = false
                    goToMemoryView = false
                }) {
                    Image(systemName: "house")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .foregroundColor(Color.white)
                }
                Spacer()
                Button(action: {
                    goToAddView = true
                    goToMemoryView = false
                    goToHomeView = false
                }){
                    Image(systemName: "plus.circle")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .foregroundColor(Color.white)
                }
                Spacer()
                Button(action:{
                    goToMemoryView = true
                    goToHomeView = false
                    goToAddView = false
                }){
                    Image(systemName: "clock.fill")
                        .resizable()
                        .frame(width: 28, height: 28)
                        .foregroundColor(Color.white)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: 45)
            .background(Color.gray)
        }
        .onAppear {
            startListener(viewModel: viewModel)
        }
        .onDisappear {
            stopListener()
        }
    }
}
```

11. ### Add View for Creating Memories

Create an `AddView.swift` file to save new location memories:

```swift
import SwiftUI
import GooglePlaces
import FirebaseStorage

struct AddView: View {
    @Binding var goToAddView: Bool
    @Binding var goToMemoryView: Bool
    @Binding var goToHomeView: Bool
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var viewModel: LocationViewModel
    @State private var placeResults: [GMSPlace] = []
    @State private var currentPhoto: UIImage?
    @State private var isSaving: Bool = false
    
    var body: some View {
        VStack {
            if let location = locationManager.location {
                VStack(spacing: 0) {
                    // Header with back button
                    HStack {
                        Button(action: {
                            goToHomeView = true
                            goToMemoryView = false
                            goToAddView = false
                        }){
                            Image(systemName: "arrowshape.turn.up.backward")
                                .resizable()
                                .frame(width: 25, height: 25)
                                .foregroundColor(Color.blue)
                            
                            Text("Back")
                                .foregroundColor(Color.blue)
                                .font(.system(size: 15))
                        }
                        Spacer()
                    }
                    .padding()
                    
                    Text("Save New Memory")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Location information card
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Location Details")
                                    .font(.headline)
                                    .padding(.bottom, 4)
                                
                                HStack {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundColor(.red)
                                    Text("Coordinates: \(String(format: "%.6f", location.coordinate.latitude)), \(String(format: "%.6f", location.coordinate.longitude))")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    Image(systemName: "arrow.triangle.swap")
                                        .foregroundColor(.blue)
                                    Text("Accuracy: \(String(format: "%.1f", location.horizontalAccuracy)) meters")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }
                    
                    // Save button
                    VStack {
                        Button(action: {
                            Task {
                                await saveLocationWithImage(location: location)
                            }
                        }) {
                            HStack {
                                if isSaving {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .padding(.trailing, 8)
                                } else {
                                    Image(systemName: "square.and.arrow.down.fill")
                                        .padding(.trailing, 8)
                                }
                                
                                Text(isSaving ? "Saving..." : "Save Memory")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundColor(.white)
                            .background(Color.blue)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                        .disabled(isSaving)
                        .padding(.bottom, 20)
                    }
                }
            } else {
                // Error view when location not available
                VStack(spacing: 20) {
                    Image(systemName: "location.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    
                    Text("Error Fetching Location")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Please make sure location services are enabled for this app.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    Button(action: {
                        goToHomeView = true
                        goToMemoryView = false
                        goToAddView = false
                    }) {
                        Text("Return to Home")
                            .padding()
                            .foregroundColor(.white)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private func saveLocationWithImage(location: CLLocation) async {
        isSaving = true
        
        // Fetch place name and photo from Google Places API
        let (placeName, _) = await fetchNearbyPlace(location: location)
        
        // Create a temporary UUID for the location
        let locationUUID = UUID()
        
        // Upload the image if available
        var imageUrl: String? = nil
        if let photo = currentPhoto {
            imageUrl = await uploadImage(image: photo, locationId: locationUUID)
        }
        
        // Create and save the location with the image URL
        let tempLocation = LocationData(
            id: locationUUID, 
            name: placeName, 
            latitude: location.coordinate.latitude, 
            longitude: location.coordinate.longitude, 
            date: Date(),
            imageUrl: imageUrl
        )
        
        await addLocation(location: tempLocation)
        
        // Return to home view after saving
        DispatchQueue.main.async {
            isSaving = false
            goToHomeView = true
            goToMemoryView = false
            goToAddView = false
        }
    }
    
    private func fetchNearbyPlace(location: CLLocation) async -> (String?, String?) {
        return await withCheckedContinuation { continuation in
            let circularLocationRestriction = GMSPlaceCircularLocationOption(
                CLLocationCoordinate2DMake(location.coordinate.latitude, location.coordinate.longitude),
                30
            )
            let placeProperties = [GMSPlaceProperty.name, GMSPlaceProperty.photos].map { $0.rawValue }
            let request = GMSPlaceSearchNearbyRequest(
                locationRestriction: circularLocationRestriction,
                placeProperties: placeProperties
            )
            
            GMSPlacesClient.shared().searchNearby(with: request) { results, error in
                if let error = error {
                    print("Error searching nearby places: \(error.localizedDescription)")
                    continuation.resume(returning: (nil, nil))
                    return
                }
                
                DispatchQueue.main.async {
                    self.placeResults = results ?? []
                }

                // Get the first photo metadata if available
                if let photoMetadata = results?.first?.photos?.first {
                    let fetchPhotoRequest = GMSFetchPhotoRequest(photoMetadata: photoMetadata, maxSize: CGSizeMake(4800, 4800))
                    GMSPlacesClient.shared().fetchPhoto(with: fetchPhotoRequest, callback: {
                        (photoImage: UIImage?, error: Error?) in
                        if let error = error {
                            print("Error fetching photo: \(error.localizedDescription)")
                            continuation.resume(returning: (results?.first?.name, nil))
                            return
                        }
                        
                        guard let photoImage = photoImage else {
                            continuation.resume(returning: (results?.first?.name, nil))
                            return
                        }
                        
                        DispatchQueue.main.async {
                            self.currentPhoto = photoImage
                        }
                        
                        continuation.resume(returning: (results?.first?.name, nil))
                    })
                } else {
                    continuation.resume(returning: (results?.first?.name, nil))
                }
            }
        }
    }
}
```

12. ### Memory View for Displaying Saved Locations

Create a `MemoryView.swift` file to display and manage saved locations:

```swift
import SwiftUI
import GooglePlaces

struct MemoryView: View {
    @Binding var goToAddView: Bool
    @Binding var goToMemoryView: Bool
    @Binding var goToHomeView: Bool
    @EnvironmentObject var viewModel: LocationViewModel
    @State private var loadingImages = [UUID: Bool]()
    @State private var images = [UUID: UIImage]()
    @State private var selectedLocation: LocationData? = nil
    
    var body: some View {
        VStack {
            Spacer()
            List {
                ForEach(viewModel.locations) { locationItem in
                    VStack(alignment: .leading) {
                        Button(action: {
                            // Shows the detail card
                            selectedLocation = locationItem
                            // Checks if the image is loaded, if not, it will load the image
                            if images[locationItem.id] == nil && loadingImages[locationItem.id] != true {
                                if let imageUrl = locationItem.imageUrl {
                                    loadImage(from: imageUrl, for: locationItem.id)
                                }
                            }
                        }){
                            VStack(alignment: .leading, spacing: 8) {
                                Text(locationItem.name ?? "error getting name")
                                    .font(.headline)

                                Text("Date: \(formatDate(locationItem.date))")
                                    .font(.caption)
                            }
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .onDelete(perform: delete)
            }
            Spacer()
            
            // Navigation Bar
            HStack {
                Button(action: {
                    goToHomeView = true
                    goToAddView = false
                    goToMemoryView = false
                }) {
                    Image(systemName: "house")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .foregroundColor(Color.white)
                }
                
                Spacer()
                
                Button(action: {
                    goToAddView = true
                    goToMemoryView = false
                    goToHomeView = false
                }){
                    Image(systemName: "plus.circle")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .foregroundColor(Color.white)
                }
                Spacer()
                
                Button(action:{
                    goToMemoryView = true
                    goToHomeView = false
                    goToAddView = false
                }){
                    Image(systemName: "clock.fill")
                        .resizable()
                        .frame(width: 28, height: 28)
                        .foregroundColor(Color.white)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: 45)
            .background(Color.gray)
        }
        // Detail sheet for selected location
        .sheet(item: $selectedLocation) { location in
            VStack {
                Text(location.name ?? "Location")
                    .font(.title)
                    .padding()
                
                if let image = images[location.id] {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding()
                } else if loadingImages[location.id] == true {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: 300)
                } else if location.imageUrl != nil {
                    Button("Load Image") {
                        if let imageUrl = location.imageUrl {
                            loadImage(from: imageUrl, for: location.id)
                        }
                    }
                    .padding()
                } else {
                    Text("No image available")
                        .padding()
                }
                
                Text("Date: \(formatDate(location.date))")
                
                Text("Location: \(location.latitude), \(location.longitude)")
                    .padding(.bottom)
                
                Button("Close") {
                    selectedLocation = nil
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.bottom)
            }
        }
        .onAppear {
            startListener(viewModel: viewModel)
        }
        .onDisappear {
            stopListener()
        }
    }
    
    // Delete a location
    func delete(at offsets: IndexSet) {
        let location = viewModel.locations[offsets.first ?? 0]
        Task {
            await deleteLocation(location: location)
        }
    }
    
    // Format date for display
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Load image from URL
    private func loadImage(from urlString: String, for locationId: UUID) {
        // Set loading state
        loadingImages[locationId] = true
        
        guard let url = URL(string: urlString) else {
            loadingImages[locationId] = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error loading image: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    loadingImages[locationId] = false
                }
                return
            }
            
            guard let data = data, let image = UIImage(data: data) else {
                DispatchQueue.main.async {
                    loadingImages[locationId] = false
                }
                return
            }
            
            DispatchQueue.main.async {
                images[locationId] = image
                loadingImages[locationId] = false
            }
        }.resume()
    }
}
```

13. ### Adding Google Places API Key to Info.plist

You need to add your Google Places API key to your Info.plist file:

1. Open your Info.plist file
2. Add a new key: `GMSPlacesAPIKey`
3. Set the value to your Google Places API key

14. ### Testing the App

Now your app should be ready to run! Here's a summary of what it does:

1. The app initializes Firebase and Google Places API on startup
2. It requests location permissions from the user
3. The home view displays a map with markers for all saved locations
4. The add view lets you save your current location as a memory, fetching nearby place information from Google Places API
5. The memory view displays a list of all saved locations with the ability to view details and delete locations
6. Firebase Firestore is used to store location data and Firebase Storage is used to store images
7. Real-time updates are implemented using Firestore listeners

## Conclusion

Congratulations! You've built a location-based iOS app with SwiftUI that uses CoreLocation, Google Places API, and Firebase. The app allows users to save memories at their current locations, complete with place names and images fetched from Google Places API. The data is stored in Firebase, allowing for real-time updates and synchronization across devices. 