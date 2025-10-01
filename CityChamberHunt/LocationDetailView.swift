//
//  LocationDetailView.swift
//  CityChamberHunt
//

import SwiftUI
import MapKit
import PhotosUI

struct LocationDetailView: View {
    let location: HuntLocation
    @State private var userImage: UIImage?          // фото из камеры/галереи
    @State private var showCamera = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var photoURL: URL?               // фото из Unsplash
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: location.lat, longitude: location.lon)
    }
    
    var body: some View {
        VStack {
            // ✅ Используем FlipCard
            FlipCard {
                // FRONT: название + адрес + карта
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
                // BACK: фото (своё или из API)
                VStack {
                    if let img = userImage {
                        // Фото из камеры или библиотеки
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .cornerRadius(12)
                    } else if let url = photoURL {
                        // Фото из Unsplash
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView("Loading...")
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 300)
                                    .cornerRadius(12)
                            case .failure:
                                VStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.red)
                                    Text("Error loading photo")
                                        .foregroundColor(.secondary)
                                }
                            @unknown default:
                                EmptyView()
                            }
                        }
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
        .onAppear {
            // ✅ Загружаем фото с Unsplash, если пользователь не сделал своё
            if userImage == nil && photoURL == nil {
                Task {
                    if let urlString = try? await PhotoAPI.shared.fetchPhoto(for: location.name),
                       let url = URL(string: urlString) {
                        photoURL = url
                    }
                }
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
        let mapItem = MKMapItem(
            location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
            address: nil
        )
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
