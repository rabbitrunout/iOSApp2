//
//  HuntPhotoInfo.swift
//  CityChamberHunt
//

import Foundation

struct HuntPhotoInfo: Codable {
    var filename: String          // Имя файла изображения
    var dateAdded: Date           // Когда добавлено
    var source: String            // "Camera", "Library", "Unsplash"
}
