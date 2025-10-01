//
//  CameraPicker.swift
//  CityChamberHunt
//

import SwiftUI
import UIKit

struct CameraPicker: UIViewControllerRepresentable {
    var onImagePicked: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    // MARK: - Coordinator
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var onImagePicked: (UIImage?) -> Void

        init(onImagePicked: @escaping (UIImage?) -> Void) {
            self.onImagePicked = onImagePicked
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            picker.dismiss(animated: true)

            guard let originalImage = info[.originalImage] as? UIImage else {
                onImagePicked(nil)
                return
            }

            var fixedImage = originalImage.fixedOrientation()

            // ✅ Зеркалим только если фото сделано фронтальной камерой
            if picker.cameraDevice == .front {
                fixedImage = fixedImage.withHorizontallyFlippedOrientation()
            }

            onImagePicked(fixedImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            onImagePicked(nil)
        }
    }
}

// MARK: - UIImage Extension
extension UIImage {
    /// Исправление EXIF ориентации → всегда .up
    func fixedOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return normalizedImage
    }
}

#Preview {
    CameraPicker { _ in }
}
