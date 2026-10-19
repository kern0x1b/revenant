// The probe for the pixel cast: a guest program that asks the port's Scene what a cast hits and
// prints the answer, so a run in the emulator shows the numbers rather than only a verdict.
//
// It is a *program* and not a device test, because `Scene.pixelCast` is a RealityFoundation member
// of the swift-runtime overlay: an Objective-C device test cannot reach it, and the Swift side is
// what this series changed. The projection beside it - scenekitprojection.m - is the device test,
// because `projectPoint:` is the backports' own and is checked against macOS there.
//
// The geometry is the one the cast is checked against: a scene with one box at the origin, a camera
// at (0, 0, 10) looking down -z, and a cast from the camera's own axis through the box. The answer
// has to name that box and to place it where the box is, and a cast from a point off the axis to a
// place the box is not has to answer nothing.
//
// Nothing here decides pass or fail. It prints, and the reading is the reader's: a run that says the
// cast found the box at the origin has proved the round trip Scene -> SCNView.projectPoint ->
// hitTest -> SCNNode.entity(in:), and a run that says nil has proved which of those four did not
// answer. That is the point of a probe rather than a check on a machine that cannot build the code.

import Foundation
import simd

#if canImport(RealityFoundation)
import RealityFoundation
import RealityKit
#endif

func spell(_ v: SIMD3<Float>) -> String {
    "(\(v.x), \(v.y), \(v.z))"
}

#if canImport(RealityFoundation)

@MainActor
func run() async {
    // The scene, the camera and the box, the same ones the projection case records.
    let scene = Scene()
    let anchor = AnchorEntity(world: .zero)
    scene.addAnchor(anchor)

    let box = MeshResource.generateBox(size: 1)
    let model = ModelComponent(mesh: box, materials: [SimpleMaterial(color: .init(white: 0.5, alpha: 1), isMetallic: false)])
    let entity = Entity()
    entity.name = "box"
    entity.position = SIM3<Float>(0, 0, 0)
    entity.components.set(model)
    anchor.addChild(entity)

    // A view, because a scene with no view has no camera to project through and answers nil - which
    // is itself the first thing to print.
    print("a scene with no view: \(String(describing: await scene.pixelCast(from: SIMD3<Float>(0, 0, 0), to: SIMD3<Float>(0, 0, -1))))")
    let view = ARView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
    scene.view = view.scnView
    // One frame, so the renderer has a projection: a view that has not rendered answers a point
    // unchanged, which lands nowhere.
    view.render()

    // Straight down the camera's own axis, through the box at the origin.
    let through = await scene.pixelCast(from: SIMD3<Float>(0, 0, 0), to: SIMD3<Float>(0, 0, -1))
    if let hit = through {
        print("through the box: hit \(hit.entity.name) at \(spell(hit.position)) normal \(spell(hit.normal)) part \(hit.meshPart)")
    } else {
        print("through the box: nothing")
    }

    // Off the axis, at nothing: the answer has to be nothing, or the cast is hitting everything.
    let beside = await scene.pixelCast(origin: SIMD3<Float>(0, 0, 0), direction: SIMD3<Float>(1, 0, 0), length: 4)
    print("beside the box: \(beside.map { "hit " + $0.entity.name } ?? "nothing")")

    // And the two views, to see which one is answering.
    print("the view: \(view.scnView.bounds.size), content scale \(view.scnView.contentScaleFactor)")
    print("probe: done")
}

MainActor.assumeIsolated {
    Task { await run() }
    // The guest is a command-line program: keep it alive until the task above has printed.
    RunLoop.main.run(until: Date().addingTimeInterval(10))
}
#else
print("probe: this build has no RealityFoundation, so there is nothing to ask")
#endif
