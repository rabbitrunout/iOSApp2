//
//  ContentView.swift
//  CityChamberHunt
//
//  Created by Irina Saf on 2025-10-08.
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

    var body: some View {
        NavigationStack {
            VStack {
                // 🔍 Поиск
                HStack {
                    TextField("Search local businesses...", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)

                    Button("Go") {
                        LocationAPI.search(query: query) { self.locations = $0 }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top)

                // 📍 Список локаций
                List(locations) { loc in
                    NavigationLink(destination:
                        LocationDetailView(
                            location: loc,
                            initialImage: userImages[loc.name], // ✅ передаём существующее фото
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
                            if let img = userImages[loc.name] {
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
                    Button("Save PDF") {
                        generatePDFReport()
                    }
                }
            }
            .task {
                loadSavedImages()
            }
        }
    }

    // MARK: - 🗂 Загрузка сохранённых фото
    private func loadSavedImages() {
        guard let data = try? Data(contentsOf: infoURL),
              let savedInfos = try? JSONDecoder().decode([String: HuntPhotoInfo].self, from: data)
        else { return }

        photoInfos = savedInfos
        for (locName, info) in savedInfos {
            let fileURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(info.filename)
            if let imageData = try? Data(contentsOf: fileURL),
               let image = UIImage(data: imageData) {
                userImages[locName] = image
            }
        }
    }

    // MARK: - 💾 Сохранение фото и метаданных
    func saveImage(_ image: UIImage, for location: HuntLocation) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        let filename = "\(location.name.replacingOccurrences(of: " ", with: "_")).jpg"
        let fileURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)

        do {
            try data.write(to: fileURL)
            userImages[location.name] = image
            photoInfos[location.name] = HuntPhotoInfo(filename: filename, date: Date())
            saveInfoToDisk()
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

    // MARK: - 🧾 Красивый PDF отчёт с логотипом
    private func generatePDFReport() {
        guard !locations.isEmpty else { return }

        let pdfMetaData: [CFString: Any] = [
            kCGPDFContextCreator: "CityChamberHunt App",
            kCGPDFContextAuthor: "Irina Safronova",
            kCGPDFContextTitle: "City Chamber Hunt Report"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            // 🟣 COVER PAGE
            context.beginPage()
            let cgContext = context.cgContext

            // Градиент фона
            let gradientColors = [UIColor.systemPurple.cgColor, UIColor.systemIndigo.cgColor]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: gradientColors as CFArray,
                                         locations: [0.0, 1.0]) {
                cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: 0, y: pageHeight),
                    options: []
                )
            }

            // Логотип (из Assets.xcassets)
            if let logo = UIImage(named: "CityChamberHunt_logo") {
                let logoRect = CGRect(x: (pageWidth - 160) / 2, y: 120, width: 160, height: 160)
                logo.draw(in: logoRect)
            }

            // Заголовок
            let title = "City Chamber Hunt Report"
            title.draw(in: CGRect(x: 40, y: 320, width: pageWidth - 80, height: 50),
                       withAttributes: [
                        .font: UIFont.boldSystemFont(ofSize: 28),
                        .foregroundColor: UIColor.white
                       ])

            // Подзаголовок
            let subtitle = "Your local adventure summary"
            subtitle.draw(in: CGRect(x: 40, y: 370, width: pageWidth - 80, height: 30),
                          withAttributes: [
                            .font: UIFont.systemFont(ofSize: 16),
                            .foregroundColor: UIColor.white.withAlphaComponent(0.8)
                          ])

            // Дата и количество
            let date = Date().formatted(date: .abbreviated, time: .shortened)
            let dateText = "📅 Generated on \(date)"
            dateText.draw(in: CGRect(x: 40, y: 420, width: pageWidth - 80, height: 30),
                          withAttributes: [
                            .font: UIFont.systemFont(ofSize: 14),
                            .foregroundColor: UIColor.white
                          ])

            let countText = "🏆 You discovered \(userImages.count) of \(locations.count) locations!"
            countText.draw(in: CGRect(x: 40, y: 460, width: pageWidth - 80, height: 30),
                           withAttributes: [
                            .font: UIFont.boldSystemFont(ofSize: 18),
                            .foregroundColor: UIColor.white
                           ])

            // Footer
            let footer = "CityChamberHunt © \(Calendar.current.component(.year, from: Date()))"
            footer.draw(in: CGRect(x: 40, y: pageHeight - 60, width: pageWidth - 80, height: 20),
                        withAttributes: [
                            .font: UIFont.systemFont(ofSize: 12),
                            .foregroundColor: UIColor.white.withAlphaComponent(0.8)
                        ])

            // 📍 Каждая локация на отдельной странице
            for loc in locations {
                context.beginPage()

                cgContext.setFillColor(UIColor.systemIndigo.cgColor)
                cgContext.fill(CGRect(x: 0, y: 0, width: pageWidth, height: 80))

                let title = loc.name
                title.draw(in: CGRect(x: 30, y: 25, width: pageWidth - 60, height: 30),
                           withAttributes: [
                            .font: UIFont.boldSystemFont(ofSize: 22),
                            .foregroundColor: UIColor.white
                           ])

                let address = "📍 \(loc.address)"
                address.draw(in: CGRect(x: 30, y: 90, width: pageWidth - 60, height: 50),
                             withAttributes: [
                                .font: UIFont.systemFont(ofSize: 14),
                                .foregroundColor: UIColor.darkGray
                             ])

                if let image = userImages[loc.name] {
                    let maxWidth: CGFloat = pageWidth - 80
                    let maxHeight: CGFloat = 400
                    let aspect = image.size.width / image.size.height
                    var imgWidth = maxWidth
                    var imgHeight = imgWidth / aspect
                    if imgHeight > maxHeight {
                        imgHeight = maxHeight
                        imgWidth = imgHeight * aspect
                    }

                    let imgRect = CGRect(
                        x: (pageWidth - imgWidth) / 2,
                        y: 150,
                        width: imgWidth,
                        height: imgHeight
                    )
                    image.draw(in: imgRect)

                    if let info = photoInfos[loc.name] {
                        let formatter = DateFormatter()
                        formatter.dateStyle = .medium
                        formatter.timeStyle = .short
                        let dateString = formatter.string(from: info.date)
                        let text = "📸 Taken on \(dateString)"
                        text.draw(in: CGRect(x: 30, y: imgRect.maxY + 12, width: pageWidth - 60, height: 20),
                                  withAttributes: [
                                    .font: UIFont.systemFont(ofSize: 13),
                                    .foregroundColor: UIColor.systemGray
                                  ])
                    }
                } else {
                    let placeholder = "No photo available for this location."
                    placeholder.draw(in: CGRect(x: 30, y: 160, width: pageWidth - 60, height: 30),
                                     withAttributes: [
                                        .font: UIFont.italicSystemFont(ofSize: 14),
                                        .foregroundColor: UIColor.systemGray
                                     ])
                }
            }
        }

        // 💾 Сохраняем PDF в Documents
        let pdfURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CityHunt_Report_\(Date().formatted(date: .abbreviated, time: .omitted)).pdf")

        do {
            try data.write(to: pdfURL)
            print("✅ PDF saved at \(pdfURL.path)")

            let activityVC = UIActivityViewController(activityItems: [pdfURL], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        } catch {
            print("❌ Error saving PDF: \(error)")
        }
    }
}

#Preview {
    ContentView()
}
