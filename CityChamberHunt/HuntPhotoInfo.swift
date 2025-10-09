//
//  HuntPhotoInfo.swift
//  CityChamberHunt
//

import Foundation

/// Метаданные о сохранённой фотографии (имя файла + дата)
struct HuntPhotoInfo: Codable {
    var filename: String
    var date: Date
}
