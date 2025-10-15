import SwiftUI
import MapKit
import PDFKit

struct ContentView: View {
    @State private var huntLocations: [HuntLocation] = []
    @State private var savedImages: [UUID: UIImage] = [:]
    @State private var imageFilenames: [UUID: String] = [:]
    @State private var photoInfo: [UUID: HuntPhotoInfo] = [:] // ✅ информация о фото
    @State private var searchQuery = ""
    @State private var isGeneratingPDF = false
    @State private var progressText = ""

    private let fileManager = FileManager.default
    private let filenamesKey = "SavedLocationImages"
    private let photoInfoKey = "SavedPhotoInfo"

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
                                }
                            ),
                            onSavePhoto: { loc, img, source in
                                savedImages[loc.id] = img
                                saveImage(img, for: loc, source: source) // ✅ передаём реальный источник
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
            loadPhotoInfo() // ✅ подгружаем данные о фото
        }
    }

    // MARK: - 📸 Сохранение изображений
    func saveImage(_ image: UIImage, for location: HuntLocation, source: String) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        let filename = "\(location.id.uuidString).jpg"
        let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)

        do {
            try data.write(to: url)
            imageFilenames[location.id] = filename
            saveFilenamesToDefaults()

            // ✅ сохраняем инфо о фото
            let info = HuntPhotoInfo(filename: filename, dateAdded: Date(), source: source)
            photoInfo[location.id] = info
            savePhotoInfo()

            print("✅ Saved image from \(source) for \(location.name)")
        } catch {
            print("❌ Failed to save image:", error)
        }
    }

    // MARK: - 💾 Сохранение / загрузка информации о фото
    func savePhotoInfo() {
        if let data = try? JSONEncoder().encode(photoInfo) {
            UserDefaults.standard.set(data, forKey: photoInfoKey)
        }
    }

    func loadPhotoInfo() {
        guard let data = UserDefaults.standard.data(forKey: photoInfoKey),
              let saved = try? JSONDecoder().decode([UUID: HuntPhotoInfo].self, from: data) else { return }
        photoInfo = saved
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

            if let data = try? Data(contentsOf: mapURL),
               let cached = UIImage(data: data) {
                result[loc.id] = cached
                print("🗺 Loaded cached map for \(loc.name)")
                continue
            }

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

            try? await Task.sleep(nanoseconds: 400_000_000)
        }

        return result
    }

    // MARK: - 📄 Генерация PDF отчёта с метаданными и обложкой
    func generatePDFReport(for locations: [HuntLocation],
                           images: [UUID: UIImage],
                           snapshots: [UUID: UIImage],
                           photoInfo: [UUID: HuntPhotoInfo]) async {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextCreator as String: "CityChamberHunt",
            kCGPDFContextAuthor as String: "Irina Safronova"
        ]

        // 🗺 Загружаем кэшированные карты, если их нет в памяти
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        var fullSnapshots = snapshots
        for loc in locations where fullSnapshots[loc.id] == nil {
            let mapFilename = "\(loc.id.uuidString)_map.jpg"
            let mapURL = documents.appendingPathComponent(mapFilename)
            if let data = try? Data(contentsOf: mapURL),
               let img = UIImage(data: data) {
                fullSnapshots[loc.id] = img
            }
        }

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        let data = renderer.pdfData { ctx in

            // 🔹 1. Обложка
            ctx.beginPage()
            let title = "🏙️ CityChamberHunt Report"
            title.draw(in: CGRect(x: 0, y: 200, width: pageWidth, height: 60),
                       withAttributes: [
                        .font: UIFont.boldSystemFont(ofSize: 32),
                        .paragraphStyle: {
                            let s = NSMutableParagraphStyle(); s.alignment = .center; return s
                        }(),
                        .foregroundColor: UIColor.systemPurple
                       ])

            let subtitle = "Collected by: Irina Safronova"
            subtitle.draw(in: CGRect(x: 0, y: 270, width: pageWidth, height: 40),
                          withAttributes: [
                            .font: UIFont.systemFont(ofSize: 18),
                            .paragraphStyle: {
                                let s = NSMutableParagraphStyle(); s.alignment = .center; return s
                            }(),
                            .foregroundColor: UIColor.darkGray
                          ])

            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            let dateText = "Generated on: \(dateFormatter.string(from: Date()))"
            dateText.draw(in: CGRect(x: 0, y: 310, width: pageWidth, height: 30),
                          withAttributes: [
                            .font: UIFont.systemFont(ofSize: 14),
                            .paragraphStyle: {
                                let s = NSMutableParagraphStyle(); s.alignment = .center; return s
                            }(),
                            .foregroundColor: UIColor.gray
                          ])

            let line = UIBezierPath()
            line.move(to: CGPoint(x: 100, y: 360))
            line.addLine(to: CGPoint(x: pageWidth - 100, y: 360))
            UIColor.systemPurple.setStroke()
            line.lineWidth = 2
            line.stroke()

            "Explore · Capture · Discover".draw(in: CGRect(x: 0, y: 400, width: pageWidth, height: 40),
                                                withAttributes: [
                                                    .font: UIFont.italicSystemFont(ofSize: 16),
                                                    .paragraphStyle: {
                                                        let s = NSMutableParagraphStyle()
                                                        s.alignment = .center
                                                        return s
                                                    }(),
                                                    .foregroundColor: UIColor.systemBlue
                                                ])

            // 🔹 2. Страницы с локациями
            for loc in locations {
                guard images[loc.id] != nil || fullSnapshots[loc.id] != nil else { continue }
                ctx.beginPage()

                // Заголовок
                let title = "📍 \(loc.name)"
                title.draw(in: CGRect(x: 20, y: 20, width: pageWidth - 40, height: 25),
                           withAttributes: [.font: UIFont.boldSystemFont(ofSize: 18)])
                loc.address.draw(in: CGRect(x: 20, y: 50, width: pageWidth - 40, height: 40),
                                 withAttributes: [.font: UIFont.systemFont(ofSize: 14)])

                // 📅 Метаданные фото
                if let info = photoInfo[loc.id] {
                    let df = DateFormatter()
                    df.dateStyle = .medium; df.timeStyle = .short
                    let dateText = df.string(from: info.dateAdded)
                    let details = "📅 Added: \(dateText)\n📸 Source: \(info.source)"
                    details.draw(in: CGRect(x: 20, y: 90, width: pageWidth - 40, height: 40),
                                 withAttributes: [
                                    .font: UIFont.systemFont(ofSize: 12),
                                    .foregroundColor: UIColor.gray
                                 ])
                }

                // Фото
                let yStart: CGFloat = 140
                let imgMaxWidth = pageWidth - 60
                let imgHeight: CGFloat = 220
                if let img = images[loc.id] {
                    let aspect = img.size.width / img.size.height
                    let width = min(imgMaxWidth, imgHeight * aspect)
                    let xOffset = (pageWidth - width) / 2
                    let imgRect = CGRect(x: xOffset, y: yStart, width: width, height: imgHeight)
                    img.draw(in: imgRect)
                } else {
                    "📸 No photo available".draw(in: CGRect(x: 20, y: yStart, width: pageWidth - 40, height: 30),
                                                withAttributes: [.font: UIFont.italicSystemFont(ofSize: 14)])
                }

                // Карта
                let mapY: CGFloat = yStart + imgHeight + 35
                let mapWidth: CGFloat = 260
                let mapHeight: CGFloat = 160
                if let map = fullSnapshots[loc.id] {
                    let mapRect = CGRect(x: (pageWidth - mapWidth) / 2,
                                         y: mapY,
                                         width: mapWidth,
                                         height: mapHeight)
                    map.draw(in: mapRect)

                    let footer = "Map data © OpenStreetMap / Apple MapKit"
                    footer.draw(in: CGRect(x: 0, y: mapRect.maxY + 10, width: pageWidth, height: 20),
                                withAttributes: [
                                    .font: UIFont.systemFont(ofSize: 10),
                                    .paragraphStyle: {
                                        let s = NSMutableParagraphStyle()
                                        s.alignment = .center
                                        return s
                                    }(),
                                    .foregroundColor: UIColor.gray
                                ])
                } else {
                    "🗺 Map unavailable".draw(in: CGRect(x: 20, y: mapY, width: pageWidth - 40, height: 30),
                                             withAttributes: [.font: UIFont.italicSystemFont(ofSize: 14)])
                }
            }
        }

        // 📤 Экспорт PDF
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
