// LocationDetailView.swift
import SwiftUI
import MapKit
import PhotosUI

struct LocationDetailView: View {
    let location: HuntLocation
    @State private var flipped = false
    @State private var userImage: UIImage?
    @State private var showCamera = false
    @State private var selectedItem: PhotosPickerItem?
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: location.lat, longitude: location.lon)
    }
    
    var body: some View {
        VStack {
            ZStack {
                // Front — название, адрес, карта
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
                    
                    Map {
                        Marker(location.name, coordinate: coordinate)
                    }
                    .frame(height: 180)
                    .cornerRadius(12)
                    
                    Spacer()
                    Text("Tap to flip ↻")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: 350)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .opacity(flipped ? 0 : 1)
                
                // Back — фото пользователя или заглушка
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
                .opacity(flipped ? 1 : 0)
            }
            .onTapGesture { flipped.toggle() }
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
}


#Preview {
    LocationDetailView(location: HuntLocation(
        name: "Starlight Cinema",
        address: "123 Main Street, Mississauga",
        lat: 43.589,
        lon: -79.644
    ))
}
