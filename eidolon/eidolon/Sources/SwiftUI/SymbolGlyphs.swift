import UIKit
import CoreGraphics

// iOS 6 has no SF Symbols. The names apps use most are drawn here, as line art in a unit square, and tinted like a
// template image; a name outside the set is reported and drawn as an outlined square with a question mark.
struct GlyphPen {
    let context: CGContext
    let size: CGFloat
    let filled: Bool

    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * size, y: y * size) }
    var line: CGFloat { size * 0.075 }

    func path(_ build: (CGMutablePath, (CGFloat, CGFloat) -> CGPoint) -> Void) -> CGPath {
        let path = CGMutablePath()
        build(path, point)
        return path
    }

    // stroke, or fill when the symbol is the ".fill" variant and the shape can be filled
    func draw(_ path: CGPath, fillable: Bool = true) {
        context.addPath(path)
        if filled && fillable { context.fillPath() } else { context.strokePath() }
    }
    func lines(_ points: [(CGFloat, CGFloat)], closed: Bool = false, fillable: Bool = false) {
        let p = path { path, at in
            path.move(to: at(points[0].0, points[0].1))
            for q in points.dropFirst() { path.addLine(to: at(q.0, q.1)) }
            if closed { path.closeSubpath() }
        }
        draw(p, fillable: fillable)
    }
    func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, fillable: Bool = true) {
        draw(CGPath(ellipseIn: CGRect(x: (x - r) * size, y: (y - r) * size, width: r * 2 * size, height: r * 2 * size), transform: nil), fillable: fillable)
    }
    func dot(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
        context.fillEllipse(in: CGRect(x: (x - r) * size, y: (y - r) * size, width: r * 2 * size, height: r * 2 * size))
    }
    func rect(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat, radius: CGFloat = 0, fillable: Bool = true) {
        let box = CGRect(x: x0 * size, y: y0 * size, width: (x1 - x0) * size, height: (y1 - y0) * size)
        let corner = min(radius * size, box.width / 2, box.height / 2)
        let rounded = CGMutablePath()
        roundedRectangle(rounded, box, CGSize(width: corner, height: corner))
        draw(rounded, fillable: fillable)
    }
    func arc(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, from: CGFloat, to: CGFloat) {
        let p = CGMutablePath()
        p.addArc(center: point(x, y), radius: r * size, startAngle: from * .pi / 180, endAngle: to * .pi / 180, clockwise: false)
        context.addPath(p)
        context.strokePath()
    }
    func rotated(_ degrees: CGFloat, _ body: () -> Void) {
        context.saveGState()
        context.translateBy(x: size / 2, y: size / 2)
        context.rotate(by: degrees * .pi / 180)
        context.translateBy(x: -size / 2, y: -size / 2)
        body()
        context.restoreGState()
    }
}

enum SymbolGlyphs {
    typealias Glyph = (GlyphPen) -> Void

    private static let arrow: Glyph = { g in
        g.lines([(0.15, 0.5), (0.85, 0.5)])
        g.lines([(0.55, 0.2), (0.85, 0.5), (0.55, 0.8)])
    }
    private static let chevron: Glyph = { g in g.lines([(0.35, 0.15), (0.7, 0.5), (0.35, 0.85)]) }

    static let table: [String: Glyph] = [
        "plus": { g in g.lines([(0.5, 0.15), (0.5, 0.85)]); g.lines([(0.15, 0.5), (0.85, 0.5)]) },
        "minus": { g in g.lines([(0.15, 0.5), (0.85, 0.5)]) },
        "xmark": { g in g.lines([(0.22, 0.22), (0.78, 0.78)]); g.lines([(0.78, 0.22), (0.22, 0.78)]) },
        "multiply": { g in g.lines([(0.22, 0.22), (0.78, 0.78)]); g.lines([(0.78, 0.22), (0.22, 0.78)]) },
        "checkmark": { g in g.lines([(0.15, 0.55), (0.4, 0.8), (0.85, 0.2)]) },
        "chevron.right": chevron,
        "chevron.left": { g in g.rotated(180) { chevron(g) } },
        "chevron.up": { g in g.rotated(-90) { chevron(g) } },
        "chevron.down": { g in g.rotated(90) { chevron(g) } },
        "chevron.up.chevron.down": { g in
            g.lines([(0.3, 0.38), (0.5, 0.15), (0.7, 0.38)]); g.lines([(0.3, 0.62), (0.5, 0.85), (0.7, 0.62)])
        },
        "arrow.right": arrow,
        "arrow.left": { g in g.rotated(180) { arrow(g) } },
        "arrow.up": { g in g.rotated(-90) { arrow(g) } },
        "arrow.down": { g in g.rotated(90) { arrow(g) } },
        "arrow.clockwise": { g in
            g.arc(0.5, 0.5, 0.33, from: -60, to: 230)
            g.lines([(0.72, 0.1), (0.82, 0.32), (0.6, 0.32)], closed: true, fillable: true)
        },
        "magnifyingglass": { g in g.circle(0.42, 0.42, 0.27, fillable: false); g.lines([(0.62, 0.62), (0.86, 0.86)]) },
        "heart": { g in
            g.draw(g.path { p, _ in
                func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint { g.point(x / 100, y / 100) }
                p.move(to: at(50, 88))
                p.addCurve(to: at(5, 30), control1: at(20, 62), control2: at(5, 45))
                p.addCurve(to: at(30, 8), control1: at(5, 15), control2: at(18, 8))
                p.addCurve(to: at(50, 22), control1: at(40, 8), control2: at(47, 14))
                p.addCurve(to: at(70, 8), control1: at(53, 14), control2: at(60, 8))
                p.addCurve(to: at(95, 30), control1: at(82, 8), control2: at(95, 15))
                p.addCurve(to: at(50, 88), control1: at(95, 45), control2: at(80, 62))
                p.closeSubpath()
            })
        },
        "star": { g in
            var points: [(CGFloat, CGFloat)] = []
            for i in 0..<10 {
                let angle = CGFloat(i) * .pi / 5 - .pi / 2
                let r: CGFloat = i % 2 == 0 ? 0.45 : 0.19
                points.append((0.5 + r * cos(angle), 0.54 + r * sin(angle)))
            }
            g.lines(points, closed: true, fillable: true)
        },
        "house": { g in
            g.lines([(0.1, 0.5), (0.5, 0.12), (0.9, 0.5)], closed: false)
            g.lines([(0.2, 0.44), (0.2, 0.88), (0.8, 0.88), (0.8, 0.44)], closed: g.filled, fillable: true)
            if !g.filled { g.lines([(0.42, 0.88), (0.42, 0.62), (0.58, 0.62), (0.58, 0.88)]) }
        },
        "person": { g in
            g.circle(0.5, 0.3, 0.17)
            g.draw(g.path { p, at in
                p.move(to: at(0.15, 0.88))
                p.addCurve(to: at(0.5, 0.56), control1: at(0.15, 0.68), control2: at(0.3, 0.56))
                p.addCurve(to: at(0.85, 0.88), control1: at(0.7, 0.56), control2: at(0.85, 0.68))
                p.closeSubpath()
            })
        },
        "person.2": { g in
            g.circle(0.35, 0.32, 0.14); g.circle(0.68, 0.36, 0.12)
            g.arc(0.35, 0.92, 0.28, from: 200, to: 340); g.arc(0.7, 0.92, 0.22, from: 210, to: 330)
        },
        "gearshape": { g in
            g.circle(0.5, 0.5, 0.3, fillable: false); g.circle(0.5, 0.5, 0.11, fillable: false)
            for i in 0..<8 {
                let a = CGFloat(i) * .pi / 4
                g.lines([(0.5 + 0.3 * cos(a), 0.5 + 0.3 * sin(a)), (0.5 + 0.44 * cos(a), 0.5 + 0.44 * sin(a))])
            }
        },
        "trash": { g in
            g.lines([(0.15, 0.25), (0.85, 0.25)])
            g.lines([(0.4, 0.25), (0.4, 0.13), (0.6, 0.13), (0.6, 0.25)])
            g.lines([(0.22, 0.32), (0.29, 0.88), (0.71, 0.88), (0.78, 0.32)], closed: false, fillable: true)
            if !g.filled { g.lines([(0.42, 0.42), (0.42, 0.76)]); g.lines([(0.58, 0.42), (0.58, 0.76)]) }
        },
        "pencil": { g in g.lines([(0.16, 0.84), (0.26, 0.56), (0.66, 0.16), (0.84, 0.34), (0.44, 0.74)], closed: true, fillable: true) },
        "square.and.pencil": { g in
            g.lines([(0.62, 0.15), (0.2, 0.15), (0.12, 0.23), (0.12, 0.82), (0.2, 0.9), (0.72, 0.9), (0.8, 0.82), (0.8, 0.45)])
            g.lines([(0.42, 0.62), (0.48, 0.44), (0.76, 0.16), (0.9, 0.3), (0.62, 0.58)], closed: true)
        },
        "square.and.arrow.up": { g in
            g.lines([(0.3, 0.42), (0.15, 0.42), (0.15, 0.9), (0.85, 0.9), (0.85, 0.42), (0.7, 0.42)])
            g.lines([(0.5, 0.65), (0.5, 0.1)]); g.lines([(0.32, 0.28), (0.5, 0.1), (0.68, 0.28)])
        },
        "paperplane": { g in g.lines([(0.1, 0.5), (0.9, 0.12), (0.62, 0.9), (0.48, 0.6)], closed: true, fillable: true) },
        "bubble.left": { g in
            g.rect(0.08, 0.14, 0.92, 0.7, radius: 0.14)
            g.lines([(0.22, 0.7), (0.18, 0.9), (0.42, 0.7)], fillable: g.filled)
        },
        "bubble.right": { g in
            g.rect(0.08, 0.14, 0.92, 0.7, radius: 0.14)
            g.lines([(0.78, 0.7), (0.82, 0.9), (0.58, 0.7)], fillable: g.filled)
        },
        "bell": { g in
            g.draw(g.path { p, at in
                p.move(to: at(0.18, 0.74))
                p.addCurve(to: at(0.5, 0.1), control1: at(0.3, 0.62), control2: at(0.22, 0.1))
                p.addCurve(to: at(0.82, 0.74), control1: at(0.78, 0.1), control2: at(0.7, 0.62))
                p.closeSubpath()
            })
            g.lines([(0.14, 0.74), (0.86, 0.74)]); g.lines([(0.42, 0.86), (0.58, 0.86)])
        },
        "envelope": { g in g.rect(0.1, 0.22, 0.9, 0.78, radius: 0.04); g.lines([(0.1, 0.24), (0.5, 0.56), (0.9, 0.24)]) },
        "camera": { g in
            g.rect(0.08, 0.3, 0.92, 0.8, radius: 0.06)
            g.lines([(0.33, 0.3), (0.4, 0.18), (0.6, 0.18), (0.67, 0.3)])
            g.circle(0.5, 0.55, 0.15, fillable: false)
        },
        "photo": { g in
            g.rect(0.1, 0.18, 0.9, 0.82, radius: 0.04)
            g.lines([(0.15, 0.76), (0.4, 0.46), (0.55, 0.63), (0.7, 0.5), (0.85, 0.72)])
            g.dot(0.7, 0.33, 0.055)
        },
        "calendar": { g in
            g.rect(0.12, 0.2, 0.88, 0.88, radius: 0.06)
            g.lines([(0.12, 0.4), (0.88, 0.4)]); g.lines([(0.3, 0.1), (0.3, 0.28)]); g.lines([(0.7, 0.1), (0.7, 0.28)])
        },
        "clock": { g in g.circle(0.5, 0.5, 0.4); g.lines([(0.5, 0.5), (0.5, 0.25)]); g.lines([(0.5, 0.5), (0.68, 0.58)]) },
        "timer": { g in
            g.circle(0.5, 0.56, 0.34); g.lines([(0.42, 0.1), (0.58, 0.1)]); g.lines([(0.5, 0.1), (0.5, 0.22)]); g.lines([(0.5, 0.56), (0.5, 0.36)])
        },
        "ellipsis": { g in g.dot(0.2, 0.5, 0.06); g.dot(0.5, 0.5, 0.06); g.dot(0.8, 0.5, 0.06) },
        "line.3.horizontal": { g in
            g.lines([(0.15, 0.28), (0.85, 0.28)]); g.lines([(0.15, 0.5), (0.85, 0.5)]); g.lines([(0.15, 0.72), (0.85, 0.72)])
        },
        "list.bullet": { g in
            for y in [0.28, 0.5, 0.72] as [CGFloat] { g.dot(0.16, y, 0.045); g.lines([(0.32, y), (0.88, y)]) }
        },
        "folder": { g in g.lines([(0.08, 0.3), (0.08, 0.2), (0.4, 0.2), (0.5, 0.3), (0.92, 0.3), (0.92, 0.82), (0.08, 0.82)], closed: true, fillable: true) },
        "doc": { g in
            g.lines([(0.2, 0.1), (0.6, 0.1), (0.8, 0.3), (0.8, 0.9), (0.2, 0.9)], closed: true, fillable: true)
            if !g.filled { g.lines([(0.6, 0.1), (0.6, 0.3), (0.8, 0.3)]) }
        },
        "lock": { g in
            g.rect(0.2, 0.45, 0.8, 0.88, radius: 0.06)
            g.draw(g.path { p, at in
                p.move(to: at(0.32, 0.45)); p.addLine(to: at(0.32, 0.34))
                p.addArc(center: at(0.5, 0.34), radius: 0.18 * g.size, startAngle: .pi, endAngle: 0, clockwise: false)
                p.addLine(to: at(0.68, 0.45))
            }, fillable: false)
        },
        "eye": { g in
            g.draw(g.path { p, at in
                p.move(to: at(0.08, 0.5))
                p.addQuadCurve(to: at(0.92, 0.5), control: at(0.5, 0.05))
                p.addQuadCurve(to: at(0.08, 0.5), control: at(0.5, 0.95))
            }, fillable: false)
            g.circle(0.5, 0.5, 0.12)
        },
        "bookmark": { g in g.lines([(0.28, 0.1), (0.72, 0.1), (0.72, 0.9), (0.5, 0.7), (0.28, 0.9)], closed: true, fillable: true) },
        "cart": { g in
            g.lines([(0.08, 0.15), (0.22, 0.15), (0.32, 0.62), (0.8, 0.62), (0.88, 0.28), (0.26, 0.28)])
            g.dot(0.38, 0.8, 0.06); g.dot(0.72, 0.8, 0.06)
        },
        "info": { g in g.dot(0.5, 0.26, 0.055); g.lines([(0.5, 0.42), (0.5, 0.76)]) },
        "exclamationmark": { g in g.lines([(0.5, 0.12), (0.5, 0.62)]); g.dot(0.5, 0.84, 0.06) },
        "exclamationmark.triangle": { g in
            g.lines([(0.5, 0.1), (0.92, 0.86), (0.08, 0.86)], closed: true, fillable: true)
            g.lines([(0.5, 0.38), (0.5, 0.6)]); g.dot(0.5, 0.74, 0.04)
        },
        "play": { g in g.lines([(0.25, 0.15), (0.85, 0.5), (0.25, 0.85)], closed: true, fillable: true) },
        "pause": { g in g.rect(0.2, 0.15, 0.4, 0.85, fillable: true); g.rect(0.6, 0.15, 0.8, 0.85, fillable: true) },
        "stop": { g in g.rect(0.2, 0.2, 0.8, 0.8, radius: 0.06) },
        "forward": { g in
            g.lines([(0.1, 0.2), (0.5, 0.5), (0.1, 0.8)], closed: true, fillable: true); g.lines([(0.5, 0.2), (0.9, 0.5), (0.5, 0.8)], closed: true, fillable: true)
        },
        "backward": { g in
            g.lines([(0.9, 0.2), (0.5, 0.5), (0.9, 0.8)], closed: true, fillable: true); g.lines([(0.5, 0.2), (0.1, 0.5), (0.5, 0.8)], closed: true, fillable: true)
        },
        "globe": { g in
            g.circle(0.5, 0.5, 0.4, fillable: false); g.rect(0.3, 0.1, 0.7, 0.9, radius: 0.2, fillable: false); g.lines([(0.1, 0.5), (0.9, 0.5)])
        },
        "location": { g in g.lines([(0.85, 0.15), (0.15, 0.45), (0.5, 0.55), (0.6, 0.9)], closed: true, fillable: true) },
        "mic": { g in
            g.rect(0.38, 0.1, 0.62, 0.55, radius: 0.12); g.arc(0.5, 0.5, 0.26, from: 0, to: 180); g.lines([(0.5, 0.76), (0.5, 0.9)])
        },
        "wifi": { g in
            g.arc(0.5, 0.82, 0.22, from: 225, to: 315); g.arc(0.5, 0.82, 0.42, from: 225, to: 315); g.dot(0.5, 0.82, 0.05)
        },
        "square": { g in g.rect(0.12, 0.12, 0.88, 0.88, radius: 0.1) },
        "circle": { g in g.circle(0.5, 0.5, 0.4) },
        "square.grid.2x2": { g in
            g.rect(0.12, 0.12, 0.46, 0.46, radius: 0.04); g.rect(0.54, 0.12, 0.88, 0.46, radius: 0.04)
            g.rect(0.12, 0.54, 0.46, 0.88, radius: 0.04); g.rect(0.54, 0.54, 0.88, 0.88, radius: 0.04)
        },
        "sun.max": { g in
            g.circle(0.5, 0.5, 0.17)
            for i in 0..<8 { let a = CGFloat(i) * .pi / 4; g.lines([(0.5 + 0.28 * cos(a), 0.5 + 0.28 * sin(a)), (0.5 + 0.42 * cos(a), 0.5 + 0.42 * sin(a))]) }
        },
        "moon": { g in
            // the crescent is circle A less circle B: A's long way round between the two crossings, then B's inner arc back
            let a = CGPoint(x: 0.5, y: 0.5), b = CGPoint(x: 0.66, y: 0.4), ra: CGFloat = 0.4, rb: CGFloat = 0.32
            let d = hypot(b.x - a.x, b.y - a.y), along = (ra * ra - rb * rb + d * d) / (2 * d), h = (ra * ra - along * along).squareRoot()
            let ux = (b.x - a.x) / d, uy = (b.y - a.y) / d
            let px = a.x + along * ux, py = a.y + along * uy
            let top = CGPoint(x: px + h * uy, y: py - h * ux), bottom = CGPoint(x: px - h * uy, y: py + h * ux)
            let topOnA = atan2(top.y - a.y, top.x - a.x), bottomOnA = atan2(bottom.y - a.y, bottom.x - a.x)
            let bottomOnB = atan2(bottom.y - b.y, bottom.x - b.x), topOnB = atan2(top.y - b.y, top.x - b.x)
            g.draw(g.path { p, at in
                p.move(to: at(top.x, top.y))
                p.addArc(center: at(a.x, a.y), radius: ra * g.size, startAngle: topOnA, endAngle: bottomOnA, clockwise: true)
                p.addArc(center: at(b.x, b.y), radius: rb * g.size, startAngle: bottomOnB, endAngle: topOnB + (topOnB < bottomOnB ? 2 * .pi : 0), clockwise: false)
                p.closeSubpath()
            })
        },
        "bolt": { g in g.lines([(0.58, 0.08), (0.22, 0.56), (0.48, 0.56), (0.4, 0.92), (0.78, 0.4), (0.52, 0.4)], closed: true, fillable: true) },
        "link": { g in
            g.rotated(-45) { g.rect(0.02, 0.36, 0.56, 0.64, radius: 0.14, fillable: false); g.rect(0.44, 0.36, 0.98, 0.64, radius: 0.14, fillable: false) }
        },
        "speaker": { g in g.lines([(0.15, 0.4), (0.33, 0.4), (0.55, 0.2), (0.55, 0.8), (0.33, 0.6), (0.15, 0.6)], closed: true, fillable: true) },
        "speaker.wave.1": { g in
            g.lines([(0.1, 0.4), (0.26, 0.4), (0.46, 0.2), (0.46, 0.8), (0.26, 0.6), (0.1, 0.6)], closed: true, fillable: true)
            g.arc(0.46, 0.5, 0.2, from: -40, to: 40)
        },
        "speaker.wave.2": { g in
            g.lines([(0.08, 0.4), (0.22, 0.4), (0.4, 0.2), (0.4, 0.8), (0.22, 0.6), (0.08, 0.6)], closed: true, fillable: true)
            g.arc(0.4, 0.5, 0.18, from: -40, to: 40); g.arc(0.4, 0.5, 0.32, from: -40, to: 40)
        },
        "speaker.wave.3": { g in
            g.lines([(0.05, 0.4), (0.18, 0.4), (0.34, 0.2), (0.34, 0.8), (0.18, 0.6), (0.05, 0.6)], closed: true, fillable: true)
            g.arc(0.34, 0.5, 0.16, from: -40, to: 40); g.arc(0.34, 0.5, 0.29, from: -40, to: 40); g.arc(0.34, 0.5, 0.42, from: -40, to: 40)
        },
        "music.note": { g in
            g.dot(0.34, 0.76, 0.13); g.lines([(0.46, 0.74), (0.46, 0.14)]); g.lines([(0.46, 0.14), (0.8, 0.28), (0.8, 0.42), (0.46, 0.3)], closed: true, fillable: true)
        },
        "slider.horizontal.3": { g in
            for (y, x) in [(0.25, 0.3), (0.5, 0.65), (0.75, 0.4)] as [(CGFloat, CGFloat)] { g.lines([(0.1, y), (0.9, y)]); g.circle(x, y, 0.09) }
        },
    ]

    // "heart.fill", "plus.circle", "xmark.circle.fill", "checkmark.square"...: a base glyph, in a circle or a square, filled or not
    static func resolve(_ name: String) -> (base: Glyph, circled: Bool, squared: Bool, filled: Bool)? {
        var rest = name
        var filled = false, circled = false, squared = false
        if rest.hasSuffix(".fill") { filled = true; rest.removeLast(5) }
        if let exact = table[rest] { return (exact, false, false, filled) }
        if rest.hasSuffix(".circle") { circled = true; rest.removeLast(7) }
        else if rest.hasSuffix(".square") { squared = true; rest.removeLast(7) }
        if let base = table[rest] { return (base, circled, squared, filled) }
        return nil
    }

    static func image(named name: String, points: CGFloat, bold: Bool) -> UIImage? {
        guard let (base, circled, squared, filled) = resolve(name) else { return nil }
        UIGraphicsBeginImageContextWithOptions(CGSize(width: points, height: points), false, 0)
        defer { UIGraphicsEndImageContext() }
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setStrokeColor(UIColor.black.cgColor)
        context.setFillColor(UIColor.black.cgColor)
        let pen = GlyphPen(context: context, size: points, filled: filled && !circled && !squared)
        context.setLineWidth(pen.line * (bold ? 1.5 : 1))
        if circled || squared {
            // a symbol in a container: the container outlined, or solid with the symbol cut out of it
            let container = GlyphPen(context: context, size: points, filled: filled)
            if squared { container.rect(0.06, 0.06, 0.94, 0.94, radius: 0.16) } else { container.circle(0.5, 0.5, 0.44) }
            context.saveGState()
            context.translateBy(x: points * 0.25, y: points * 0.25)
            context.scaleBy(x: 0.5, y: 0.5)
            if filled { context.setBlendMode(.clear) }
            context.setLineWidth(pen.line * (bold ? 1.5 : 1) * 1.6)
            base(GlyphPen(context: context, size: points, filled: false))
            context.restoreGState()
        } else {
            base(pen)
        }
        return UIGraphicsGetImageFromCurrentImageContext()
    }

    // what a name that is not in the set looks like: an outlined square with a question mark
    static func placeholder(points: CGFloat) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(CGSize(width: points, height: points), false, 0)
        defer { UIGraphicsEndImageContext() }
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(points * 0.06)
        context.stroke(CGRect(x: points * 0.1, y: points * 0.1, width: points * 0.8, height: points * 0.8))
        let mark = UILabel(frame: CGRect(x: 0, y: points * 0.14, width: points, height: points * 0.7))
        mark.text = "?"
        mark.font = UIFont.boldSystemFont(ofSize: points * 0.55)
        mark.textAlignment = .center
        mark.textColor = .black
        mark.backgroundColor = .clear
        context.translateBy(x: 0, y: points * 0.14)
        mark.layer.render(in: context)
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
