//
//  LocationViewModel.swift
//  Roam
//
//  Created by Joshua Johnson on 3/10/25.
//
import Foundation

@MainActor
class LocationViewModel: ObservableObject {
    @Published var locations: [LocationData] = []

    func addLocationItem(location: LocationData) {
        Task {
            await addLocation(location: location)
        }
    }
}
