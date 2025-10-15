//
//  LocationDetailView.swift
//  CityChamberHunt
//

import SwiftUI
import MapKit
import PhotosUI

struct LocationDetailView: View {
    let location: HuntLocation
    @Binding var userImage: UIImage?
    var onSavePhoto: ((HuntLocation, UIImage, String) -> Void)? = nil // ✅ добавили source

    @State private var showCamera = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var photoURL: URL?

    private let fileManager = FileManager.default

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: location.lat, longitude: location.lon)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // ✅ FlipCard
                FlipCard {
                    VStack(spacing: 12) {
                        Text(location.name)
                            .font(.title)
                            .bold()
                        Text(location.address)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Map(initialPosition: .region(
                            MKCoordinateRegion(center: coordinate,
                                               latitudinalMeters: 8000,
                                               longitudinalMeters: 8000)
                        )) {
                            Marker(location.name, coordinate: coordinate)
                        }
                        .frame(height: 300)
                        .cornerRadius(16)
                        .shadow(radius: 6)
                    }
                } back: {
                    if let img = userImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .cornerRadius(12)
                    } else if let url = photoURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty: ProgressView()
                            case .success(let image): image.resizable().scaledToFit()
                            case .failure: Text("Failed to load image")
                            @unknown default: EmptyView()
                            }
                        }
                    } else {
                        Text("No photo yet").foregroundColor(.secondary)
                    }
                }
                .id(location.id)

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
            .padding()
        }
        // 📸 Камера
        .sheet(isPresented: $showCamera) {
            CameraPicker { image in
                if let img = image {
                    saveAndNotify(img, source: "Camera") // ✅ указываем источник
                }
            }
        }
        // 🖼️ Фото из библиотеки
        .onChange(of: selectedItem) { _, newVal in
            Task {
                if let data = try? await newVal?.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    saveAndNotify(img, source: "Library") // ✅ указываем источник
                }
            }
        }
        // 🌐 Фото из Unsplash
        .onAppear {
            if userImage == nil {
                if let saved = loadFromDisk() {
                    userImage = saved
                } else {
                    Task {
                        if let urlString = try? await PhotoAPI.shared.fetchPhoto(for: location.name),
                           let url = URL(string: urlString) {
                            photoURL = url
                            // Загружаем превью и сохраняем как Unsplash
                            if let data = try? Data(contentsOf: url),
                               let img = UIImage(data: data) {
                                saveAndNotify(img, source: "Unsplash")
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers
    private func saveAndNotify(_ image: UIImage, source: String) {
        userImage = image
        saveToDisk(image)
        onSavePhoto?(location, image, source) // ✅ передаём источник в ContentView
    }

    private func saveToDisk(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        let filename = "\(location.id.uuidString).jpg"
        let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        try? data.write(to: url)
    }

    private func loadFromDisk() -> UIImage? {
        let filename = "\(location.id.uuidString).jpg"
        let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url),
              let img = UIImage(data: data) else { return nil }
        return img
    }
}
