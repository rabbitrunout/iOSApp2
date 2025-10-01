//
//  CameraPicker.swift
//  CityChamberHunt
//
//  Created by Irina Saf on 2025-10-01.
//

import SwiftUI
import UIKit

struct CameraPicker: UIViewControllerRepresentable {
    var onCapture: (UIImage?) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }
        
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
                ?? info[.originalImage] as? UIImage
            parent.onCapture(image)
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCapture(nil)
            picker.dismiss(animated: true)
        }
    }
}


#Preview {
    CameraPicker { _ in } // заглушка для Canvas
}

