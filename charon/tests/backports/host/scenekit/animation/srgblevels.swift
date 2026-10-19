// The mip levels of an opaque sRGB image by the rule Metal's blit generateMipmaps follows for an rgba8Unorm_srgb
// texture on macOS (facts/SceneKit/SCNView.md, "Textures"): every level is made from the level before it as that is
// stored, 8-bit sRGB. A texel of level n + 1 is the mean, in linear light, of its 2x2 texels of level n, stored as the
// byte whose interval [b - 0.5, b + 0.5) / 255 of the encoding holds it (half up). The oracle's own copy of the rule,
// taken from Metal's level bytes, not from the port; all in doubles, the mean summed row by row.
import Metal

func srgbLinear(_ e: Double) -> Double { e <= 0.04045 ? e / 12.92 : pow((e + 0.055) / 1.055, 2.4) }

// srgbBounds[b] is the linear value from which the byte b holds a mean, the decoding of (b - 0.5) / 255
let srgbBounds: [Double] = (0..<256).map { $0 == 0 ? -Double.infinity : srgbLinear((Double($0) - 0.5) / 255) }

func srgbByte(_ linear: Double) -> UInt8 {
    var low = 0, high = 255
    while low < high { let mid = (low + high + 1) / 2; if srgbBounds[mid] <= linear { low = mid } else { high = mid - 1 } }
    return UInt8(low)
}

// every level of a square RGBA image of side 2^k, level 0 first; alpha is 255 throughout
func srgbLevels(_ image: [UInt8], side: Int) -> [[UInt8]] {
    var levels = [image], n = side
    while n > 1 {
        let above = levels.last!, m = n / 2
        var level = [UInt8](repeating: 255, count: m * m * 4)
        for y in 0..<m { for x in 0..<m { for k in 0..<3 {
            var sum = 0.0
            for j in 0..<2 { for i in 0..<2 { sum += srgbLinear(Double(above[((2 * y + j) * n + 2 * x + i) * 4 + k]) / 255) } }
            level[(y * m + x) * 4 + k] = srgbByte(sum / 4)
        } } }
        levels.append(level); n = m
    }
    return levels
}

// an rgba8Unorm_srgb texture holding exactly these levels; SceneKit samples a given texture's levels only under
// mipFilter linear, and reads level 0 alone under nearest (host/scenekit/animation/givenlevels.swift)
func srgbTexture(_ device: MTLDevice, _ levels: [[UInt8]], side: Int) -> MTLTexture {
    let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm_srgb, width: side, height: side, mipmapped: true)
    d.storageMode = .shared
    let t = device.makeTexture(descriptor: d)!
    for (k, level) in levels.enumerated() {
        let n = side >> k
        t.replace(region: MTLRegionMake2D(0, 0, n, n), mipmapLevel: k, withBytes: level, bytesPerRow: n * 4)
    }
    return t
}
