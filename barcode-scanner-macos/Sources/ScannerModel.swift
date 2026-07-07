import AppKit
import AVFoundation
import SwiftUI
import Vision

final class ScannerModel: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    enum State: Equatable {
        case idle
        case requestingAccess
        case scanning
        case detected(type: String)
        case denied
        case failed(String)
    }

    let session = AVCaptureSession()

    @Published private(set) var state: State = .idle
    @Published private(set) var detectedPayload: String?
    @Published private(set) var detectedURL: URL?

    private let sessionQueue = DispatchQueue(label: "BarcodeScanner.session")
    private let videoQueue = DispatchQueue(label: "BarcodeScanner.video")
    private var configured = false
    private var videoOutput: AVCaptureVideoDataOutput?
    private var shouldAnalyzeFrames = true
    private var lastAnalysisTime: CFTimeInterval = 0
    private let minimumAnalysisInterval: CFTimeInterval = 0.12

    var hasResult: Bool {
        detectedPayload != nil
    }

    var statusTitle: String {
        switch state {
        case .idle:
            return "Ready"
        case .requestingAccess:
            return "Camera Permission"
        case .scanning:
            return "Scanning"
        case .detected:
            return detectedURL == nil ? "Payload Found" : "URL Found"
        case .denied:
            return "Camera Blocked"
        case .failed:
            return "Camera Error"
        }
    }

    var statusDetail: String {
        switch state {
        case .idle:
            return "Camera session is waiting."
        case .requestingAccess:
            return "macOS is requesting camera access."
        case .scanning:
            return "No barcode payload has been decoded yet."
        case .detected(let type):
            return "Decoded \(friendlyTypeName(type))."
        case .denied:
            return "Enable camera access for BarcodeScanner in System Settings."
        case .failed(let message):
            return message
        }
    }

    var statusSymbol: String {
        switch state {
        case .idle, .scanning:
            return "viewfinder"
        case .requestingAccess:
            return "camera"
        case .detected:
            return "checkmark.circle.fill"
        case .denied:
            return "lock.slash"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    var accentColor: Color {
        switch state {
        case .detected:
            return Color(red: 0.21, green: 0.75, blue: 0.44)
        case .denied, .failed:
            return Color(red: 0.94, green: 0.31, blue: 0.27)
        default:
            return Color(red: 0.19, green: 0.55, blue: 0.96)
        }
    }

    var resultHeading: String {
        detectedURL == nil ? "Payload" : "URL"
    }

    var resultText: String {
        if let detectedURL {
            return detectedURL.absoluteString
        }

        if let detectedPayload {
            return detectedPayload
        }

        return "Waiting for scan..."
    }

    func requestAccessAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            start()
        case .notDetermined:
            state = .requestingAccess
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    granted ? self.start() : self.markDenied()
                }
            }
        case .denied, .restricted:
            markDenied()
        @unknown default:
            markFailed("Unknown camera authorization state.")
        }
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            do {
                try self.configureSessionIfNeeded()
            } catch {
                DispatchQueue.main.async {
                    self.markFailed(error.localizedDescription)
                }
                return
            }

            if !self.session.isRunning {
                self.session.startRunning()
            }

            DispatchQueue.main.async {
                if self.detectedPayload == nil {
                    self.state = .scanning
                }
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func reset() {
        detectedPayload = nil
        detectedURL = nil
        state = session.isRunning ? .scanning : .idle
        videoQueue.async { [weak self] in
            self?.shouldAnalyzeFrames = true
            self?.lastAnalysisTime = 0
        }
    }

    func copyResult() {
        guard hasResult else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(resultText, forType: .string)
    }

    func openURL() {
        guard let detectedURL else { return }
        NSWorkspace.shared.open(detectedURL)
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard shouldAnalyzeFrames else { return }

        let now = CACurrentMediaTime()
        guard now - lastAnalysisTime >= minimumAnalysisInterval else { return }
        lastAnalysisTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let request = VNDetectBarcodesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return
        }

        guard
            let barcode = request.results?.first(where: { observation in
                guard let value = observation.payloadStringValue else { return false }
                return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }),
            let value = barcode.payloadStringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty
        else {
            return
        }

        shouldAnalyzeFrames = false

        DispatchQueue.main.async { [weak self] in
            guard let self, self.detectedPayload != value else { return }
            self.detectedPayload = value
            self.detectedURL = Self.normalizedURL(from: value)
            self.state = .detected(type: barcode.symbology.rawValue)
            NSSound(named: "Glass")?.play()
        }
    }

    private func configureSessionIfNeeded() throws {
        guard !configured else { return }

        session.beginConfiguration()
        defer {
            session.commitConfiguration()
        }

        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(for: .video) else {
            throw ScannerError.noCamera
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            throw ScannerError.cannotAddCameraInput
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        guard session.canAddOutput(output) else {
            throw ScannerError.cannotAddVideoOutput
        }

        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: videoQueue)
        session.addOutput(output)

        videoOutput = output
        configured = true
    }

    private func markDenied() {
        state = .denied
    }

    private func markFailed(_ message: String) {
        state = .failed(message)
    }

    private func friendlyTypeName(_ rawType: String) -> String {
        rawType
            .replacingOccurrences(of: "org.iso.", with: "")
            .replacingOccurrences(of: "org.gs1.", with: "")
            .replacingOccurrences(of: "com.intermec.", with: "")
            .replacingOccurrences(of: "VNBarcodeSymbology", with: "")
            .replacingOccurrences(of: "Barcode", with: "")
            .replacingOccurrences(of: ".", with: " ")
    }

    private static func normalizedURL(from payload: String) -> URL? {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)

        if
            let url = URL(string: trimmed),
            let scheme = url.scheme?.lowercased(),
            ["http", "https"].contains(scheme)
        {
            return url
        }

        let bareDomainPattern = #"^[A-Za-z0-9.-]+\.[A-Za-z]{2,}(:[0-9]+)?(/.*)?$"#
        if trimmed.range(of: bareDomainPattern, options: .regularExpression) != nil {
            return URL(string: "https://\(trimmed)")
        }

        return nil
    }
}

private enum ScannerError: LocalizedError {
    case noCamera
    case cannotAddCameraInput
    case cannotAddVideoOutput

    var errorDescription: String? {
        switch self {
        case .noCamera:
            return "No camera was found on this Mac."
        case .cannotAddCameraInput:
            return "The camera input could not be added to the capture session."
        case .cannotAddVideoOutput:
            return "The camera frame output could not be added to the capture session."
        }
    }
}
