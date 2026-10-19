import UIKit
import CoreGraphics

// How a view's layer is rasterised, which is what the release of a view is made of. Apple's type is
// nested - `_RendererConfiguration.RasterizationOptions` in both the SDK of 16.4
// (`arm64e-apple-ios.swiftinterface:17490`) and the one of 26.2 - so it is nested here too, and the
// interface spells the seven properties and `init()` and gives no initial value for any of them.
//
// The seven defaults are the framework's own, read off it on the host with
// `eidolon/host/hostrenderer.swift` (an underscored name is public in Swift, so the type is in
// scope there): colorMode nonLinear, rendersAsynchronously false, isOpaque true, drawsPlatformViews
// true, prefersDisplayCompositing false, maxDrawableCount 3, rbColorMode nil. An earlier version of
// this file had three of the seven wrong and claimed no source existed; the measurement was there.
/// The configuration of the release that draws a view. This is Apple's own name, exactly: both the
/// SDK of 16.4 (`arm64e-apple-ios.swiftinterface:17488`) and the one of 26.2 declare
/// `_RendererConfiguration` with `RasterizationOptions` nested in it. An underscored name in Swift is
/// public, so the host can be asked for the defaults, and it answers - see the seven values below.
public struct _RendererConfiguration {
    public struct RasterizationOptions {
        public var colorMode: ColorRenderingMode
    /// The `rbColorMode` the release sends down to its own rendering, where it has one. iOS 6's
    /// `CALayer` has no such key, so it is nil and nothing is sent.
        public var rbColorMode: Int32?
        public var rendersAsynchronously: Bool
        public var isOpaque: Bool
        public var drawsPlatformViews: Bool
        public var prefersDisplayCompositing: Bool
        public var maxDrawableCount: Int

        public init() {
            colorMode = .nonLinear
            rbColorMode = nil
            rendersAsynchronously = false
            isOpaque = true
            drawsPlatformViews = true
            prefersDisplayCompositing = false
            maxDrawableCount = 3
        }
    }
}

// No environment key: Apple's type is a parameter of the APIs that take it, and neither SDK declares
// one in `EnvironmentValues` - the reverse check is what caught that the first version of this file had.

extension _RendererConfiguration.RasterizationOptions {
    /// The layer settings the release's own rasterisation asks for. `shouldRasterize` and the scale are
    /// the two `CALayer` of iOS 6 has, and a colour mode or a drawable count is a key it does not, so
    /// those do not reach it.
    func applied(to layer: CALayer) {
        // of the seven, three reach a `CALayer` of iOS 6: whether it is drawn on the main thread,
        // whether it is opaque, and the scale it is rasterised at. A colour mode, a drawable count and
        // a preference for the system's compositing are keys that layer has none of.
        layer.drawsAsynchronously = rendersAsynchronously
        layer.isOpaque = isOpaque
        layer.rasterizationScale = 0
        layer.rasterizationScale = UIScreen.main.scale
    }
}


/// The renderer a view is drawn with, nested in the same place Apple nests it
/// (`_RendererConfiguration` of the SDK of 16.4, `arm64e-apple-ios.swiftinterface:14472`): the default
/// one, or a rasterised one with the options. The type carries no availability annotation, so it is
/// available on iOS 6 like the rest of its neighbours, and the two cases are Apple's.
extension _RendererConfiguration {
    public enum Renderer {
        case `default`
        indirect case rasterized(RasterizationOptions = .init())
    }
}
