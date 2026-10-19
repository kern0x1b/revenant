import UIKit

extension Color: Hashable {
    private var components: [CGFloat] {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) { return [r, g, b, a] }
        var w: CGFloat = 0
        if uiColor.getWhite(&w, alpha: &a) { return [w, w, w, a] }
        return (uiColor.cgColor.components ?? []).map { $0 }
    }
    public static func == (a: Color, b: Color) -> Bool {
        let x = a.components, y = b.components
        return x.count == y.count && zip(x, y).allSatisfy { abs($0 - $1) < 0.0001 }
    }
    public func hash(into hasher: inout Hasher) {
        for component in components { hasher.combine(Int((component * 1000).rounded())) }
    }
    public init(cgColor: CGColor) { self.init(UIColor(cgColor: cgColor)) }
    public init(_ cgColor: CGColor) { self.init(UIColor(cgColor: cgColor)) }
    public var cgColor: CGColor? { uiColor.cgColor }
}

extension Color: CustomStringConvertible {
    public var description: String {
        let c = components
        return c.count == 4 ? "#" + c.prefix(3).map { String(format: "%02X", Int(($0 * 255).rounded())) }.joined() + (c[3] < 1 ? String(format: "%02X", Int((c[3] * 255).rounded())) : "") : "Color"
    }
}
