import UIKit
import CoreGraphics

public struct _RendererConfiguration {
    public struct RasterizationOptions {
        public var colorMode: ColorRenderingMode
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

extension _RendererConfiguration.RasterizationOptions {
    func applied(to layer: CALayer) {
        layer.drawsAsynchronously = rendersAsynchronously
        layer.isOpaque = isOpaque
        layer.rasterizationScale = 0
        layer.rasterizationScale = UIScreen.main.scale
    }
}


extension _RendererConfiguration {
    public enum Renderer {
        case `default`
        indirect case rasterized(RasterizationOptions = .init())
    }
}
