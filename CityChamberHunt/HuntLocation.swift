//
//  HuntLocation.swift
//  CityChamberHunt
//

import Foundation
import CryptoKit

struct HuntLocation: Identifiable, Codable, Hashable {
    let name: String
    let address: String
    let lat: Double
    let lon: Double

    // ✅ Стабильный ID: хеш из имени и адреса
    var id: UUID {
        let baseString = "\(name)_\(address)"
        let hash = Insecure.MD5.hash(data: Data(baseString.utf8))
        let bytes = Array(hash.prefix(16))
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
