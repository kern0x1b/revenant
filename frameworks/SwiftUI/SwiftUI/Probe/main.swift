@_spi(Probe) import SwiftUI
import UIKit
import Foundation

final class Model: ObservableObject {
    @Published var count = 0
    @Published var wide = false
    @Published var items = [1, 2]
}

struct Bar: View {
    let index: Int
    let wide: Bool

    var body: some View {
        HStack(spacing: 4) {
            Color.blue.frame(width: wide ? 120 : 40, height: 12)
            Spacer()
            Color.red.frame(width: CGFloat(8 * index), height: 12)
        }
    }
}

struct ProbeView: View {
    @ObservedObject var model: Model

    var body: some View {
        VStack(spacing: 6) {
            Color.green.frame(height: CGFloat(10 + model.count % 20))
            ForEach(model.items, id: \.self) { item in
                Bar(index: item, wide: model.wide)
            }
            if model.wide {
                Color.orange.frame(height: 20)
            }
            Spacer()
        }
        .padding(8)
    }
}

setvbuf(stdout, nil, _IONBF, 0)
let useText = ProcessInfo.processInfo.arguments.contains("--text")
let depths: [Int] = {
    let arguments = ProcessInfo.processInfo.arguments
    guard let at = arguments.firstIndex(of: "--depths"), at + 1 < arguments.count else { return [2, 3, 4] }
    return arguments[at + 1].split(separator: ",").compactMap { Int($0) }
}()
let model = Model()
let probe = _Probe(ProbeView(model: model), width: 320, height: 460)
print("== initial")
print(probe.dump())

model.count = 7
model.wide = true
model.items.append(3)
probe.flush()
print("== after state change")
print(probe.dump())
print("body evaluations: \(probe.bodyEvaluations)")

var worst = 0.0
let iterations = 200
let start = Date()
for i in 0..<iterations {
    let t0 = Date()
    model.count = i
    probe.flush()
    worst = max(worst, Date().timeIntervalSince(t0))
}
let total = Date().timeIntervalSince(start)
print(String(format: "update loop: %d updates in %.3f s, %.2f ms average, %.2f ms worst", iterations, total, total / Double(iterations) * 1000, worst * 1000))
let buildStart = Date()
for _ in 0..<20 { _ = _Probe(ProbeView(model: model), width: 320, height: 460) }
print(String(format: "build+layout of the screen: %.1f ms average", Date().timeIntervalSince(buildStart) / 20 * 1000))

final class DeepModel: ObservableObject {
    @Published var tick = 0
}

struct Nest: View {
    let depth: Int
    let tick: Int
    let text: Bool
    var body: some View {
        if depth == 0 {
            if text { Text("leaf \(tick % 10)") } else { Color.red.frame(width: CGFloat(10 + tick % 10), height: 8) }
        } else {
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    Color.blue.frame(width: 6, height: 6)
                    Nest(depth: depth - 1, tick: tick, text: text)
                    Color.green.frame(width: 6)
                }
                Color.gray.frame(height: 2)
            }
            .padding(1)
        }
    }
}

struct DeepView: View {
    @ObservedObject var model: DeepModel
    let depth: Int
    let text: Bool
    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<6) { row in Nest(depth: depth, tick: row == 0 || !onlyFirstRow ? model.tick + row : row, text: text) }
        }
    }
}

nonisolated(unsafe) var onlyFirstRow = false

func deepRun(_ depth: Int, text: Bool) {
    let deepModel = DeepModel()
    let buildStart = Date()
    let deep = _Probe(DeepView(model: deepModel, depth: depth, text: text), width: 320, height: 460)
    let build = Date().timeIntervalSince(buildStart)
    var worst = 0.0
    let loops = 30
    let before = _Probe.measurements
    let phasesBefore = _Probe.phaseSeconds
    let start = Date()
    for i in 0..<loops {
        let t0 = Date()
        deepModel.tick = i + 1
        deep.flush()
        worst = max(worst, Date().timeIntervalSince(t0))
    }
    let total = Date().timeIntervalSince(start)
    let after = _Probe.measurements
    let phases = _Probe.phaseSeconds
    print(String(format: "  phases per update: render %.2f ms, mount %.2f ms, layout %.2f ms",
                 (phases.render - phasesBefore.render) / Double(loops) * 1000, (phases.mount - phasesBefore.mount) / Double(loops) * 1000,
                 (phases.layout - phasesBefore.layout) / Double(loops) * 1000))
    print(String(format: "deep %@%@ depth %d: build+layout %.1f ms, update %.2f ms average, %.2f ms worst, %d sizes computed and %d cached per update",
                 text ? "text" : "color", onlyFirstRow ? " one-row" : "", depth, build * 1000, total / Double(loops) * 1000, worst * 1000,
                 (after.computed - before.computed) / loops, (after.cached - before.cached) / loops))
}
for depth in depths { deepRun(depth, text: false) }
onlyFirstRow = true
for depth in depths { deepRun(depth, text: false) }
onlyFirstRow = false
if useText { for depth in depths { deepRun(depth, text: true) } }

if useText {
    print("== text scenario (needs the font server)")
    let text = _Probe(VStack { Text("Hello"); Text("World") }, width: 320, height: 460)
    print(text.dump())
}
print("ok")
