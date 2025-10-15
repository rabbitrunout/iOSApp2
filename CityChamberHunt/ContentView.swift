//
//  ContentView.swift
//  CityChamberHunt
//
//  Created by Irina Safronova
//

import SwiftUI
import MapKit
import PDFKit

struct ContentView: View {
    @State private var huntLocations: [HuntLocation] = []
    @State private var savedImages: [UUID: UIImage] = [:]
    @State private var imageFilenames: [UUID: String] = [:]
    @State private var searchQuery = ""
    @State private var isGeneratingPDF = false
    @State private var progressText = ""

    private let fileManager = FileManager.default
    private let filenamesKey = "SavedLocationImages"

    var body: some View {
        NavigationView {
            VStack {
                // 🔍 Поиск локаций
                HStack {
                    TextField("Search location...", text: $searchQuery)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)

                    Button("Find") {
                        LocationAPI.search(query: searchQuery) { result in
                            huntLocations = result
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.trailing)
                }
                .padding(.top)

                // 📍 Список найденных локаций
                List(huntLocations) { location in
                    NavigationLink(
                        destination: LocationDetailView(
                            location: location,
                            userImage: Binding(
                                get: { savedImages[location.id] },
                                set: { newImage in
                                    savedImages[location.id] = newImage
                                    if let img = newImage {
                                        saveImage(img, for: location)
                                    }
                                }
                            ),
                            onSavePhoto: { loc, img in
                                savedImages[loc.id] = img
                                saveImage(img, for: loc)
                            }
                        )
                    ) {
                        HStack {
                            if let thumb = savedImages[location.id] {
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

                            VStack(alignment: .leading) {
                                Text(location.name)
                                    .font(.headline)
                                Text(location.address)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // 🧾 Кнопка экспорта PDF
                VStack(spacing: 6) {
                    if isGeneratingPDF {
                        ProgressView(progressText)
                            .progressViewStyle(.linear)
                            .padding(.horizontal)
                    }

                    Button {
                        Task {
                            isGeneratingPDF = true
                            progressText = "Preparing maps..."
                            let snapshots = await preloadMaps(for: huntLocations)
                            progressText = "Generating PDF..."
                            await generatePDFReport(for: huntLocations,
                                                    images: savedImages,
                                                    snapshots: snapshots)
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
        }
    }

    // MARK: - 📸 Сохранение изображений
    func saveImage(_ image: UIImage, for location: HuntLocation) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        let filename = "\(location.id.uuidString).jpg"
        let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)

        do {
            try data.write(to: url)
            imageFilenames[location.id] = filename
            saveFilenamesToDefaults()
            print("✅ Saved image for \(location.name)")
        } catch {
            print("❌ Failed to save image:", error)
        }
    }

    // MARK: - 💾 Загрузка сохранённых изображений
    func loadSavedImages() {
        guard let data = UserDefaults.standard.data(forKey: filenamesKey),
              let savedMap = try? JSONDecoder().decode([UUID: String].self, from: data)
        else { return }

        imageFilenames = savedMap
        var loadedImages: [UUID: UIImage] = [:]

        for (id, filename) in savedMap {
            let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(filename)
            if let imgData = try? Data(contentsOf: url),
               let img = UIImage(data: imgData) {
                loadedImages[id] = img
            }
        }

        savedImages = loadedImages
        print("📂 Restored \(savedImages.count) images from disk")
    }

    // MARK: - 🧠 Сохранение имён файлов
    func saveFilenamesToDefaults() {
        if let data = try? JSONEncoder().encode(imageFilenames) {
            UserDefaults.standard.set(data, forKey: filenamesKey)
        }
    }

    // MARK: - 🗺 Предзагрузка всех карт с кешированием
    func preloadMaps(for locations: [HuntLocation]) async -> [UUID: UIImage] {
        var result: [UUID: UIImage] = [:]
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fallbackCoordinate = CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832)

        for (index, loc) in locations.enumerated() {
            let mapFilename = "\(loc.id.uuidString)_map.jpg"
            let mapURL = documents.appendingPathComponent(mapFilename)

            progressText = "Loading map \(index + 1) of \(locations.count)..."

            // Проверяем кеш
            if let data = try? Data(contentsOf: mapURL),
               let cached = UIImage(data: data) {
                result[loc.id] = cached
                print("🗺 Loaded cached map for \(loc.name)")
                continue
            }

            // Создание карты
            var coord = CLLocationCoordinate2D(latitude: loc.lat, longitude: loc.lon)
            if coord.latitude == 0 || coord.longitude == 0 {
                coord = fallbackCoordinate
            }

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
                    result[loc.id] = img
                    if let data = img.jpegData(compressionQuality: 0.9) {
                        try? data.write(to: mapURL)
                    }
                    print("✅ Map preloaded for \(loc.name)")
                }
            } catch {
                print("⚠️ Snapshot failed for \(loc.name): \(error.localizedDescription)")
            }

            // Пауза для симулятора
            try? await Task.sleep(nanoseconds: 400_000_000)
        }

        return result
    }

    // MARK: - 📄 Генерация PDF
    func generatePDFReport(for locations: [HuntLocation],
                           images: [UUID: UIImage],
                           snapshots: [UUID: UIImage]) async {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextCreator as String: "CityChamberHunt",
            kCGPDFContextAuthor as String: "Irina Safronova"
        ]

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        let data = renderer.pdfData { ctx in
            for loc in locations {
                guard let img = images[loc.id] else { continue }
                ctx.beginPage()

                // Заголовок и адрес
                let title = "📍 \(loc.name)"
                title.draw(in: CGRect(x: 20, y: 20, width: pageWidth - 40, height: 25),
                           withAttributes: [.font: UIFont.boldSystemFont(ofSize: 18)])
                loc.address.draw(in: CGRect(x: 20, y: 50, width: pageWidth - 40, height: 40),
                                 withAttributes: [.font: UIFont.systemFont(ofSize: 14)])

                // Фото
                let maxWidth = pageWidth - 40
                let aspect = img.size.width / img.size.height
                let imgRect = CGRect(x: 20, y: 100, width: maxWidth, height: maxWidth / aspect)
                img.draw(in: imgRect)

                // Карта
                if let map = snapshots[loc.id] {
                    let mapRect = CGRect(x: (pageWidth - 300) / 2,
                                         y: imgRect.maxY + 20,
                                         width: 300,
                                         height: 200)
                    map.draw(in: mapRect)
                    let footer = "Map data © OpenStreetMap / Apple MapKit"
                    footer.draw(in: CGRect(x: 20, y: mapRect.maxY + 10,
                                           width: pageWidth - 40, height: 20),
                                withAttributes: [.font: UIFont.systemFont(ofSize: 10),
                                                 .foregroundColor: UIColor.gray])
                } else {
                    let placeholder = "🗺 Map unavailable"
                    placeholder.draw(in: CGRect(x: 20,
                                                y: imgRect.maxY + 20,
                                                width: pageWidth - 40,
                                                height: 30),
                                     withAttributes: [.font: UIFont.italicSystemFont(ofSize: 14)])
                }
            }
        }

        // Экспорт PDF
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
}

#Preview {
    ContentView()
}
