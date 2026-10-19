// retargetcmp.swift: what a value does when it is told to go somewhere else while it is on its way, Apple's against the port's
// `Passage` (Flights.swift), on the host. Apple's is a Shape in an NSHostingView in a window that is not shown, that records the data
// it is drawn with and when; the port's is asked for the number at the moment of each record. It needs a window server, so it runs from
// a login session, and the moments are the ones the run loop gives, so the numbers are compared as the value at any moment within a few
// thousandths of a second of the record, as the staircase of a fluid spring is a jump a thousandth of a second makes.
//   d=$(mktemp -d); (echo "import SwiftUI"; cat ../Sources/SwiftUI/Springs.swift) > $d/Springs.swift
//   (echo "import SwiftUI"; cat ../Sources/SwiftUI/Flights.swift) > $d/Flights.swift
//   cp retargetcmp.swift $d/main.swift && swiftc -O $d/main.swift $d/Springs.swift $d/Flights.swift -o $d/retargetcmp && $d/retargetcmp
// It prints `DIFF` for every scenario that is not within the tolerance, the worst difference of each group and a last line with the
// count. The scenarios not here are the ones it could not ask consistently: a fluid spring that is delayed or sped up, told to go
// somewhere else (see the comment in Flights.swift).
import SwiftUI
import AppKit

nonisolated(unsafe) var drawn: [(Double, Double)] = []
struct Recorded: Shape {
    var value: Double
    var animatableData: Double { get { value } set { value = newValue } }
    func path(in rect: CGRect) -> Path { drawn.append((CACurrentMediaTime(), value)); return Path(rect) }
}
final class Model: ObservableObject { @Published var value = 0.0 }
struct Scene: View {
    @ObservedObject var model: Model
    var body: some View { Recorded(value: model.value).frame(width: 100, height: 100) }
}
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let model = Model()
let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100), styleMask: [.borderless], backing: .buffered, defer: false)
window.contentView = NSHostingView(rootView: Scene(model: model))
window.orderFrontRegardless()
func spin(_ seconds: Double) { RunLoop.main.run(until: Date().addingTimeInterval(seconds)) }
spin(0.3)
setvbuf(stdout, nil, _IOLBF, 0)

/// An animation, as Apple's and as the port's pace.
struct Motion {
    let name: String
    /// The Swift that makes the animation, which the numbers pasted into Tests/main.swift are written with.
    let source: String
    let apple: Animation?
    let base: ((Double) -> BaseTrack)?
    let spring: Spring?
    let retiming: Retiming

    static func curve(_ name: String, _ source: String, _ apple: Animation, length: Double, unit: UnitCurve) -> Motion {
        Motion(name: name, source: source, apple: apple, base: { _ in .lasting(length) { unit.value(at: $0) } }, spring: nil, retiming: Retiming())
    }
    static func fluid(_ name: String, response: Double, fraction: Double) -> Motion {
        let spring = Spring(response: response, dampingRatio: fraction)
        return Motion(name: name, source: ".spring(response: \(response), dampingFraction: \(fraction))", apple: .spring(response: response, dampingFraction: fraction), base: { .fluid(spring, distance: $0) }, spring: spring, retiming: Retiming())
    }
    static func held(_ name: String, mass: Double, stiffness: Double, damping: Double) -> Motion {
        let held = InterpolatingSpring(mass: mass, stiffness: stiffness, damping: damping)
        return Motion(name: name, source: ".interpolatingSpring(mass: \(mass), stiffness: \(stiffness), damping: \(damping))", apple: .interpolatingSpring(mass: mass, stiffness: stiffness, damping: damping), base: { _ in .interpolating(held) }, spring: nil, retiming: Retiming())
    }
    static let none = Motion(name: "none", source: "nil", apple: nil, base: nil, spring: nil, retiming: Retiming())

    func delayed(_ seconds: Double) -> Motion { Motion(name: name + " delay \(seconds)", source: source + ".delay(\(seconds))", apple: apple?.delay(seconds), base: base, spring: spring, retiming: retiming.delaying(by: seconds)) }
    func sped(_ rate: Double) -> Motion { Motion(name: name + " speed \(rate)", source: source + ".speed(\(rate))", apple: apple?.speed(rate), base: base, spring: spring, retiming: retiming.speeding(by: rate)) }
    func repeated(_ count: Int, reverses: Bool) -> Motion {
        Motion(name: name + " repeat \(count)", source: source + ".repeatCount(\(count), autoreverses: \(reverses))", apple: apple?.repeatCount(count, autoreverses: reverses), base: base, spring: spring, retiming: retiming.repeating(count: Double(count), reverses: reverses))
    }

    var pace: Pace? {
        guard let base else { return nil }
        let retiming = retiming
        return Pace(retiming: retiming, spring: spring, course: { AnimationCourse(base($0), retiming: retiming) })
    }
}

let linear = Motion.curve("linear", ".linear(duration: 1)", .linear(duration: 1), length: 1, unit: .linear)
let easeInOut = Motion.curve("easeInOut", ".easeInOut(duration: 1)", .easeInOut(duration: 1), length: 1, unit: .easeInOut)
let easeIn = Motion.curve("easeIn", ".easeIn(duration: 0.6)", .easeIn(duration: 0.6), length: 0.6, unit: .easeIn)
let easeOut = Motion.curve("easeOut", ".easeOut(duration: 1.4)", .easeOut(duration: 1.4), length: 1.4, unit: .easeOut)
let loose = Motion.fluid("spring .5", response: 1.0, fraction: 0.5)
let tight = Motion.fluid("spring crit", response: 0.3, fraction: 1.0)
let bouncy = Motion.fluid("bouncy", response: 0.5, fraction: 0.7)
let smooth = Motion.fluid("smooth", response: 0.5, fraction: 1.0)
let held = Motion.held("interpolating", mass: 1, stiffness: 100, damping: 8)

/// Where Apple's value was at the moments after the first animation began, when each of the animations was begun, from nothing to
/// the places: `steps` are (animation, seconds after the first, place).
func appleSeries(_ steps: [(Motion, Double, Double)], until: Double) -> (moments: [(Double, Double)], begun: [Double]) {
    model.value = 0
    spin(0.3)
    drawn = []
    let origin = CACurrentMediaTime()
    var next = 0
    var begun: [Double] = []
    while CACurrentMediaTime() - origin < until {
        spin(0.001)
        let now = CACurrentMediaTime() - origin
        if next < steps.count, now >= steps[next].1 {
            withAnimation(steps[next].0.apple) { model.value = steps[next].2 }
            begun.append(CACurrentMediaTime() - origin)
            next += 1
        }
    }
    return (drawn.map { ($0.0 - origin, $0.1) }, begun)
}

/// Where the port's passage is, for the same animations begun at the same moments.
func port(_ steps: [(Motion, Double, Double)], begun: [Double]) -> Passage<Double> {
    var passage = Passage<Double>(end: 0)
    for (index, step) in steps.enumerated() {
        passage = Passage.redirecting(passage, to: step.2, pace: step.0.pace, now: begun[index])
    }
    return passage
}

/// How far from the moment of a record the port's number may be taken at, in seconds.
let timingWindow = 0.003
var scenarios = 0
var differing = 0
var worstOverall = 0.0
var groupWorst: [String: Double] = [:]
var retried = 0
/// Runs one scenario, and prints it if no moment of Apple's series is within a tolerance of the port's at any moment within a window of it
/// (three thousandths of a second). The moments are the run loop's, and a loaded machine delays them by more than the window now and then, so
/// a scenario that differs is run again, twice at most, and is reported only if it differs every time. The tolerance, a fortieth of the distance, is
/// two thousandths of a second of a spring at its fastest (ten distances a second), the most the moments of a frame are out by.
func compare(_ group: String, _ steps: [(Motion, Double, Double)], until: Double = 2.6, tolerance: Double = 0.025) {
    var best = (worst: Double.infinity, at: 0.0, checked: 0)
    for attempt in 0..<3 {
        let (moments, begun) = appleSeries(steps, until: until)
        guard begun.count == steps.count else { print("DIFF", group, "a step was not begun"); return }
        let passage = port(steps, begun: begun)
        let last = begun[begun.count - 1]
        var worst = 0.0, at = 0.0
        var checked = 0
        for (time, value) in moments where time > last + 0.002 {
            var nearest = Double.infinity
            var offset = -timingWindow
            while offset <= timingWindow + 0.00001 {
                nearest = min(nearest, abs(passage.data(at: time + offset) - value))
                offset += 0.00025
            }
            checked += 1
            if nearest > worst { worst = nearest; at = time }
        }
        if worst < best.worst || checked == 0 { best = (worst, at, checked) }
        if checked > 0 && worst <= tolerance { if attempt > 0 { retried += 1 }; break }
    }
    scenarios += 1
    worstOverall = max(worstOverall, best.worst)
    groupWorst[group] = max(groupWorst[group] ?? 0, best.worst)
    if best.worst > tolerance || best.checked == 0 {
        differing += 1
        let names = steps.map { "\($0.0.name) @\(String(format: "%.2f", $0.1)) to \($0.2)" }.joined(separator: ", ")
        print("DIFF", group, names, "worst", String(format: "%.4f", best.worst), "at", String(format: "%.3f", best.at), "of", best.checked)
    }
}

/// `retargetcmp pins`: the numbers for Tests/main.swift instead of the comparison: for each scenario the width of a bar (a hundred times the
/// value) at moments after the second animation began, as the engine test asks them, with the moment it began at.
func pin(_ steps: [(Motion, Double, Double)], after: [Double] = [0.1, 0.3, 0.6, 1.0, 2.0]) {
    let (moments, begun) = appleSeries(steps, until: 3.5)
    let moment = begun[begun.count - 1]
    var rows: [String] = []
    for delta in after {
        let time = ((moment + delta) * 100).rounded() / 100
        guard let drawnThen = moments.last(where: { $0.0 <= time }) else { continue }
        rows.append("(\(String(format: "%.2f", time)), \(String(format: "%.3f", drawnThen.1 * 100)))")
    }
    let (first, second) = (steps[0].0, steps[steps.count - 1].0)
    print("retargetBar(\(first.source), \(second.source), at: \(String(format: "%.4f", moment)), to: \(steps[steps.count - 1].2), [\(rows.joined(separator: ", "))], \"\(first.name) told to go to \(steps[steps.count - 1].2) by \(second.name)\")")
}
if CommandLine.arguments.dropFirst().first == "pins" {
    for (first, second, place) in [(linear, linear, 3.0), (easeInOut, easeIn, 0.0), (easeOut, held, 3.0), (linear, loose, 3.0), (held, bouncy, 0.0), (loose, loose, 3.0), (loose, tight, 0.0),
                                   (bouncy, smooth, 3.0), (tight, bouncy, 3.0), (loose, linear, 0.0), (bouncy, held, 3.0), (linear, linear.delayed(0.5), 3.0), (linear, linear.sped(2), 3.0),
                                   (linear.delayed(0.5), linear, 3.0), (linear.sped(2), linear, 3.0), (linear, linear.repeated(2, reverses: true), 3.0), (linear.repeated(2, reverses: true), linear, 3.0),
                                   (loose.sped(2), loose, 3.0), (loose.delayed(0.2), loose, 3.0), (loose.sped(0.5), loose, 3.0), (loose, Motion.none, 3.0), (linear, Motion.none, 3.0), (held, Motion.none, 3.0)] {
        pin([(first, 0, 1), (second, 0.3, place)])
    }
    pin([(loose, 0, 1), (linear, 0.2, 3), (bouncy, 0.5, -1)])
    pin([(linear, 0, 1), (Motion.none, 0.2, 3), (loose, 0.4, 0)])
    pin([(linear, 0, 1), (bouncy, 0.3, 1)], after: [0.1, 0.3, 0.6])
    exit(0)
}

// two animations, the second begun 0.3 s into the first, to nothing and to three
for first in [linear, easeInOut, easeOut, loose, bouncy, held] {
    for second in [linear, easeIn, loose, tight, smooth, held] {
        for place in [0.0, 3.0] { compare("two animations", [(first, 0, 1), (second, 0.3, place)]) }
    }
}
// at other moments of the first, before it is over and after
for first in [linear, loose, held] {
    for second in [linear, loose, held] {
        for moment in [0.1, 0.6, 1.5] { compare("another moment", [(first, 0, 1), (second, moment, 2)]) }
    }
}
// an animation that is retimed or repeated, as the first and as the second, over one that is not, but for a fluid spring that is retimed
// as the second, whose way from the first no rule here gives
for retimed in [linear.delayed(0.5), linear.sped(2), easeInOut.delayed(0.2).sped(2), linear.repeated(2, reverses: true), held.delayed(0.3)] {
    compare("retimed second", [(linear, 0, 1), (retimed, 0.3, 3)])
    compare("retimed second", [(loose, 0, 1), (retimed, 0.3, 3)])
    compare("retimed first", [(retimed, 0, 1), (linear, 0.3, 3)], until: 4.2)
}
for retimed in [loose.delayed(0.2), loose.sped(2), loose.sped(0.5), loose.delayed(0.2).sped(2)] {
    for second in [loose, tight, bouncy, linear] { compare("retimed first", [(retimed, 0.0, 1), (second, 0.3, 3)], until: 4.2) }
}
// a third one, told while the second is on its way
for second in [linear, loose, held] {
    for third in [linear, loose, bouncy, held] { compare("three animations", [(loose, 0, 1), (second, 0.2, 3), (third, 0.5, -1)], until: 4.2) }
}
for second in [linear, bouncy] { compare("three animations", [(linear, 0, 1), (second, 0.2, 3), (second, 0.5, -1)], until: 4.2) }
// no animation: what is going on goes on to where it was going, shifted by how far the new place is from it
for first in [linear, easeInOut, loose, bouncy, held] {
    compare("no animation", [(first, 0, 1), (Motion.none, 0.3, 3)])
    compare("no animation then one", [(first, 0, 1), (Motion.none, 0.2, 3), (loose, 0.4, 0)], until: 4.2)
    compare("no animation then one", [(first, 0, 1), (Motion.none, 0.2, 3), (linear, 0.4, 0)], until: 4.2)
}
// told to go where it is going: nothing changes
for first in [linear, loose] { compare("the same place", [(first, 0, 1), (easeIn, 0.3, 1)]) }

print("compared", scenarios, "scenarios, differing", differing, ", run again", retried, "; worst difference", String(format: "%.4f", worstOverall))
for (group, worst) in groupWorst.sorted(by: { $0.key < $1.key }) { print("  ", group, String(format: "%.4f", worst)) }
