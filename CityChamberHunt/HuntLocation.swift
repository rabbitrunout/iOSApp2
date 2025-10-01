//
//  HuntLocation.swift
//  CityChamberHunt
//
//  Created by Irina Saf on 2025-10-01.
//

import Foundation

struct HuntLocation: Identifiable {
    let id = UUID()
    let name: String
    let address: String
    let lat: Double
    let lon: Double
    var userPhotoFilename: String? = nil
}

