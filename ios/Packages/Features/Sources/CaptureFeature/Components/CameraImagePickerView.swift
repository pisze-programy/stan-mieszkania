import DesignSystem
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)
  import UIKit

  struct CameraImagePickerView: UIViewControllerRepresentable {
    let onCapture: (Data) -> Void
    let onCancel: () -> Void

    static var isCameraAvailable: Bool {
      UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeCoordinator() -> Coordinator {
      Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
      let picker = UIImagePickerController()
      picker.sourceType = .camera
      // Decision S2-6 & §3: Cropping is strictly disallowed so saved file matches capture.
      picker.allowsEditing = false
      picker.delegate = context.coordinator
      return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    typealias PickerDelegates = UINavigationControllerDelegate & UIImagePickerControllerDelegate

    final class Coordinator: NSObject, PickerDelegates {
      private let onCapture: (Data) -> Void
      private let onCancel: () -> Void

      init(onCapture: @escaping (Data) -> Void, onCancel: @escaping () -> Void) {
        self.onCapture = onCapture
        self.onCancel = onCancel
      }

      func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        onCancel()
      }

      func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
      ) {
        if let imageURL = info[.imageURL] as? URL, let rawBytes = try? Data(contentsOf: imageURL) {
          onCapture(rawBytes)
          return
        }

        guard let image = info[.originalImage] as? UIImage else {
          onCancel()
          return
        }

        if let jpegWithMetadata = encodeJPEGWithMetadata(
          image: image,
          metadata: info[.mediaMetadata] as? [CFString: Any]
        ) {
          onCapture(jpegWithMetadata)
          return
        }

        let quality = CaptureConstants.jpegExportQuality
        if let fallbackData = image.jpegData(compressionQuality: quality) {
          onCapture(fallbackData)
        } else {
          onCancel()
        }
      }

      private func encodeJPEGWithMetadata(
        image: UIImage,
        metadata: [CFString: Any]?
      ) -> Data? {
        guard let cgImage = image.cgImage else {
          return nil
        }
        let mutableData = NSMutableData()
        guard
          let destination = CGImageDestinationCreateWithData(
            mutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
          )
        else {
          return nil
        }
        var properties = metadata ?? [:]
        properties[kCGImageDestinationLossyCompressionQuality] = CaptureConstants.jpegExportQuality
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
          return nil
        }
        return mutableData as Data
      }
    }
  }
#else
  struct CameraImagePickerView: View {
    let onCapture: (Data) -> Void
    let onCancel: () -> Void

    static var isCameraAvailable: Bool { false }

    var body: some View {
      ContentUnavailableView(
        L10n.string("capture.camera.unavailable"),
        systemImage: "camera.fill"
      )
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(L10n.string("apartments.create.cancel.cta"), action: onCancel)
        }
      }
    }
  }
#endif
