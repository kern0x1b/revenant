import SwiftUI
// Apple's type is `_RendererConfiguration.RasterizationOptions`; an underscored name in Swift is
// public, so the host can be asked for its seven defaults.
let o = _RendererConfiguration.RasterizationOptions()
print("colorMode=\(o.colorMode) rendersAsynchronously=\(o.rendersAsynchronously) isOpaque=\(o.isOpaque)")
print("drawsPlatformViews=\(o.drawsPlatformViews) prefersDisplayCompositing=\(o.prefersDisplayCompositing)")
print("maxDrawableCount=\(o.maxDrawableCount) rbColorMode=\(String(describing: o.rbColorMode))")
