//
//  LocationDetailView.swift
//  CityChamberHunt
//

import SwiftUI
import MapKit
import PhotosUI

struct LocationDetailView: View {
    let location: HuntLocation
    @State private var userImage: UIImage?
    @State private var showCamera = false
    @State private var selectedItem: PhotosPickerItem?
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: location.lat, longitude: location.lon)
    }
    
    var body: some View {
        VStack {
            // Используем FlipCard (берётся из FlipCard.swift)
            FlipCard {
                // FRONT: название + полный адрес + карта
                VStack(spacing: 12) {
                    Text(location.name)
                        .font(.title)
                        .bold()
                        .multilineTextAlignment(.center)
                    
                    Text(location.address)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .lineLimit(nil)
                    
                    // ✅ увеличенная карта
                    Map(initialPosition: .region(
                        MKCoordinateRegion(
                            center: coordinate,
                            latitudinalMeters: 5000,
                            longitudinalMeters: 5000
                        )
                    )) {
                        Marker(location.name, coordinate: coordinate)
                    }
                    .frame(height: 300)
                    .cornerRadius(16)
                    .shadow(radius: 6)
                    
                    // ✅ кнопка "Открыть в Apple Maps"
                    Button {
                        openInAppleMaps()
                    } label: {
                        Label("Open in Apple Maps", systemImage: "map")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                    
                    Spacer()
                    Text("Tap to flip ↻")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: 520)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(radius: 6)
            } back: {
                // BACK: фото пользователя или заглушка
                VStack {
                    if let img = userImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .cornerRadius(12)
                    } else {
                        VStack {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                            Text("No photo yet")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: 350)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(radius: 6)
            }
            .padding()
            
            // Кнопки для фото
            HStack {
                Button {
                    showCamera = true
                } label: {
                    Label("Camera", systemImage: "camera")
                }
                .buttonStyle(.borderedProminent)
                
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("Library", systemImage: "photo")
                }
                .buttonStyle(.bordered)
            }
        }
        .onChange(of: selectedItem) { _, newVal in
            Task {
                if let data = try? await newVal?.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    userImage = img
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker { image in
                if let img = image {
                    userImage = img
                }
            }
        }
    }
    
    // MARK: - Open in Apple Maps
    private func openInAppleMaps() {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = location.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

#Preview {
    LocationDetailView(location: HuntLocation(
        name: "Starlight Cinema",
        address: "123 Main Street, Mississauga, Ontario, Canada L5B 4C4",
        lat: 43.589,
        lon: -79.644
    ))
}
