import Foundation
import CoreLocation

struct HuntLocation: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let address: String
    let lat: Double
    let lon: Double

    init(id: UUID = UUID(), name: String, address: String, lat: Double, lon: Double) {
        self.id = id
        self.name = name
        self.address = address
        self.lat = lat
        self.lon = lon
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}
