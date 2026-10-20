import SwiftUI
let o = _RendererConfiguration.RasterizationOptions()
print("colorMode=\(o.colorMode) rendersAsynchronously=\(o.rendersAsynchronously) isOpaque=\(o.isOpaque)")
print("drawsPlatformViews=\(o.drawsPlatformViews) prefersDisplayCompositing=\(o.prefersDisplayCompositing)")
print("maxDrawableCount=\(o.maxDrawableCount) rbColorMode=\(String(describing: o.rbColorMode))")
