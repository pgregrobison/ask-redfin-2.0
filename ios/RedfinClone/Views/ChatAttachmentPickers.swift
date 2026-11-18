import SwiftUI
import PhotosUI
import UIKit
import UniformTypeIdentifiers
import AVFoundation

struct ChatCameraPicker: UIViewControllerRepresentable {
    enum Mode: String, Identifiable {
        case photo
        case video
        var id: String { rawValue }
    }

    let mode: Mode
    let onPicked: (ChatAttachment) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            // Cloud simulator fallback: show placeholder.
            let host = UIHostingController(rootView: ChatCameraUnavailableView(onClose: onCancel))
            return host
        }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.cameraCaptureMode = mode == .photo ? .photo : .video
        switch mode {
        case .photo:
            picker.mediaTypes = [UTType.image.identifier]
        case .video:
            picker.mediaTypes = [UTType.movie.identifier]
            picker.videoQuality = .typeHigh
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    @MainActor
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ChatCameraPicker

        init(parent: ChatCameraPicker) {
            self.parent = parent
        }

        nonisolated func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = info[.originalImage] as? UIImage
            let videoURL = info[.mediaURL] as? URL
            Task { @MainActor in
                if let videoURL {
                    if let att = AttachmentStore.saveVideo(at: videoURL) {
                        parent.onPicked(att)
                    } else {
                        parent.onCancel()
                    }
                } else if let image {
                    if let att = AttachmentStore.saveImage(image) {
                        parent.onPicked(att)
                    } else {
                        parent.onCancel()
                    }
                } else {
                    parent.onCancel()
                }
            }
        }

        nonisolated func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            Task { @MainActor in
                parent.onCancel()
            }
        }
    }
}

private struct ChatCameraUnavailableView: View {
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.white.opacity(0.7))
                Text("Camera unavailable")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(.white)
                Text("Install this app on your device via the Rork App to use the camera.")
                    .font(Theme.Typography.secondary)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 32)
                Button("Close", action: onClose)
                    .buttonStyle(.borderedProminent)
                    .tint(.white.opacity(0.2))
                    .foregroundStyle(.white)
                    .padding(.top, 8)
            }
        }
    }
}
