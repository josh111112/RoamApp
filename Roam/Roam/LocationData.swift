//
//  LocationData.swift
//  Roam
//
//  Created by Joshua Johnson on 3/10/25.
//
import Foundation
import GooglePlaces

struct LocationData: Identifiable, Codable {
    var id = UUID()
    var name: String?
    var latitude: Double
    var longitude: Double
    var date = Date()
    var imageUrl: String?
}
