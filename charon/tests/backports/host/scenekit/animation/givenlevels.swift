// givenlevels : whether SceneKit samples the mip levels of an MTLTexture it is given as a property's contents, or
// makes its own. Every level of an rgba8Unorm_srgb texture is one solid marker colour (red 10 + 28 k, green 240 - 28 k
// in level k); the gradient case's quad (constant lighting, a new material's nearest mip filter) is drawn at sizes
// where level 0, 2, 5 and 7 are read. Prints "size S level L red green", the centre pixel, and whether it is level L's
// marker: SceneKit regenerating the levels from level 0 would draw level 0's marker at every size.
import SceneKit
import AppKit
import Metal

let dev = MTLCreateSystemDefaultDevice()!
let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm_srgb, width: 256, height: 256, mipmapped: true)
d.storageMode = .managed
d.usage = .shaderRead
let texture = dev.makeTexture(descriptor: d)!
func marker(_ k: Int) -> (Int, Int) { (10 + 28 * k, 240 - 28 * k) }
for k in 0..<texture.mipmapLevelCount {
    let n = 256 >> k
    let (r, g) = marker(k)
    var bytes = [UInt8](repeating: 255, count: n * n * 4)
    for i in 0..<(n * n) { bytes[4 * i] = UInt8(r); bytes[4 * i + 1] = UInt8(g); bytes[4 * i + 2] = 0 }
    texture.replace(region: MTLRegionMake2D(0, 0, n, n), mipmapLevel: k, withBytes: bytes, bytesPerRow: n * 4)
}
let scene = SCNScene()
let cam = SCNNode(); cam.camera = SCNCamera(); cam.camera!.usesOrthographicProjection = true; cam.camera!.orthographicScale = 1; cam.position = SCNVector3(0, 0, 5); scene.rootNode.addChildNode(cam)
let plane = SCNGeometry(sources: [SCNGeometrySource(vertices: [SCNVector3(-1, -1, 0), SCNVector3(1, -1, 0), SCNVector3(1, 1, 0), SCNVector3(-1, 1, 0)]),
                                  SCNGeometrySource(textureCoordinates: [CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 1), CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 0)])],
                        elements: [SCNGeometryElement(indices: [UInt16(0), 1, 2, 0, 2, 3], primitiveType: .triangles)])
let m = SCNMaterial(); plane.materials = [m]; m.lightingModel = .constant
m.diffuse.contents = texture
scene.rootNode.addChildNode(SCNNode(geometry: plane))
let r = SCNRenderer(device: dev, options: nil); r.scene = scene; r.pointOfView = cam
var status: Int32 = 0
for (size, level) in [(256, 0), (64, 2), (8, 5), (2, 7)] {
    let rep = NSBitmapImageRep(data: r.snapshot(atTime: 0, with: CGSize(width: size, height: size), antialiasingMode: .none).tiffRepresentation!)!
    var px = [Int](repeating: 0, count: 4)
    rep.getPixel(&px, atX: size / 2, y: size / 2)
    let (wr, wg) = marker(level)
    let given = px[0] == wr && px[1] == wg
    print("size \(size) level \(level) \(px[0]) \(px[1]) \(given ? "the given level" : "not the given level (level 0 is \(marker(0)))")")
    if !given { status = 1 }
}
exit(status)
