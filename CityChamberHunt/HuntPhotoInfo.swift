//
//  HuntPhotoInfo.swift
//  CityChamberHunt
//
//  Created by Irina Saf on 2025-10-08.
//

import Foundation

/// Информация о фото, сделанном пользователем для локации
struct HuntPhotoInfo: Codable {
    var filename: String      // имя файла сохранённого изображения
    var date: Date            // дата съёмки
}
