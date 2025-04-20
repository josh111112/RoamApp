//
//  ImageData.swift
//  Roam
//
//  Created by Joshua Johnson on 4/18/25.
//

import Foundation

struct ImageData: Identifiable, Codable {
    var id = UUID()
    var locationId: UUID
    var url: String
    var filename: String
} 
