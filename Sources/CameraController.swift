import Foundation
import AVFoundation
import Vision
import os.log

final class CameraController: NSObject, ObservableObject {
    enum State {
        case idle
        case requesting
        case authorized
        case denied
        case noCamera
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var pathPoints: [CGPoint] = []
    @Published private(set) var isTracking = false

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "CameraController.sessionQueue")
    private let videoOutputQueue = DispatchQueue(label: "CameraController.videoOutputQueue")
    private var isConfigured = false
    private let handPoseRequest: VNDetectHumanHandPoseRequest = {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1
        return request
    }()
    private let visionSequenceHandler = VNSequenceRequestHandler()
    private let maxRecordedPoints = 2_000
    private let logger = OSLog(subsystem: "com.example.CameraPreview", category: "CameraController")

    override init() {
        session.sessionPreset = .high
        super.init()
    }

    func start() {
        handleAuthorization()
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
        setTracking(false)
        clearDrawing()
    }

    func toggleTracking() {
        setTracking(!isTracking)
    }

    func setTracking(_ enabled: Bool) {
        Task { @MainActor in
            self.isTracking = enabled
            if !enabled {
                self.pathPoints.removeAll()
            }
        }
    }

    func clearDrawing() {
        Task { @MainActor in
            self.pathPoints.removeAll()
        }
    }

    private func handleAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            updateState(.authorized)
            configureSessionIfNeeded()
        case .notDetermined:
            updateState(.requesting)
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.updateState(granted ? .authorized : .denied)
                    if granted {
                        self.configureSessionIfNeeded()
                    }
                }
            }
        case .denied, .restricted:
            updateState(.denied)
        @unknown default:
            updateState(.failed("Unknown authorization status."))
        }
    }

    private func configureSessionIfNeeded() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard !self.isConfigured else {
                self.startSessionIfNeeded()
                return
            }

            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified) ??
                    AVCaptureDevice.default(for: .video) else {
                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    self.updateState(.noCamera)
                }
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                }
            } catch {
                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    self.updateState(.failed(error.localizedDescription))
                }
                return
            }

            let videoDataOutput = AVCaptureVideoDataOutput()
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            if self.session.canAddOutput(videoDataOutput) {
                self.session.addOutput(videoDataOutput)
                videoDataOutput.setSampleBufferDelegate(self, queue: self.videoOutputQueue)
            }

            self.session.commitConfiguration()
            self.isConfigured = true
            self.startSessionIfNeeded()
        }
    }

    private func startSessionIfNeeded() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.session.isRunning {
                self.session.startRunning()
                os_log("Session started", log: logger, type: .info)
            } else {
                os_log("Session already running", log: logger, type: .debug)
            }
        }
    }

    private func updateState(_ newValue: State) {
        Task { @MainActor in
            self.state = newValue
            os_log("State changed to %{public}@", log: logger, type: .info, String(describing: newValue))
        }
    }

    private func appendFingerPoint(_ point: CGPoint) {
        Task { @MainActor in
            var updated = self.pathPoints
            updated.append(point)
            if updated.count > self.maxRecordedPoints {
                updated.removeFirst(updated.count - self.maxRecordedPoints)
            }
            self.pathPoints = updated
        }
    }
}

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isTracking,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        do {
            try visionSequenceHandler.perform([handPoseRequest], on: pixelBuffer)
            guard let observation = handPoseRequest.results?.first else { return }
            guard let tip = try? observation.recognizedPoint(.indexTip), tip.confidence > 0.3 else { return }
            appendFingerPoint(tip.location)
        } catch {
            // Ignore transient Vision failures
        }
    }
}

extension CameraController.State {
    var statusDescription: String {
        switch self {
        case .idle: return "idle"
        case .requesting: return "requesting permission"
        case .authorized: return "authorized"
        case .denied: return "denied"
        case .noCamera: return "no camera"
        case .failed: return "failed"
        }
    }
}
