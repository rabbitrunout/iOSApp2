//
//  LocationDetailView.swift
//  CityChamberHunt
//
//  Created by Irina Saf on 2025-10-08.
//

import SwiftUI
import MapKit
import PhotosUI

struct LocationDetailView: View {
    let location: HuntLocation
    let onSavePhoto: (HuntLocation, UIImage) -> Void
    @State private var userImage: UIImage?
    @State private var showCamera = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var photoURL: URL?
    @State private var isImageVisible = false  // ✅ для анимации

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: location.lat, longitude: location.lon)
    }

    // ✅ Новая инициализация с уже сохранённым фото
    init(location: HuntLocation,
         initialImage: UIImage? = nil,
         onSavePhoto: @escaping (HuntLocation, UIImage) -> Void) {
        self.location = location
        self._userImage = State(initialValue: initialImage)
        self.onSavePhoto = onSavePhoto
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                FlipCard {
                    // FRONT
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

                        Map(initialPosition: .region(
                            MKCoordinateRegion(
                                center: coordinate,
                                latitudinalMeters: 8000,
                                longitudinalMeters: 8000
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
                    }
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: 6)

                } back: {
                    // BACK
                    VStack {
                        if let img = userImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 300)
                                .cornerRadius(12)
                                .shadow(radius: 6)
                                .opacity(isImageVisible ? 1 : 0)
                                .scaleEffect(isImageVisible ? 1 : 0.95)
                                .animation(.easeInOut(duration: 0.5), value: isImageVisible)
                                .onAppear { isImageVisible = true }
                        } else if let url = photoURL {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView("Loading...")
                                case .success(let image):
                                    image.resizable()
                                        .scaledToFit()
                                        .cornerRadius(12)
                                        .shadow(radius: 4)
                                case .failure:
                                    Label("Image not available", systemImage: "xmark.circle")
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                            Label("No photo yet", systemImage: "photo")
                                .foregroundColor(.secondary)
                                .padding(.top, 40)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: 350)
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                // 📸 Кнопки
                HStack(spacing: 20) {
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
            .padding()
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker { image in
                if let img = image {
                    userImage = img
                    onSavePhoto(location, img) // ✅ сохраняем в ContentView
                }
            }
        }
        .onChange(of: selectedItem) { _, newVal in
            Task {
                if let data = try? await newVal?.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    userImage = img
                    onSavePhoto(location, img) // ✅ сохраняем в ContentView
                }
            }
        }
        .onAppear {
            if userImage == nil && photoURL == nil {
                Task {
                    if let urlString = try? await PhotoAPI.shared.fetchPhoto(for: location.name),
                       let url = URL(string: urlString) {
                        photoURL = url
                    }
                }
            }
        }
    }

    // ✅ Исправленный Apple Maps переход
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
    LocationDetailView(
        location: HuntLocation(
            name: "Starlight Cinema",
            address: "123 Main Street, Mississauga, Ontario, Canada L5B 4C4",
            lat: 43.589,
            lon: -79.644
        ),
        initialImage: UIImage(systemName: "photo.fill")!,
        onSavePhoto: { _, _ in }
    )
}
