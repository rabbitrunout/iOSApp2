//
//  ContentView.swift
//  CityChamberHunt
//
//  Created by Irina Safronova on 2025-10-15.
//

import SwiftUI
import MapKit
import PDFKit

struct ContentView: View {
    @State private var huntLocations: [HuntLocation] = []
    @State private var savedImages: [String: UIImage] = [:] // ключ = адрес
    @State private var imageFilenames: [String: String] = [:]
    @State private var photoInfo: [String: HuntPhotoInfo] = [:]
    @State private var searchQuery = ""
    @State private var isGeneratingPDF = false
    @State private var progressText = ""

    private let fileManager = FileManager.default
    private let filenamesKey = "SavedLocationImages"
    private let photoInfoKey = "SavedPhotoInfo"

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                // 🔍 Поиск
                HStack {
                    TextField("Search location...", text: $searchQuery)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)

                    Button("Find") {
                        LocationAPI.search(query: searchQuery) { result in
                            huntLocations = result
                            loadSavedImages() // подгрузим фото к найденным
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.trailing)
                }

                // 📋 Список локаций
                List(huntLocations) { location in
                    NavigationLink(
                        destination: LocationDetailView(
                            location: location,
                            userImage: Binding(
                                get: { savedImages[location.address] },
                                set: { newImage in
                                    savedImages[location.address] = newImage
                                }
                            ),
                            onSavePhoto: { loc, img, source in
                                savedImages[loc.address] = img
                                saveImage(img, for: loc, source: source)
                            }
                        )
                    ) {
                        HStack {
                            if let thumb = savedImages[location.address] {
                                Image(uiImage: thumb)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 50, height: 50)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .shadow(radius: 2)
                            } else {
                                Image(systemName: "photo")
                                    .frame(width: 50, height: 50)
                                    .foregroundColor(.gray)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(location.name).font(.headline)
                                Text(location.address)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // 🧾 PDF экспорт
                VStack(spacing: 6) {
                    if isGeneratingPDF {
                        ProgressView(progressText)
                            .progressViewStyle(.linear)
                            .padding(.horizontal)
                    }

                    Button {
                        Task {
                            isGeneratingPDF = true
                            progressText = "Preparing data..."
                            try? await Task.sleep(nanoseconds: 400_000_000)

                            print("🧩 Locations: \(huntLocations.count)")
                            print("🧩 Images: \(savedImages.count)")
                            print("🧩 PhotoInfo: \(photoInfo.count)")

                            let snapshots = await preloadMaps(for: huntLocations)
                            progressText = "Generating PDF..."
                            await generatePDFReport(for: huntLocations,
                                                    images: savedImages,
                                                    snapshots: snapshots,
                                                    photoInfo: photoInfo)
                            isGeneratingPDF = false
                            progressText = ""
                        }
                    } label: {
                        HStack {
                            if isGeneratingPDF { ProgressView() }
                            Label("Export PDF Report", systemImage: "doc.richtext.fill")
                        }
                    }
                    .padding()
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("CityChamberHunt")
        }
        .onAppear {
            loadSavedImages()
            loadPhotoInfo()
        }
    }

    // MARK: - 📸 Сохранение фото по адресу
    func saveImage(_ image: UIImage, for location: HuntLocation, source: String) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }

        let safeName = location.address.replacingOccurrences(of: "/", with: "_")
        let filename = "\(safeName).jpg"
        let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)

        do {
            try data.write(to: url)
            imageFilenames[location.address] = filename
            saveFilenamesToDefaults()

            let info = HuntPhotoInfo(
                filename: filename,
                dateAdded: Date(),
                source: source + " (from location)",
                address: location.address,
                latitude: location.lat,
                longitude: location.lon
            )
            photoInfo[location.address] = info
            savePhotoInfo()
            UserDefaults.standard.synchronize()

            print("✅ Saved image for \(location.name) → \(filename)")
        } catch {
            print("❌ Failed to save image:", error)
        }
    }

    // MARK: - 💾 Save / Load info
    func savePhotoInfo() {
        if let data = try? JSONEncoder().encode(photoInfo) {
            UserDefaults.standard.set(data, forKey: photoInfoKey)
            UserDefaults.standard.synchronize()
            print("💾 Photo info saved: \(photoInfo.count)")
        }
    }

    func loadPhotoInfo() {
        guard let data = UserDefaults.standard.data(forKey: photoInfoKey),
              let saved = try? JSONDecoder().decode([String: HuntPhotoInfo].self, from: data)
        else { return }
        photoInfo = saved
        print("📖 Restored \(photoInfo.count) photo infos")
    }

    // MARK: - 💾 Загрузка фото с диска
    func loadSavedImages() {
        guard let data = UserDefaults.standard.data(forKey: filenamesKey),
              let savedMap = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            print("⚠️ No saved filenames found in UserDefaults")
            return
        }

        imageFilenames = savedMap
        var loadedImages: [String: UIImage] = [:]
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]

        for (address, filename) in savedMap {
            let url = docs.appendingPathComponent(filename)
            if let imgData = try? Data(contentsOf: url),
               let img = UIImage(data: imgData) {
                loadedImages[address] = img
                print("✅ Loaded:", filename)
            } else {
                print("⚠️ Missing:", filename)
            }
        }

        savedImages = loadedImages
        print("📂 Restored \(savedImages.count) images total")
    }

    func saveFilenamesToDefaults() {
        if let data = try? JSONEncoder().encode(imageFilenames) {
            UserDefaults.standard.set(data, forKey: filenamesKey)
            UserDefaults.standard.synchronize()
            print("💾 Filenames saved: \(imageFilenames.count)")
        }
    }

    // MARK: - 🗺 Карты
    func preloadMaps(for locations: [HuntLocation]) async -> [String: UIImage] {
        var result: [String: UIImage] = [:]
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]

        for loc in locations {
            let mapFilename = "\(loc.address.replacingOccurrences(of: "/", with: "_"))_map.jpg"
            let mapURL = docs.appendingPathComponent(mapFilename)

            if let data = try? Data(contentsOf: mapURL),
               let cached = UIImage(data: data) {
                result[loc.address] = cached
                continue
            }

            let coord = CLLocationCoordinate2D(latitude: loc.lat, longitude: loc.lon)
            let opts = MKMapSnapshotter.Options()
            opts.region = MKCoordinateRegion(center: coord,
                                             latitudinalMeters: 4000,
                                             longitudinalMeters: 4000)
            opts.size = CGSize(width: 300, height: 200)
            opts.scale = UIScreen.main.scale

            do {
                let snapshot = try await MKMapSnapshotter(options: opts).start()
                UIGraphicsBeginImageContextWithOptions(opts.size, true, 0)
                snapshot.image.draw(at: .zero)
                let pin = UIImage(systemName: "mappin.circle.fill")!
                let point = snapshot.point(for: coord)
                pin.draw(at: CGPoint(x: point.x - 12, y: point.y - 24))
                let final = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()

                if let img = final {
                    result[loc.address] = img
                    if let data = img.jpegData(compressionQuality: 0.9) {
                        try? data.write(to: mapURL)
                    }
                }
            } catch {
                print("⚠️ Map failed for \(loc.name)")
            }
        }
        return result
    }

    // MARK: - 📄 PDF
    func generatePDFReport(for locations: [HuntLocation],
                           images: [String: UIImage],
                           snapshots: [String: UIImage],
                           photoInfo: [String: HuntPhotoInfo]) async {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let format = UIGraphicsPDFRendererFormat()

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        let data = renderer.pdfData { ctx in

            // Обложка
            ctx.beginPage()
            let title = "🏙️ CityChamberHunt Report"
            title.draw(in: CGRect(x: 0, y: 240, width: pageWidth, height: 60),
                       withAttributes: [.font: UIFont.boldSystemFont(ofSize: 28),
                                        .paragraphStyle: centered(),
                                        .foregroundColor: UIColor.systemPurple])
            "Generated on \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))"
                .draw(in: CGRect(x: 0, y: 310, width: pageWidth, height: 30),
                      withAttributes: [.font: UIFont.systemFont(ofSize: 14),
                                       .paragraphStyle: centered(),
                                       .foregroundColor: UIColor.gray])

            // Страницы локаций
            for loc in locations {
                guard let img = images[loc.address] else { continue }
                ctx.beginPage()

                PDFRenderer.drawHeader(title: loc.name, address: loc.address, on: ctx, in: pageRect)
                PDFRenderer.drawImage(img, in: pageRect)

                if let info = photoInfo[loc.address] {
                    PDFRenderer.drawMeta(info, on: ctx, in: pageRect)
                }

                if let map = snapshots[loc.address] {
                    let mapRect = CGRect(x: (pageWidth - 260) / 2, y: 480, width: 260, height: 160)
                    map.draw(in: mapRect)
                }
            }
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("CityHunt_Report.pdf")
        do {
            try data.write(to: tempURL)
            let vc = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let root = scene.windows.first?.rootViewController {
                root.present(vc, animated: true)
            }
        } catch {
            print("❌ PDF save error:", error)
        }
    }

    private func centered() -> NSMutableParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.alignment = .center
        return p
    }
}

#Preview { ContentView() }
