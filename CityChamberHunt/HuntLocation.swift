//
//  HuntLocation.swift
//  CityChamberHunt
//

import Foundation
import CoreLocation

/// Модель локации для игры City Chamber Hunt
struct HuntLocation: Identifiable, Codable, Hashable {
    /// Уникальный ID: комбинация имени и адреса (устойчивый между сессиями)
    var id: String { "\(name)_\(address)".replacingOccurrences(of: " ", with: "_") }

    let name: String
    let address: String
    let lat: Double
    let lon: Double
}
