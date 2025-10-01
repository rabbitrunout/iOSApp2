//
//  CityChamberHuntApp.swift
//  CityChamberHunt
//
//  Created by Irina Saf on 2025-10-01.
//

import SwiftUI

@main
struct CityChamberHuntApp: App {
    init() {
        let unsplashKey = Bundle.main.infoDictionary?["UNSPLASH_ACCESS_KEY"] as? String ?? ""
        print("🔑 Unsplash Key:", unsplashKey)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

