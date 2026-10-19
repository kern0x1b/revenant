import UIKit
import CoreGraphics

extension Path {
    public enum Element: Equatable {
        case move(to: CGPoint)
        case line(to: CGPoint)
        case quadCurve(to: CGPoint, control: CGPoint)
        case curve(to: CGPoint, control1: CGPoint, control2: CGPoint)
        case closeSubpath
    }

    private final class ElementCollector {
        var elements: [Element] = []
    }

    var elements: [Element] {
        let collector = ElementCollector()
        storage.apply(info: Unmanaged.passUnretained(collector).toOpaque()) { info, pointer in
            let collector = Unmanaged<ElementCollector>.fromOpaque(info!).takeUnretainedValue()
            let element = pointer.pointee
            switch element.type {
            case .moveToPoint: collector.elements.append(.move(to: element.points[0]))
            case .addLineToPoint: collector.elements.append(.line(to: element.points[0]))
            case .addQuadCurveToPoint: collector.elements.append(.quadCurve(to: element.points[1], control: element.points[0]))
            case .addCurveToPoint: collector.elements.append(.curve(to: element.points[2], control1: element.points[0], control2: element.points[1]))
            case .closeSubpath: collector.elements.append(.closeSubpath)
            @unknown default: break
            }
        }
        return collector.elements
    }

    public func forEach(_ body: (Element) -> Void) {
        elements.forEach(body)
    }

    public mutating func addLines(_ lines: [CGPoint]) {
        guard let first = lines.first else { return }
        move(to: first)
        for point in lines.dropFirst() { addLine(to: point) }
    }

    public mutating func addRects(_ rects: [CGRect], transform: CGAffineTransform = .identity) {
        unique()
        for rect in rects { storage.addRect(rect, transform: transform) }
    }

    public mutating func addRelativeArc(center: CGPoint, radius: CGFloat, startAngle: Angle, delta: Angle, transform: CGAffineTransform = .identity) {
        unique()
        storage.addRelativeArc(center: center, radius: radius, startAngle: CGFloat(startAngle.radians), delta: CGFloat(delta.radians), transform: transform)
    }

    public func strokedPath(_ style: StrokeStyle) -> Path {
        var source = storage as CGPath
        if !style.dash.isEmpty {
            source = source.copy(dashingWithPhase: style.dashPhase, lengths: style.dash)
        }
        return Path(source.copy(strokingWithWidth: style.lineWidth, lineCap: style.lineCap, lineJoin: style.lineJoin, miterLimit: style.miterLimit))
    }

    // The path as straight pieces: a curve becomes enough short lines that the eye cannot tell.
    fileprivate func polylines() -> [Polyline] {
        var result: [Polyline] = []
        var current: [CGPoint] = []
        var start = CGPoint.zero
        var last = CGPoint.zero
        func flush(closed: Bool) {
            if current.count > 1 || (closed && current.count == 1) { result.append(Polyline(points: current, closed: closed)) }
            current = []
        }
        func steps(_ polygon: [CGPoint]) -> Int {
            var length: CGFloat = 0
            for index in 1..<polygon.count { length += hypot(polygon[index].x - polygon[index - 1].x, polygon[index].y - polygon[index - 1].y) }
            return min(64, max(8, Int(length / 2)))
        }
        for element in elements {
            switch element {
            case .move(let point):
                flush(closed: false)
                current = [point]; start = point; last = point
            case .line(let point):
                if current.isEmpty { current = [last] }
                current.append(point); last = point
            case .quadCurve(let point, let control):
                if current.isEmpty { current = [last] }
                let count = steps([last, control, point])
                for step in 1...count {
                    let t = CGFloat(step) / CGFloat(count), u = 1 - t
                    current.append(CGPoint(x: u * u * last.x + 2 * u * t * control.x + t * t * point.x,
                                           y: u * u * last.y + 2 * u * t * control.y + t * t * point.y))
                }
                last = point
            case .curve(let point, let control1, let control2):
                if current.isEmpty { current = [last] }
                let count = steps([last, control1, control2, point])
                for step in 1...count {
                    let t = CGFloat(step) / CGFloat(count), u = 1 - t
                    current.append(CGPoint(x: u * u * u * last.x + 3 * u * u * t * control1.x + 3 * u * t * t * control2.x + t * t * t * point.x,
                                           y: u * u * u * last.y + 3 * u * u * t * control1.y + 3 * u * t * t * control2.y + t * t * t * point.y))
                }
                last = point
            case .closeSubpath:
                if !current.isEmpty { flush(closed: true) }
                last = start
            }
        }
        flush(closed: false)
        return result
    }

    // The part of the path between two fractions of its total length, the lengths of all subpaths counted together.
    public func trimmedPath(from: CGFloat, to: CGFloat) -> Path {
        let lines = polylines()
        let total = lines.reduce(CGFloat(0)) { $0 + $1.length }
        let lower = max(0, min(1, from)) * total, upper = max(0, min(1, to)) * total
        guard total > 0, upper > lower else { return Path() }
        var result = Path()
        var offset: CGFloat = 0
        for line in lines {
            let segments = line.segments
            let length = line.length
            defer { offset += length }
            let a = max(lower, offset), b = min(upper, offset + length)
            guard b > a || (b == a && length == 0) else { continue }
            if a <= offset && b >= offset + length && line.closed {
                result.move(to: line.points[0])
                for point in line.points.dropFirst() { result.addLine(to: point) }
                result.closeSubpath()
                continue
            }
            var travelled = offset
            var started = false
            for (from, to) in segments {
                let segment = hypot(to.x - from.x, to.y - from.y)
                defer { travelled += segment }
                guard segment > 0 else { continue }
                let lo = max(a, travelled), hi = min(b, travelled + segment)
                guard hi > lo else { continue }
                let first = CGPoint(x: from.x + (to.x - from.x) * (lo - travelled) / segment, y: from.y + (to.y - from.y) * (lo - travelled) / segment)
                let second = CGPoint(x: from.x + (to.x - from.x) * (hi - travelled) / segment, y: from.y + (to.y - from.y) * (hi - travelled) / segment)
                if !started { result.move(to: first); started = true }
                result.addLine(to: second)
            }
        }
        return result
    }
}

fileprivate struct Polyline {
    var points: [CGPoint]
    var closed: Bool

    var segments: [(CGPoint, CGPoint)] {
        var pairs = zip(points, points.dropFirst()).map { ($0, $1) }
        if closed, let first = points.first, let last = points.last, first != last { pairs.append((last, first)) }
        return pairs
    }

    var length: CGFloat { segments.reduce(0) { $0 + hypot($1.1.x - $1.0.x, $1.1.y - $1.0.y) } }
}

public struct _TrimmedShape<S: Shape>: Shape, PrimitiveView {
    public var shape: S
    public var startFraction: CGFloat
    public var endFraction: CGFloat
    public func path(in rect: CGRect) -> Path { shape.path(in: rect).trimmedPath(from: startFraction, to: endFraction) }
    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(startFraction, endFraction) }
        set { startFraction = newValue.first; endFraction = newValue.second }
    }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = ShapeNode(); n.update(self, env); return n }
}

public struct _SizedShape<S: Shape>: Shape, PrimitiveView {
    public var shape: S
    public var size: CGSize
    public func path(in rect: CGRect) -> Path { shape.path(in: CGRect(origin: rect.origin, size: size)) }
    public func sizeThatFits(_ proposal: ProposedViewSize) -> CGSize { size }
    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(size.width, size.height) }
        set { size = CGSize(width: newValue.first, height: newValue.second) }
    }
    func makeNode(_ env: EnvironmentValues) -> Node { let n = ShapeNode(); n.update(self, env); return n }
}

extension Shape {
    public func trim(from startFraction: CGFloat = 0, to endFraction: CGFloat = 1) -> some Shape {
        _TrimmedShape(shape: self, startFraction: startFraction, endFraction: endFraction)
    }
    public func size(_ size: CGSize) -> some Shape { _SizedShape(shape: self, size: size) }
    public func size(width: CGFloat, height: CGFloat) -> some Shape { _SizedShape(shape: self, size: CGSize(width: width, height: height)) }
}
