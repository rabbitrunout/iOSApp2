//
//  PhotoAPI.swift
//  CityChamberHunt
//
//  Created by Irina Saf on 2025-10-01.
//

import Foundation

// MARK: - Модель для ответа Unsplash
struct PhotoResult: Decodable {
    let urls: Urls
}

struct Urls: Decodable {
    let regular: String
}

// MARK: - API-клиент Unsplash
class PhotoAPI {
    static let shared = PhotoAPI()
    
    private let apiKey: String
    
    init() {
        // Берем ключ из Info.plist
        self.apiKey = Bundle.main.infoDictionary?["UNSPLASH_ACCESS_KEY"] as? String ?? ""
    }
    
    /// Загрузка фото по ключевому слову
    func fetchPhoto(for query: String) async throws -> String? {
        guard let url = URL(string: "https://api.unsplash.com/photos/random?query=\(query)&client_id=\(apiKey)") else {
            return nil
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let result = try JSONDecoder().decode(PhotoResult.self, from: data)
        return result.urls.regular
    }
}
