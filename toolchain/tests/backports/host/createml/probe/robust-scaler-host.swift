import CreateMLComponents

func medianByHand(_ data: [Double]) -> Double {
    let sorted = data.sorted { $0 < $1 }
    let n = sorted.count
    return n % 2 == 1 ? sorted[n / 2] : (sorted[n / 2 - 1] + sorted[n / 2]) / 2
}

func report(_ name: String, _ data: [Double], _ q: ClosedRange<Double>) {
    do {
        let t = try RobustScaler<Double>(quantileRange: q).fitted(to: data)
        let width = q.upperBound - q.lowerBound
        print("--- \(name)  n=\(data.count)  quantileRange=\(q)  width=\(width)")
        print("    median=\(t.median)  interQuartileRange=\(t.interQuartileRange)  (IQR == width: \(t.interQuartileRange == width))")
        let hand = medianByHand(data.compactMap { $0.isFinite ? $0 : nil })
        print("    median by hand=\(hand)  match: \(t.median == hand)")
        let finite = data.compactMap { $0 }
        let probes: [Double] = [finite.min() ?? 0, t.median, finite.max() ?? 0]
        for x in probes {
            let deviation = t.median.isFinite ? x - t.median : x
            let scaled = t.interQuartileRange.isFinite && t.interQuartileRange != 0
                ? deviation / t.interQuartileRange : deviation
            let holds = t.applied(to: x) == scaled || (t.applied(to: x).isNaN && scaled.isNaN)
            print("    applied(\(x))=\(t.applied(to: x))  deviation-if-finite-then-scaled=\(scaled)  holds: \(holds)")
        }
    } catch {
        print("--- \(name)  quantileRange=\(q)  THREW: \(error)")
    }
}

report("five integers", [1, 2, 3, 4, 100], 0.25...0.75)
report("five integers, 0.1...0.9", [1, 2, 3, 4, 100], 0.1...0.9)
report("five integers, 0.0...1.0", [1, 2, 3, 4, 100], 0.0...1.0)
report("even, four", [1, 2, 3, 4], 0.25...0.75)
report("even, four, non-integer", [1.5, 2.5, 3.5, 4.5], 0.25...0.75)

report("constant column", [7, 7, 7, 7], 0.25...0.75)

var skewed: [Double] = []
for i in 0..<200 { skewed.append(Double(i) * 0.37 + 1.0) }
skewed[199] = 10_000.5
report("200 skewed non-integer", skewed, 0.25...0.75)

report("zero width 0.5...0.5", [1, 2, 3, 4, 100], 0.5...0.5)
report("data with NaN", [1.0, 2.0, Double.nan, 4.0], 0.25...0.75)
report("all NaN", [Double.nan, Double.nan, Double.nan], 0.25...0.75)

report("infinite width 0.0...inf", [1, 2, 3], 0.0...Double.infinity)
