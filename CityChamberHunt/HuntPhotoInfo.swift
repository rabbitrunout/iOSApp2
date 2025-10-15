//
//  HuntPhotoInfo.swift
//  CityChamberHunt
//
//  Created by Irina Safronova on 2025-10-15.
//

import Foundation

/// Информация о сделанном фото: где, когда и откуда добавлено
struct HuntPhotoInfo: Codable {
    var filename: String
    var dateAdded: Date
    var source: String       // Camera, Library, Unsplash
    var address: String?     // 📍 место съёмки
    var latitude: Double?    // 🌐 координаты
    var longitude: Double?
}
