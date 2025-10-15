//
//  LocationAPI.swift
//  CityChamberHunt
//

import Foundation

struct NominatimResult: Decodable {
    let display_name: String
    let lat: String
    let lon: String
}

class LocationAPI {
    static func search(query: String, completion: @escaping ([HuntLocation]) -> Void) {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://nominatim.openstreetmap.org/search?q=\(encoded)&format=json&limit=10&countrycodes=ca"
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async { completion([]) }
            return
        }

        var request = URLRequest(url: url)
        request.setValue("CityChamberHunt/1.0 (irina.safronova@example.com)", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil else {
                print("❌ Network error:", error?.localizedDescription ?? "unknown")
                DispatchQueue.main.async { completion([]) }
                return
            }

            do {
                let decoded = try JSONDecoder().decode([NominatimResult].self, from: data)

                let mapped = decoded.compactMap { result -> HuntLocation? in
                    guard
                        let lat = Double(result.lat),
                        let lon = Double(result.lon),
                        lat != 0, lon != 0
                    else {
                        print("⚠️ Skipped invalid coords for:", result.display_name)
                        return nil
                    }

                    let title = result.display_name.components(separatedBy: ",").first ?? "Unknown"
                    return HuntLocation(
                        name: title,
                        address: result.display_name,
                        lat: lat,
                        lon: lon
                    )
                }

                DispatchQueue.main.async {
                    print("✅ Found \(mapped.count) valid locations")
                    completion(mapped)
                }

            } catch {
                print("❌ Decode error:", error)
                DispatchQueue.main.async { completion([]) }
            }
        }.resume()
    }
}
