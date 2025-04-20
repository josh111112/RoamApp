//
//  MemoryView.swift
//  Roam
//
//  Created by Joshua Johnson on 3/10/25.
//

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
                            // shows the detail card
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
            
            // ---------- NAVIGATION BAR ----------
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
        // item: is used instead of isPresented, was causing race conditions
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
    
    func delete(at offsets: IndexSet) {
        let location = viewModel.locations[offsets.first ?? 0]
        Task {
            await deleteLocation(location: location)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
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
