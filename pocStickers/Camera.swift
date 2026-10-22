import AVFoundation
import PhotosUI
import SwiftUI

@Observable
@MainActor
final class CameraController: NSObject, AVCapturePhotoCaptureDelegate {
    enum Status {
        case checking
        case ready
        case denied
        case unavailable
    }

    var status = Status.checking
    var isCapturing = false

    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var pending: CheckedContinuation<Data, Error>?

    func start() async {
        let granted: Bool
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            granted = true
        case .notDetermined:
            granted = await AVCaptureDevice.requestAccess(for: .video)
        default:
            granted = false
        }
        guard granted else {
            status = .denied
            return
        }
        guard configure() else {
            status = .unavailable
            return
        }
        status = .ready
        let session = session
        Task.detached {
            if !session.isRunning {
                session.startRunning()
            }
        }
    }

    func stop() {
        let session = session
        Task.detached {
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    func capture() async throws -> Data {
        isCapturing = true
        defer { isCapturing = false }
        return try await withCheckedThrowingContinuation { continuation in
            pending = continuation
            if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let data = photo.fileDataRepresentation()
        Task { @MainActor in
            if let data {
                pending?.resume(returning: data)
            } else {
                pending?.resume(throwing: error ?? CameraError.noData)
            }
            pending = nil
        }
    }

    private func configure() -> Bool {
        guard session.inputs.isEmpty else { return true }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return false }

        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        guard session.canAddInput(input), session.canAddOutput(output) else { return false }
        session.addInput(input)
        session.addOutput(output)
        return true
    }
}

enum CameraError: Error {
    case noData
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}

struct CameraScreen: View {
    @Binding var pickerItem: PhotosPickerItem?
    let onCapture: (Data) -> Void
    let onSample: () -> Void
    let onClose: () -> Void

    @State private var camera = CameraController()
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch camera.status {
            case .ready:
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(.white.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [10, 8]))
                    .padding(48)
                    .allowsHitTesting(false)
            case .checking:
                ProgressView()
                    .tint(.white)
            case .denied:
                VStack(spacing: 12) {
                    Text("Camera access is off")
                        .foregroundStyle(.white)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            case .unavailable:
                Text("No camera on this device")
                    .foregroundStyle(.white)
            }

            VStack {
                Spacer()
                Text("Place it on a plain surface")
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.5), in: Capsule())

                HStack {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(.black.opacity(0.5), in: Circle())
                    }
                    .frame(maxWidth: .infinity)

                    Button(action: shoot) {
                        Circle()
                            .fill(.white)
                            .frame(width: 68, height: 68)
                            .overlay(Circle().strokeBorder(.black.opacity(0.2), lineWidth: 3))
                            .padding(5)
                            .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                    }
                    .disabled(camera.status != .ready || camera.isCapturing)
                    .frame(maxWidth: .infinity)

                    Button("Sample", action: onSample)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                }
                .padding(.bottom, 24)
            }
        }
        .overlay(alignment: .topLeading) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.black.opacity(0.5)))
            }
            .accessibilityIdentifier("camera-close")
            .padding()
        }
        .task { await camera.start() }
        .onDisappear { camera.stop() }
    }

    private func shoot() {
        Task {
            if let data = try? await camera.capture() {
                onCapture(data)
            }
        }
    }
}
