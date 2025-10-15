//
//  LocationDetailView.swift
//  CityChamberHunt
//
//  Created by Irina Safronova on 2025-10-15.
//

import SwiftUI
import MapKit
import PhotosUI

struct LocationDetailView: View {
    let location: HuntLocation
    @Binding var userImage: UIImage?
    var onSavePhoto: ((HuntLocation, UIImage, String) -> Void)? = nil

    @State private var showCamera = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var photoURL: URL?

    @State private var photoInfo: HuntPhotoInfo?  // ✅ информация о фото

    private let fileManager = FileManager.default

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: location.lat, longitude: location.lon)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 🌆 Front side — map and location info
                FlipCard {
                    VStack(spacing: 12) {
                        Text(location.name)
                            .font(.title2)
                            .bold()
                        Text(location.address)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Map(initialPosition: .region(
                            MKCoordinateRegion(center: coordinate,
                                               latitudinalMeters: 6000,
                                               longitudinalMeters: 6000)
                        )) {
                            Marker(location.name, coordinate: coordinate)
                        }
                        .frame(height: 250)
                        .cornerRadius(16)
                        .shadow(radius: 6)
                    }
                } back: {
                    VStack(spacing: 10) {
                        if let img = userImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 280)
                                .cornerRadius(12)
                                .shadow(radius: 4)

                            // 📅 Информация о фото
                            if let info = photoInfo {
                                VStack(alignment: .leading, spacing: 6) {
                                    Divider().padding(.vertical, 6)
                                    Label {
                                        Text(formattedDate(info.dateAdded))
                                    } icon: {
                                        Image(systemName: "calendar")
                                            .foregroundColor(.purple)
                                    }
                                    Label {
                                        Text(info.source)
                                    } icon: {
                                        Image(systemName: "camera.fill")
                                            .foregroundColor(.blue)
                                    }
                                    if let addr = info.address {
                                        Label {
                                            Text(addr)
                                        } icon: {
                                            Image(systemName: "mappin.and.ellipse")
                                                .foregroundColor(.red)
                                        }
                                    }
                                    if let lat = info.latitude, let lon = info.longitude {
                                        Label {
                                            Text(String(format: "Lat: %.4f, Lon: %.4f", lat, lon))
                                        } icon: {
                                            Image(systemName: "globe.americas.fill")
                                                .foregroundColor(.teal)
                                        }
                                    }
                                }
                                .font(.footnote)
                                .padding(.horizontal)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        } else if let url = photoURL {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                case .success(let image):
                                    image.resizable().scaledToFit().cornerRadius(12)
                                case .failure:
                                    Text("Failed to load image")
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                            VStack {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                Text("No photo yet")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 30)
                        }
                    }
                }
                .id(location.id)

                // 🎛 Кнопки для фото
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
                .padding(.bottom, 10)
            }
            .padding()
        }
        // 📸 Камера
        .sheet(isPresented: $showCamera) {
            CameraPicker { image in
                if let img = image {
                    saveAndNotify(img, source: "Camera")
                }
            }
        }
        // 🖼️ Фото из библиотеки
        .onChange(of: selectedItem) { _, newVal in
            Task {
                if let data = try? await newVal?.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    saveAndNotify(img, source: "Library")
                }
            }
        }
        // 🌐 Фото из Unsplash, если нет локального
        .onAppear {
            loadExistingPhotoInfo()
            if userImage == nil {
                if let saved = loadFromDisk() {
                    userImage = saved
                } else {
                    Task {
                        if let urlString = try? await PhotoAPI.shared.fetchPhoto(for: location.name),
                           let url = URL(string: urlString) {
                            photoURL = url
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

    private func formattedDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: date)
    }

    private func saveAndNotify(_ image: UIImage, source: String) {
        userImage = image
        saveToDisk(image)
        let info = HuntPhotoInfo(
            filename: "\(location.id.uuidString).jpg",
            dateAdded: Date(),
            source: source + " (from location)",
            address: location.address,
            latitude: location.lat,
            longitude: location.lon
        )

        photoInfo = info
        savePhotoInfo(info, for: location)
        onSavePhoto?(location, image, source)
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

    // MARK: - Хранение/чтение информации о фото
    private func savePhotoInfo(_ info: HuntPhotoInfo, for location: HuntLocation) {
        let key = "PhotoInfo_\(location.id.uuidString)"
        if let encoded = try? JSONEncoder().encode(info) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }

    private func loadExistingPhotoInfo() {
        let key = "PhotoInfo_\(location.id.uuidString)"
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode(HuntPhotoInfo.self, from: data) {
            photoInfo = saved
        }
    }
}
