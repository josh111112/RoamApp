import FirebaseFirestore
import Foundation
import GooglePlaces
import FirebaseStorage
import SwiftUI

let db = Firestore.firestore()
let storage = Storage.storage()
var listener : ListenerRegistration? = nil

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
            print("started listening")
            print("Read \(parsedLocations.count) locations from Firestore")
            Task { @MainActor in 
                viewModel.locations = parsedLocations
            }
        }
}

func stopListener() {
    if let l = listener {
        l.remove()
    }
    print("stopped listening")
}

func deleteLocation(location: LocationData) async {
    do {
        try await db.collection("locations").document(location.id.uuidString).delete()
        
        // Delete the image if it exists
        if let imageUrl = location.imageUrl {
            let storageRef = storage.reference(forURL: imageUrl)
            try await storageRef.delete()
            print("Image deleted successfully")
        }
        
        print("Location deleted successfully")
    } catch {
        print("Error deleting location: \(error)")
    }
}
