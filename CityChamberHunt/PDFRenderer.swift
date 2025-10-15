//
//  PDFRenderer.swift
//  CityChamberHunt
//
//  Created by Irina Safronova on 2025-10-15.
//

import UIKit
import PDFKit

enum PDFRenderer {
    /// Заголовок страницы
    static func drawHeader(title: String, address: String, on ctx: UIGraphicsPDFRendererContext, in rect: CGRect) {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: UIColor.label
        ]
        let addressAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.secondaryLabel
        ]

        title.draw(in: CGRect(x: 20, y: 20, width: rect.width - 40, height: 25), withAttributes: titleAttributes)
        address.draw(in: CGRect(x: 20, y: 45, width: rect.width - 40, height: 40), withAttributes: addressAttributes)
    }

    /// Фото пользователя
    static func drawImage(_ image: UIImage, in rect: CGRect) {
        let maxWidth = rect.width - 60
        let maxHeight: CGFloat = 220
        let aspect = image.size.width / image.size.height
        let width = min(maxWidth, maxHeight * aspect)
        let xOffset = (rect.width - width) / 2
        let imgRect = CGRect(x: xOffset, y: 100, width: width, height: maxHeight)
        image.draw(in: imgRect)
    }

    /// Метаданные фото (дата, источник, адрес)
    static func drawMeta(_ info: HuntPhotoInfo, on ctx: UIGraphicsPDFRendererContext, in rect: CGRect) {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        let dateText = df.string(from: info.dateAdded)

        var meta = "📅 \(dateText) • 📸 \(info.source)"
        if let addr = info.address {
            meta += "\n📍 \(addr)"
        }
        if let lat = info.latitude, let lon = info.longitude {
            meta += String(format: "\n🌐 %.4f, %.4f", lat, lon)
        }

        meta.draw(in: CGRect(x: 20, y: 330, width: rect.width - 40, height: 70),
                  withAttributes: [
                    .font: UIFont.systemFont(ofSize: 12),
                    .foregroundColor: UIColor.gray
                  ])
    }

    /// Картинка карты
    static func drawMap(_ image: UIImage, on ctx: UIGraphicsPDFRendererContext, in rect: CGRect) {
        let mapRect = CGRect(x: (rect.width - 260) / 2, y: 420, width: 260, height: 160)
        image.draw(in: mapRect)
        "🗺 Map data © OpenStreetMap / Apple MapKit"
            .draw(in: CGRect(x: 0, y: mapRect.maxY + 10, width: rect.width, height: 20),
                  withAttributes: [
                    .font: UIFont.systemFont(ofSize: 10),
                    .paragraphStyle: {
                        let p = NSMutableParagraphStyle()
                        p.alignment = .center
                        return p
                    }(),
                    .foregroundColor: UIColor.gray
                  ])
    }
}
