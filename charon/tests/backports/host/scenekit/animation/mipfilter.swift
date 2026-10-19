// mipfilter : on macOS SceneKit, the mipFilter a property made alone and a new material's slots answer, and what the
// animation cases' gradient draws at the initial transforms of `gradient` and `shimmer` (and the shimmer's end) under
// each mipFilter, at 8 pixels, as scenekit-animation samples it, and at 256, where only level 0 is read. Prints "[red, green]".
import SceneKit
import AppKit
import Metal
func gradient() -> CGImage {
    var bytes = [UInt8](repeating: 255, count: 256 * 256 * 4)
    for y in 0..<256 { for x in 0..<256 { bytes[(y * 256 + x) * 4] = UInt8(x); bytes[(y * 256 + x) * 4 + 1] = UInt8(y); bytes[(y * 256 + x) * 4 + 2] = 0 } }
    let ctx = CGContext(data: &bytes, width: 256, height: 256, bitsPerComponent: 8, bytesPerRow: 1024, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    return ctx.makeImage()!
}
print("standalone property mipFilter", SCNMaterialProperty(contents: NSColor.red).mipFilter.rawValue, "new material diffuse", SCNMaterial().diffuse.mipFilter.rawValue, "emission", SCNMaterial().emission.mipFilter.rawValue)
let dev = MTLCreateSystemDefaultDevice()
func draw(_ which: String, _ mip: SCNFilterMode?, _ size: Int = 8) -> [Int] {
    let scene = SCNScene()
    let cam = SCNNode(); cam.camera = SCNCamera(); cam.camera!.usesOrthographicProjection = true; cam.camera!.orthographicScale = 1; cam.position = SCNVector3(0, 0, 5); scene.rootNode.addChildNode(cam)
    let plane = SCNGeometry(sources: [SCNGeometrySource(vertices: [SCNVector3(-1, -1, 0), SCNVector3(1, -1, 0), SCNVector3(1, 1, 0), SCNVector3(-1, 1, 0)]),
                                      SCNGeometrySource(textureCoordinates: [CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 1), CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 0)])],
                            elements: [SCNGeometryElement(indices: [UInt16(0), 1, 2, 0, 2, 3], primitiveType: .triangles)])
    let m = SCNMaterial(); plane.materials = [m]; m.lightingModel = .constant
    let p: SCNMaterialProperty
    if which == "gradient" { m.diffuse.contents = gradient(); m.diffuse.wrapS = .repeat; m.diffuse.wrapT = .repeat; m.diffuse.contentsTransform = SCNMatrix4MakeTranslation(0.24, -0.24, 0); p = m.diffuse }
    else {
        m.diffuse.contents = NSColor.black; m.emission.contents = gradient(); m.emission.wrapS = .clamp; m.emission.wrapT = .clampToBorder
        var t = SCNMatrix4Translate(SCNMatrix4MakeScale(0.5, 0.5, 1), 1, 0.15, 0)
        if which == "shimmer-end" { t = SCNMatrix4Translate(t, -1.6, 0, 0) }
        m.emission.contentsTransform = t; p = m.emission
    }
    if let mip = mip { p.mipFilter = mip }
    scene.rootNode.addChildNode(SCNNode(geometry: plane))
    let r = SCNRenderer(device: dev, options: nil); r.scene = scene; r.pointOfView = cam
    let rep = NSBitmapImageRep(data: r.snapshot(atTime: 0, with: CGSize(width: size, height: size), antialiasingMode: .none).tiffRepresentation!)!
    var px = [Int](repeating: 0, count: 4); rep.getPixel(&px, atX: size / 2, y: size / 2); return Array(px[0..<2])
}
for which in ["gradient", "shimmer", "shimmer-end"] {
    print(which, "default", draw(which, nil), "none", draw(which, SCNFilterMode.none), "nearest", draw(which, .nearest), "linear", draw(which, .linear), "| at 256 px: default", draw(which, nil, 256), "none", draw(which, SCNFilterMode.none, 256))
}
