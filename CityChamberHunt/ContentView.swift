//
//  ContentView.swift
//  CityChamberHunt
//
//  Created by Irina Saf on 2025-10-01.
//
// ContentView.swift
import SwiftUI

struct ContentView: View {
    @State private var query: String = ""
    @State private var locations: [HuntLocation] = []
    
    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    TextField("Search places (cinema, bakery...)", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                    
                    Button("Go") {
                        LocationAPI.search(query: query) { self.locations = $0 }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top)
                
                List(locations) { loc in
                    NavigationLink(destination: LocationDetailView(location: loc)) {
                        VStack(alignment: .leading) {
                            Text(loc.name).font(.headline)
                            Text(loc.address).font(.subheadline).foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("City Hunt")
        }
    }
}






#Preview {
    ContentView()
}
