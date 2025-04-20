//
//  AddView.swift
//  Roam
//
//  Created by Joshua Johnson on 3/10/25.
//
import SwiftUI
import GooglePlaces
import GooglePlacesSwift
import FirebaseStorage

struct AddView: View {
    @Binding var goToAddView: Bool
    @Binding var goToMemoryView: Bool
    @Binding var goToHomeView: Bool
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var viewModel: LocationViewModel
    @State private var placeResults: [GMSPlace] = []
    @State private var currentPhoto: UIImage?
    @State private var photoData: ImageData?
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
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    
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
                                        .font(.system(size: 18))
                                    Text("Coordinates: \(String(format: "%.6f", location.coordinate.latitude)), \(String(format: "%.6f", location.coordinate.longitude))")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    Image(systemName: "arrow.triangle.swap")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 18))
                                    Text("Accuracy: \(String(format: "%.1f", location.horizontalAccuracy)) meters")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal)                            
                            
                            Spacer(minLength: 40)
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
                    .background(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: -1)
                }
            } else {
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
        
        let (placeName, _) = await fetchNearbyPlace(location: location)
        
        // Create a temporary UUID for the location
        let locationUUID = UUID()
        
        // Upload the image if available
        var imageUrl: String? = nil
        if let photo = currentPhoto {
            print("Uploading image for location: \(locationUUID)")
            imageUrl = await uploadImage(image: photo, locationId: locationUUID)
            print("Image upload result: \(imageUrl ?? "failed")")
        } else {
            print("No photo available to upload")
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
                    print("Found photo metadata, fetching photo...")
                    let fetchPhotoRequest = GMSFetchPhotoRequest(photoMetadata: photoMetadata, maxSize: CGSizeMake(4800, 4800))
                    GMSPlacesClient.shared().fetchPhoto(with: fetchPhotoRequest, callback: {
                        (photoImage: UIImage?, error: Error?) in
                        if let error = error {
                            print("Error fetching photo: \(error.localizedDescription)")
                            continuation.resume(returning: (results?.first?.name, nil))
                            return
                        }
                        
                        guard let photoImage = photoImage else {
                            print("No photo returned from Google Places")
                            continuation.resume(returning: (results?.first?.name, nil))
                            return
                        }
                        
                        print("Successfully fetched photo of size: \(photoImage.size)")
                        DispatchQueue.main.async {
                            self.currentPhoto = photoImage
                        }
                        
                        continuation.resume(returning: (results?.first?.name, nil))
                    })
                } else {
                    print("No photo metadata available for this place")
                    continuation.resume(returning: (results?.first?.name, nil))
                }
            }
        }
    }
}
