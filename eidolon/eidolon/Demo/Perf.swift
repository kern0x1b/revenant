@_spi(Probe) import SwiftUI
import UIKit

final class PerfModel: ObservableObject {
    @Published var tick = 0
}

struct PerfNest: View {
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
                    PerfNest(depth: depth - 1, tick: tick, text: text)
                    Color.green.frame(width: 6)
                }
                if text { Text("level \(depth)").font(.caption) } else { Color.gray.frame(height: 2) }
            }
            .padding(1)
        }
    }
}

struct PerfScreen: View {
    @ObservedObject var model: PerfModel
    let depth: Int
    let text: Bool
    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<6) { row in PerfNest(depth: depth, tick: model.tick + row, text: text) }
        }
    }
}

func runPerf() {
    for text in [false, true] {
        for depth in 1...5 {
            let model = PerfModel()
            let buildStart = Date()
            let probe = _Probe(PerfScreen(model: model, depth: depth, text: text), width: 320, height: 460)
            let build = Date().timeIntervalSince(buildStart)
            let loops = 20
            let before = _Probe.measurements
            var worst = 0.0
            let start = Date()
            for i in 0..<loops {
                let t0 = Date()
                model.tick = i + 1
                probe.flush()
                worst = max(worst, Date().timeIntervalSince(t0))
            }
            let total = Date().timeIntervalSince(start)
            let after = _Probe.measurements
            logProbe(String(format: "perf %@ depth %d: build+layout %.1f ms, update %.2f ms average, %.2f ms worst, %d sizes computed and %d cached per update",
                            text ? "text" : "color", depth, build * 1000, total / Double(loops) * 1000, worst * 1000,
                            (after.computed - before.computed) / loops, (after.cached - before.cached) / loops))
        }
    }
    logProbe("perf done")
}
