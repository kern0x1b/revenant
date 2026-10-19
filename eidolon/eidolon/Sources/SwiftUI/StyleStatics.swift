import UIKit
import CoreGraphics

extension ProgressViewStyle where Self == DefaultProgressViewStyle {
    public static var automatic: DefaultProgressViewStyle { DefaultProgressViewStyle() }
}
extension ProgressViewStyle where Self == CircularProgressViewStyle {
    public static var circular: CircularProgressViewStyle { CircularProgressViewStyle() }
}
extension ProgressViewStyle where Self == LinearProgressViewStyle {
    public static var linear: LinearProgressViewStyle { LinearProgressViewStyle() }
}
extension ListStyle where Self == InsetListStyle {
    public static var inset: InsetListStyle { InsetListStyle() }
}
extension ListStyle where Self == SidebarListStyle {
    public static var sidebar: SidebarListStyle { SidebarListStyle() }
}
extension PickerStyle where Self == DefaultPickerStyle {
    public static var automatic: DefaultPickerStyle { DefaultPickerStyle() }
}
extension ToggleStyle where Self == DefaultToggleStyle {
    public static var automatic: DefaultToggleStyle { DefaultToggleStyle() }
}
extension TextFieldStyle where Self == DefaultTextFieldStyle {
    public static var automatic: DefaultTextFieldStyle { DefaultTextFieldStyle() }
}
extension DatePickerStyle where Self == DefaultDatePickerStyle {
    public static var automatic: DefaultDatePickerStyle { DefaultDatePickerStyle() }
}
extension DatePickerStyle where Self == WheelDatePickerStyle {
    public static var wheel: WheelDatePickerStyle { WheelDatePickerStyle() }
}
extension DatePickerStyle where Self == CompactDatePickerStyle {
    public static var compact: CompactDatePickerStyle { CompactDatePickerStyle() }
}
extension DatePickerStyle where Self == GraphicalDatePickerStyle {
    public static var graphical: GraphicalDatePickerStyle { GraphicalDatePickerStyle() }
}

extension Material {
    public static let ultraThin = Material.ultraThinMaterial
    public static let thin = Material.thinMaterial
    public static let regular = Material.regularMaterial
    public static let thick = Material.thickMaterial
    public static let ultraThick = Material.ultraThickMaterial
}

extension ShapeStyle where Self == Color {
    public static var purple: Color { .purple }
    public static var pink: Color { .pink }
    public static var brown: Color { .brown }
    public static var cyan: Color { .cyan }
    public static var indigo: Color { .indigo }
    public static var mint: Color { .mint }
    public static var teal: Color { .teal }
}

extension ShapeStyle where Self == ForegroundStyle {
    public static var foreground: ForegroundStyle { ForegroundStyle() }
}
extension ShapeStyle where Self == BackgroundStyle {
    public static var background: BackgroundStyle { BackgroundStyle() }
}

protocol OptionalPaintStyle { var optionalPaint: _GradientPaint? { get } }

public struct _OpacityStyle<Base: ShapeStyle>: ShapeStyle, OptionalPaintStyle {
    let base: Base
    let opacity: Double
    public var _uiColor: UIColor? {
        base._uiColor.map { color in
            var white: CGFloat = 0, alpha: CGFloat = 0
            if color.getWhite(&white, alpha: &alpha) { return UIColor(white: white, alpha: alpha * CGFloat(opacity)) }
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
            if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) { return UIColor(red: red, green: green, blue: blue, alpha: alpha * CGFloat(opacity)) }
            return color.withAlphaComponent(CGFloat(opacity))
        }
    }
    var optionalPaint: _GradientPaint? {
        base._gradientPaint.map { paint in
            _GradientPaint(kind: paint.kind, stops: paint.stops.map { stop in
                var color = stop.color
                color = Color(_OpacityStyle<Color>(base: color, opacity: opacity)._uiColor ?? color.uiColor)
                return Gradient.Stop(color: color, location: stop.location)
            })
        }
    }
}

extension ShapeStyle {
    public func opacity(_ opacity: Double) -> some ShapeStyle { _OpacityStyle(base: self, opacity: opacity) }
    public func blendMode(_ blendMode: BlendMode) -> some ShapeStyle {
        if blendMode != .normal { _Unsupported.note("ShapeStyle.blendMode", "CoreAnimation of iOS 6 has no layer blend modes; the style is drawn normally") }
        return self
    }
}
