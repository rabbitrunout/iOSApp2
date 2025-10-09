//
//  ContentView.swift
//  CityChamberHunt
//

import SwiftUI
import PDFKit
import UIKit

struct ContentView: View {
    @State private var query: String = ""
    @State private var locations: [HuntLocation] = []
    @State private var userImages: [String: UIImage] = [:]
    @State private var photoInfos: [String: HuntPhotoInfo] = [:]

    private let fileManager = FileManager.default
    private var infoURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HuntPhotoInfo.json")
    }

    // MARK: - UI
    var body: some View {
        NavigationStack {
            VStack {
                // 🔍 Поиск
                HStack {
                    TextField("Search local businesses...", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)

                    Button("Go") {
                        LocationAPI.search(query: query) { results in
                            self.locations = results
                            self.loadSavedImages()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top)

                // 📍 Список локаций
                List(locations, id: \.id) { loc in
                    NavigationLink(destination:
                        LocationDetailView(
                            location: loc,
                            userImage: Binding(
                                get: { userImages[loc.id] },
                                set: { newImage in
                                    if let img = newImage {
                                        saveImage(img, for: loc)
                                    }
                                }
                            ),
                            onSavePhoto: { location, image in
                                saveImage(image, for: location)
                            }
                        )
                    ) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(loc.name).font(.headline)
                                Text(loc.address)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if let img = userImages[loc.id] {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 45, height: 45)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.purple, lineWidth: 1))
                            }
                        }
                    }
                }
            }
            .navigationTitle("City Hunt")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export PDF") {
                        generatePDFReport()
                    }
                }
            }
            .task {
                loadSavedImages()
            }
        }
    }

    // MARK: - 💾 Сохранение фото
    private func saveImage(_ image: UIImage, for location: HuntLocation) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }

        let filename = "\(location.id).jpg"
        let fileURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)

        do {
            try data.write(to: fileURL)
            userImages[location.id] = image
            photoInfos[location.id] = HuntPhotoInfo(filename: filename, date: Date())
            saveInfoToDisk()
            print("💾 Saved image for \(location.name)")
        } catch {
            print("❌ Error saving image: \(error)")
        }
    }

    private func saveInfoToDisk() {
        do {
            let data = try JSONEncoder().encode(photoInfos)
            try data.write(to: infoURL)
        } catch {
            print("❌ Error saving JSON: \(error)")
        }
    }

    // MARK: - 📥 Загрузка фото
    private func loadSavedImages() {
        print("📥 Loading saved images...")
        guard let data = try? Data(contentsOf: infoURL),
              let savedInfos = try? JSONDecoder().decode([String: HuntPhotoInfo].self, from: data)
        else {
            print("⚠️ No saved photo info found.")
            return
        }

        photoInfos = savedInfos
        for (id, info) in savedInfos {
            let fileURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(info.filename)
            if let imgData = try? Data(contentsOf: fileURL),
               let image = UIImage(data: imgData) {
                userImages[id] = image
            }
        }
        print("✅ Loaded \(userImages.count) saved images.")
    }

    // MARK: - 🧾 Генерация PDF отчёта
    private func generatePDFReport() {
        guard !locations.isEmpty else { return }

        let format = UIGraphicsPDFRendererFormat()
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            context.beginPage()
            "City Chamber Hunt Report"
                .draw(in: CGRect(x: 40, y: 150, width: 532, height: 40),
                      withAttributes: [.font: UIFont.boldSystemFont(ofSize: 26)])

            for loc in locations {
                context.beginPage()

                loc.name.draw(in: CGRect(x: 20, y: 20, width: 572, height: 30),
                              withAttributes: [.font: UIFont.boldSystemFont(ofSize: 20)])
                loc.address.draw(in: CGRect(x: 20, y: 60, width: 572, height: 40),
                                 withAttributes: [.font: UIFont.systemFont(ofSize: 14)])

                if let img = userImages[loc.id] {
                    let maxW: CGFloat = 572
                    let maxH: CGFloat = 400
                    let ratio = img.size.width / img.size.height
                    var w = maxW
                    var h = w / ratio
                    if h > maxH {
                        h = maxH
                        w = h * ratio
                    }
                    let rect = CGRect(x: (612 - w)/2, y: 120, width: w, height: h)
                    img.draw(in: rect)
                }
            }
        }

        let pdfURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CityHunt_Report.pdf")

        do {
            try data.write(to: pdfURL)
            let vc = UIActivityViewController(activityItems: [pdfURL], applicationActivities: nil)
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = scene.windows.first?.rootViewController {
                rootVC.present(vc, animated: true)
            }
        } catch {
            print("❌ PDF error: \(error)")
        }
    }
}

#Preview {
    ContentView()
}
