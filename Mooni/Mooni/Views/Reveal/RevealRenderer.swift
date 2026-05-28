import SwiftUI
import UIKit

/// Renders a `RevealCard` to a `UIImage` at 1080×1920 (9:16 portrait — TikTok
/// / Stories / Reels native aspect). The output is a single PNG-backed image
/// that ShareLink hands off to the system share sheet; no AVFoundation needed.
///
/// Usage:
///   if let img = RevealRenderer.render(stats: stats, template: .night) { ... }
///
/// The renderer runs on the main actor because `ImageRenderer` ultimately
/// drives UIKit-backed drawing. Call it from a Task on `@MainActor` (which
/// SwiftUI views already are) — typical render time is 30–80ms on an A17.
@MainActor
enum RevealRenderer {
    /// Default output dimensions. 1080×1920 fills a TikTok / Story frame
    /// without any letterboxing on modern phones.
    static let outputSize = CGSize(width: 1080, height: 1920)

    static func render(stats: RevealStats, template: RevealTemplate) -> UIImage? {
        let card = RevealCard(stats: stats, template: template, canvasSize: outputSize)
            .frame(width: outputSize.width, height: outputSize.height)

        let renderer = ImageRenderer(content: card)
        renderer.proposedSize = .init(outputSize)
        // Scale of 1 — our canvas is already in pixel coordinates.
        renderer.scale = 1.0

        return renderer.uiImage
    }

    /// Convenience wrapper that returns a `Transferable` ready for `ShareLink`.
    /// Returns nil if rendering failed (rare — usually a font/asset miss).
    static func shareItem(stats: RevealStats, template: RevealTemplate) -> Image? {
        guard let ui = render(stats: stats, template: template) else { return nil }
        return Image(uiImage: ui)
    }
}
