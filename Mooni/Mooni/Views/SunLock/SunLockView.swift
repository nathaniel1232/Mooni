import SwiftUI
import Combine
@preconcurrency import AVFoundation
import CoreImage
import UIKit

/// Full-screen morning gate. The user can't get to the rest of the app until
/// the camera sees real sunlight (high luminance + saturated bright pixels).
struct SunLockView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var detector = SunDetector()
    @State private var didPass = false

    var body: some View {
        ZStack {
            MooniGradient.night.ignoresSafeArea()
            StarsBackground(count: 60)

            Group {
                switch detector.authorizationState {
                case .authorized:
                    cameraStack
                case .denied:
                    permissionDenied
                case .undetermined, .requesting:
                    loading
                }
            }
            .padding(.horizontal, 22)
        }
        .onAppear { detector.start() }
        .onDisappear { detector.stop() }
        .onChange(of: detector.confidence) { (_: Double, value: Double) in
            if value >= 1.0 && !didPass {
                didPass = true
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
        }
    }

    // MARK: - Sections

    private var cameraStack: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 8)
            sunHero
            titleBlock
            previewCard
            statusCard
            Spacer(minLength: 8)
        }
    }

    private var sunHero: some View {
        ZStack {
            Circle()
                .fill(Color.yellow.opacity(0.18))
                .frame(width: 120, height: 120)
                .blur(radius: 22)
            Image(systemName: "sun.max.fill")
                .font(.system(size: 62))
                .foregroundStyle(
                    LinearGradient(colors: [Color.yellow, Color.orange],
                                   startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: Color.yellow.opacity(0.6), radius: 14)
                .symbolEffect(.pulse, options: .repeating, isActive: !didPass)
        }
    }

    private var titleBlock: some View {
        VStack(spacing: 10) {
            Text(didPass ? "Good morning" : "Show me the sun")
                .font(MooniFont.display(32))
                .foregroundColor(MooniColor.textPrimary)
                .multilineTextAlignment(.center)
            Text(didPass
                 ? "Circadian rhythm: locked in."
                 : "Point your camera at real sunlight to\nunlock the app for today.")
                .font(MooniFont.body(16))
                .foregroundColor(MooniColor.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
    }

    private var previewCard: some View {
        ZStack {
            CameraPreviewView(session: detector.session)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: Color.yellow.opacity(detector.confidence * 0.45),
                        radius: 28)

            if didPass {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.yellow.opacity(0.30))
                    .overlay(
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .yellow.opacity(0.7), radius: 12)
                    )
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .animation(.easeInOut(duration: 0.3), value: didPass)
    }

    private var statusCard: some View {
        MooniCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "sun.haze.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.yellow)
                        .frame(width: 36, height: 36)
                        .background(Color.yellow.opacity(0.16))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(detector.statusMessage)
                            .font(MooniFont.title(14))
                            .foregroundColor(MooniColor.textPrimary)
                        Text("\(Int(detector.confidence * 100))% sunlight detected")
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.textSecondary)
                    }
                    Spacer()
                }
                progressBar(value: detector.confidence)
            }
        }
    }

    private func progressBar(value: Double) -> some View {
        GeometryReader { geo in
            let pct = max(0, min(1, value))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.10))
                Capsule()
                    .fill(
                        LinearGradient(colors: [Color.yellow, Color.orange],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: geo.size.width * CGFloat(pct))
                    .animation(.easeOut(duration: 0.25), value: pct)
            }
            .frame(height: 8)
        }
        .frame(height: 8)
    }

    private var permissionDenied: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                Circle()
                    .fill(MooniColor.warning.opacity(0.15))
                    .frame(width: 110, height: 110)
                    .blur(radius: 18)
                Image(systemName: "camera.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(
                        LinearGradient(colors: [MooniColor.accentSoft, MooniColor.accent],
                                       startPoint: .top, endPoint: .bottom)
                    )
            }
            VStack(spacing: 10) {
                Text("Camera access needed")
                    .font(MooniFont.display(28))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Mooni needs the camera to detect morning\nsunlight. Enable it in Settings to continue.")
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            PrimaryButton(title: "Open Settings", icon: "gear") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .padding(.horizontal, 8)
            Spacer()
        }
    }

    private var loading: some View {
        VStack(spacing: 14) {
            Spacer()
            ProgressView().tint(MooniColor.accent)
            Text("Preparing camera…")
                .font(MooniFont.body(15))
                .foregroundColor(MooniColor.textSecondary)
            Spacer()
        }
    }
}

// MARK: - Camera preview

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

// MARK: - Sun detector

@MainActor
final class SunDetector: NSObject, ObservableObject {
    enum AuthState { case undetermined, requesting, authorized, denied }

    @Published var authorizationState: AuthState = .undetermined
    @Published var confidence: Double = 0      // 0 ... 1
    @Published var statusMessage: String = "Looking for sunlight…"

    nonisolated(unsafe) let session = AVCaptureSession()
    nonisolated(unsafe) private let videoOutput = AVCaptureVideoDataOutput()
    private let sampleQueue = DispatchQueue(label: "mooni.sunlock.video")
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    /// Sustained bright frames (each ~1/15s). Need ~15 in a row (~1s) to unlock.
    private var brightStreak: Int = 0
    private let requiredStreak: Int = 15

    func start() {
        #if targetEnvironment(simulator)
        // No real camera on the simulator — auto-pass after a brief beat so
        // developers aren't permanently locked out while iterating.
        authorizationState = .authorized
        statusMessage = "Simulator: simulating sunlight…"
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            self.confidence = 1.0
        }
        return
        #else
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorizationState = .authorized
            configureAndStart()
        case .notDetermined:
            authorizationState = .requesting
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    guard let self else { return }
                    if granted {
                        self.authorizationState = .authorized
                        self.configureAndStart()
                    } else {
                        self.authorizationState = .denied
                    }
                }
            }
        case .denied, .restricted:
            authorizationState = .denied
        @unknown default:
            authorizationState = .denied
        }
        #endif
    }

    func stop() {
        let session = self.session
        sampleQueue.async {
            if session.isRunning { session.stopRunning() }
        }
    }

    private func configureAndStart() {
        sampleQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .medium

            // Wide camera, back. Fall back to front if unavailable.
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(for: .video)

            guard let device,
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else {
                self.session.commitConfiguration()
                return
            }
            self.session.addInput(input)

            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            self.videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            self.videoOutput.setSampleBufferDelegate(self, queue: self.sampleQueue)
            if self.session.canAddOutput(self.videoOutput) {
                self.session.addOutput(self.videoOutput)
            }

            self.session.commitConfiguration()
            self.session.startRunning()
        }
    }

    /// Returns (avgBrightness 0..1, brightFraction 0..1) where brightFraction is
    /// the share of pixels above ~0.95 luminance — characteristic of a saturated sun.
    nonisolated private func analyze(_ pixelBuffer: CVPixelBuffer) -> (Double, Double)? {
        let ci = CIImage(cvPixelBuffer: pixelBuffer)
        // Downsample for speed.
        let scale = 64.0 / max(ci.extent.width, ci.extent.height)
        let small = ci.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let extent = small.extent

        guard let cg = ciContext.createCGImage(small, from: extent) else { return nil }
        let width = cg.width
        let height = cg.height
        let bytesPerRow = width * 4
        let total = width * height
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: total * 4)
        defer { buffer.deallocate() }
        buffer.initialize(repeating: 0, count: total * 4)

        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: buffer,
                                  width: width,
                                  height: height,
                                  bitsPerComponent: 8,
                                  bytesPerRow: bytesPerRow,
                                  space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        var lumaSum: Double = 0
        var brightCount: Int = 0

        for i in stride(from: 0, to: total * 4, by: 4) {
            let r = Double(buffer[i]) / 255.0
            let g = Double(buffer[i + 1]) / 255.0
            let b = Double(buffer[i + 2]) / 255.0
            let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
            lumaSum += luma
            if luma > 0.95 { brightCount += 1 }
        }

        let avg = lumaSum / Double(total)
        let frac = Double(brightCount) / Double(total)
        return (avg, frac)
    }
}

extension SunDetector: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput,
                                   didOutput sampleBuffer: CMSampleBuffer,
                                   from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard let (avg, brightFrac) = analyze(pixelBuffer) else { return }

        // Sun heuristic: scene must be globally bright AND contain a saturated hot spot.
        let isSunny = avg > 0.55 && brightFrac > 0.01

        Task { @MainActor in
            if isSunny {
                self.brightStreak = min(self.brightStreak + 1, self.requiredStreak)
            } else {
                self.brightStreak = max(self.brightStreak - 1, 0)
            }
            self.confidence = Double(self.brightStreak) / Double(self.requiredStreak)
            self.statusMessage = self.message(for: avg, brightFrac: brightFrac)
        }
    }

    @MainActor
    private func message(for avg: Double, brightFrac: Double) -> String {
        if confidence >= 1.0 { return "Locked in. Have a great day." }
        if brightFrac > 0.005 { return "Almost there — hold steady." }
        if avg > 0.4 { return "Brighter — find direct sunlight." }
        return "Too dark. Point at a window or step outside."
    }
}
