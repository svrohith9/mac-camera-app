import SwiftUI
import AVFoundation
import AppKit

struct ContentView: View {
    @StateObject private var cameraController = CameraController()
    @State private var paintColorIndex = 0
    @State private var isMirrored = true
    @State private var isFlippedVertically = false
    private let paintPalette: [Color] = [.green, .yellow, .orange, .pink, .blue, .cyan, .white]

    var body: some View {
        ZStack {
            switch cameraController.state {
            case .authorized:
                cameraSurface
            case .requesting:
                progressView(text: "Requesting camera access…")
            case .denied:
                infoView(
                    title: "Camera Access Disabled",
                    message: "Open System Settings → Privacy & Security → Camera and allow access for CameraPreview."
                )
            case .noCamera:
                infoView(
                    title: "No Camera Found",
                    message: "Connect a camera and relaunch the app."
                )
            case .failed(let error):
                infoView(
                    title: "Unable to Start Camera",
                    message: error
                )
            case .idle:
                progressView(text: "Preparing camera…")
            }
        }
        .background(Color.black)
        .onAppear {
            cameraController.start()
        }
        .onDisappear {
            cameraController.stop()
        }
    }

    private func progressView(text: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func infoView(title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.title3)
                .bold()
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var cameraSurface: some View {
        CameraPreview(
            session: cameraController.session,
            isMirrored: isMirrored,
            isFlippedVertically: isFlippedVertically
        )
            .background(Color.black)
            .overlay(
                FingerDrawingOverlay(
                    points: cameraController.pathPoints,
                    mirrorHorizontally: isMirrored,
                    flipVertically: isFlippedVertically,
                    color: paintColor,
                    lineWidth: 6
                )
            )
            .overlay(alignment: .bottomLeading) {
                debugOverlay
            }
            .overlay(alignment: .top) {
                controlBar
            }
            .ignoresSafeArea()
    }

    private var paintColor: Color {
        guard !paintPalette.isEmpty else { return .green }
        return paintPalette[paintColorIndex % paintPalette.count]
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            Button {
                cameraController.toggleTracking()
            } label: {
                Label(
                    cameraController.isTracking ? "Stop Painting" : "Start Painting",
                    systemImage: cameraController.isTracking ? "pause.circle.fill" : "hand.draw.fill"
                )
            }
            .buttonStyle(.borderedProminent)

            Button {
                cameraController.clearDrawing()
            } label: {
                Label("Clear Paint", systemImage: "eraser.line.dashed")
            }
            .buttonStyle(.bordered)
            .disabled(cameraController.pathPoints.isEmpty)

            Button {
                paintColorIndex = (paintColorIndex + 1) % max(paintPalette.count, 1)
            } label: {
                Label("Color", systemImage: "paintpalette")
            }
            .buttonStyle(.bordered)

            Button {
                isMirrored.toggle()
            } label: {
                Label(isMirrored ? "Unmirror" : "Mirror", systemImage: "rectangle.on.rectangle.angled")
            }
            .buttonStyle(.bordered)

            Button {
                isFlippedVertically.toggle()
            } label: {
                Label(isFlippedVertically ? "Unflip" : "Flip Vertical", systemImage: "arrow.up.arrow.down")
            }
            .buttonStyle(.bordered)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.top, 24)
    }

    private var debugOverlay: some View {
        VStack(alignment: .leading, spacing: 4) {
            labelRow(systemImage: "camera", text: "State: \(cameraController.state.statusDescription)")
            labelRow(systemImage: "hand.point.up.left.fill", text: cameraController.isTracking ? "Tracking: on" : "Tracking: off")
            if !cameraController.pathPoints.isEmpty {
                labelRow(systemImage: "scribble.variable", text: "Points: \(cameraController.pathPoints.count)")
            }
            labelRow(systemImage: "rectangle.on.rectangle.angled", text: isMirrored ? "Mirror: on" : "Mirror: off")
            labelRow(systemImage: "arrow.up.arrow.down", text: isFlippedVertically ? "Flip: on" : "Flip: off")
        }
        .font(.caption2)
        .padding(8)
        .background(.black.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding()
    }

    private func labelRow(systemImage: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
            Text(text)
        }
        .foregroundStyle(.white)
    }
}

struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession
    var isMirrored: Bool
    var isFlippedVertically: Bool

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoGravity = .resizeAspectFill
        view.session = session
        view.isMirrored = isMirrored
        view.isFlippedVertically = isFlippedVertically
        return view
    }

    func updateNSView(_ nsView: PreviewView, context: Context) {
        nsView.session = session
        nsView.isMirrored = isMirrored
        nsView.isFlippedVertically = isFlippedVertically
    }
}

final class PreviewView: NSView {
    private let previewLayer = AVCaptureVideoPreviewLayer()
    var isMirrored: Bool = true {
        didSet { configureTransforms() }
    }
    var isFlippedVertically: Bool = false {
        didSet { configureTransforms() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        if layer == nil {
            layer = CALayer()
        }
        layer?.backgroundColor = NSColor.black.cgColor
        previewLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(previewLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var videoGravity: AVLayerVideoGravity {
        get { previewLayer.videoGravity }
        set { previewLayer.videoGravity = newValue }
    }

    var session: AVCaptureSession? {
        get { previewLayer.session }
        set {
            previewLayer.session = newValue
            configureTransforms()
        }
    }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
        configureTransforms()
    }

    private func configureTransforms() {
        guard let connection = previewLayer.connection else { return }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = isMirrored
        }
        let scaleY: CGFloat = isFlippedVertically ? -1 : 1
        previewLayer.setAffineTransform(CGAffineTransform(scaleX: 1, y: scaleY))
    }
}

struct FingerDrawingOverlay: View {
    let points: [CGPoint]
    let mirrorHorizontally: Bool
    let flipVertically: Bool
    let color: Color
    let lineWidth: CGFloat

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                guard points.count > 1 else { return }
                var path = Path()
                let start = convert(points[0], in: size)
                path.move(to: start)
                for point in points.dropFirst() {
                    path.addLine(to: convert(point, in: size))
                }
                let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                context.stroke(path, with: .color(color), style: style)
            }
            .allowsHitTesting(false)
            .blendMode(.plusLighter)
        }
    }

    private func convert(_ normalizedPoint: CGPoint, in size: CGSize) -> CGPoint {
        let x = mirrorHorizontally ? (1 - normalizedPoint.x) * size.width : normalizedPoint.x * size.width
        let yNormalized = flipVertically ? normalizedPoint.y : (1 - normalizedPoint.y)
        return CGPoint(
            x: x,
            y: yNormalized * size.height
        )
    }
}
