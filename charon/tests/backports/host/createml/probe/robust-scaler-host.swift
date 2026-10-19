// The host program that produced every number the robust-scaler check in
// `../transformers/main.swift` quotes. Kept in the tree beside the check so the oracle is re-runnable
// rather than a transcript, and so a reader can see what was asked and not only what was answered.
//
//     xcrun swiftc -O -o robust-scaler-host robust-scaler-host.swift && ./robust-scaler-host
//
// It asks the host's own `RobustScaler` - Apple's, from the macOS SDK - the questions the check pins:
// the scale for a quantile range whose width varies, the median for even and odd counts, what happens
// at a zero width, and what a non-finite median does. Nothing here is transcribed from Apple's source;
// every value printed is read out of the running framework.
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

// The scale is the quantile range's width, over three widths and datasets with different shapes.
report("five integers", [1, 2, 3, 4, 100], 0.25...0.75)
report("five integers, 0.1...0.9", [1, 2, 3, 4, 100], 0.1...0.9)
report("five integers, 0.0...1.0", [1, 2, 3, 4, 100], 0.0...1.0)
report("even, four", [1, 2, 3, 4], 0.25...0.75)
report("even, four, non-integer", [1.5, 2.5, 3.5, 4.5], 0.25...0.75)

// A constant column: a statistic of the data would be 0 here, and the host's scale is not 0.
report("constant column", [7, 7, 7, 7], 0.25...0.75)

// 200 skewed non-integer values, even count.
var skewed: [Double] = []
for i in 0..<200 { skewed.append(Double(i) * 0.37 + 1.0) }
skewed[199] = 10_000.5
report("200 skewed non-integer", skewed, 0.25...0.75)

// A zero width leaves the deviation unscaled, and a non-finite median is not subtracted.
report("zero width 0.5...0.5", [1, 2, 3, 4, 100], 0.5...0.5)
report("data with NaN", [1.0, 2.0, Double.nan, 4.0], 0.25...0.75)
report("all NaN", [Double.nan, Double.nan, Double.nan], 0.25...0.75)

// Infinite bounds are accepted, and the scale is infinite - the same unscaled answer as a zero width.
report("infinite width 0.0...inf", [1, 2, 3], 0.0...Double.infinity)
