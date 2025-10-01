// LocationAPI.swift
import Foundation

struct NominatimResult: Decodable {
    let display_name: String
    let lat: String
    let lon: String
}

class LocationAPI {
    static func search(query: String, completion: @escaping ([HuntLocation]) -> Void) {
        let urlString = "https://nominatim.openstreetmap.org/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&format=json&limit=10&countrycodes=ca"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.setValue("CityHuntApp/1.0 (your_email@example.com)", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data else { return }
            do {
                let decoded = try JSONDecoder().decode([NominatimResult].self, from: data)
                let mapped = decoded.map {
                    HuntLocation(
                        name: $0.display_name.components(separatedBy: ",").first ?? "Unknown",
                        address: $0.display_name,
                        lat: Double($0.lat) ?? 0,
                        lon: Double($0.lon) ?? 0
                    )
                }
                DispatchQueue.main.async { completion(mapped) }
            } catch {
                print("Decode error:", error)
            }
        }.resume()
    }
}
