import SceneKit
import AppKit
import Metal
let dev = MTLCreateSystemDefaultDevice()!
var metalLevels: MTLTexture?
var bytes = [UInt8](repeating: 255, count: 256 * 256 * 4)
for y in 0..<256 { for x in 0..<256 { bytes[(y * 256 + x) * 4] = UInt8(x); bytes[(y * 256 + x) * 4 + 1] = UInt8(y); bytes[(y * 256 + x) * 4 + 2] = 0 } }
for (name, format) in [("srgb", MTLPixelFormat.rgba8Unorm_srgb), ("unorm", .rgba8Unorm)] {
    let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: 256, height: 256, mipmapped: true)
    d.storageMode = .managed
    let t = dev.makeTexture(descriptor: d)!
    t.replace(region: MTLRegionMake2D(0, 0, 256, 256), mipmapLevel: 0, withBytes: bytes, bytesPerRow: 1024)
    let q = dev.makeCommandQueue()!, cb = q.makeCommandBuffer()!, blit = cb.makeBlitCommandEncoder()!
    blit.generateMipmaps(for: t); blit.synchronize(resource: t); blit.endEncoding(); cb.commit(); cb.waitUntilCompleted()
    for l in 1...8 {
        let n = 256 >> l
        var row = [UInt8](repeating: 0, count: n * 4)
        t.getBytes(&row, bytesPerRow: n * 4, from: MTLRegionMake2D(0, 0, n, 1), mipmapLevel: l)
        print("metal", name, "level", l, (0..<n).map { row[$0 * 4] })
    }
    if format == .rgba8Unorm_srgb { metalLevels = t }
}
let ruleLevels = srgbLevels(bytes, side: 256)
for l in 1...8 { print("rule level", l, (0..<(256 >> l)).map { ruleLevels[l][$0 * 4] }) }
let img = CGContext(data: &bytes, width: 256, height: 256, bitsPerComponent: 8, bytesPerRow: 1024, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
let scene = SCNScene()
let cam = SCNNode(); cam.camera = SCNCamera(); cam.camera!.usesOrthographicProjection = true; cam.camera!.orthographicScale = 1; cam.position = SCNVector3(0, 0, 5); scene.rootNode.addChildNode(cam)
let plane = SCNGeometry(sources: [SCNGeometrySource(vertices: [SCNVector3(-1, -1, 0), SCNVector3(1, -1, 0), SCNVector3(1, 1, 0), SCNVector3(-1, 1, 0)]),
                                  SCNGeometrySource(textureCoordinates: [CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 1), CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 0)])],
                        elements: [SCNGeometryElement(indices: [UInt16(0), 1, 2, 0, 2, 3], primitiveType: .triangles)])
let m = SCNMaterial(); plane.materials = [m]; m.lightingModel = .constant
m.diffuse.contents = img; m.diffuse.wrapS = .repeat; m.diffuse.wrapT = .repeat
scene.rootNode.addChildNode(SCNNode(geometry: plane))
let r = SCNRenderer(device: dev, options: nil); r.scene = scene; r.pointOfView = cam
for (label, contents, filter) in [("scn", img as Any, SCNFilterMode.nearest), ("given-metal", metalLevels!, .linear),
                                  ("given-rule", srgbTexture(dev, ruleLevels, side: 256), .linear)] {
    m.diffuse.contents = contents; m.diffuse.mipFilter = filter
    for (tx, ty) in [(0.24, -0.24), (0.1, -0.1), (0.0, 0.0), (0.013, 0.37), (-0.11, 0.0)] {
        m.diffuse.contentsTransform = SCNMatrix4MakeTranslation(CGFloat(tx), CGFloat(ty), 0)
        let rep = NSBitmapImageRep(data: r.snapshot(atTime: 0, with: CGSize(width: 8, height: 8), antialiasingMode: .none).tiffRepresentation!)!
        for y in 0..<8 { for x in 0..<8 { var px = [Int](repeating: 0, count: 4); rep.getPixel(&px, atX: x, y: y); print(label, tx, ty, x, y, px[0], px[1]) } }
    }
}
