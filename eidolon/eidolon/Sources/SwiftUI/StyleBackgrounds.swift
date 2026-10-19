import UIKit

struct _EnvironmentBackground<Content: View, S: Shape>: View {
    let content: Content
    let shape: S
    let above: Bool
    @Environment(\.self) var environment
    var body: some View {
        let style = environment.backgroundShapeStyle ?? AnyShapeStyle(Color.white)
        return above ? AnyView(content.overlay(shape.fill(style))) : AnyView(content.background(shape.fill(style)))
    }
}

extension View {
    @_disfavoredOverload
    public func background<S: ShapeStyle>(_ style: S, ignoresSafeAreaEdges edges: Edge.Set = .all) -> some View {
        background(Rectangle().fill(style))
    }
    public func background(ignoresSafeAreaEdges edges: Edge.Set = .all) -> some View {
        _EnvironmentBackground(content: self, shape: Rectangle(), above: false)
    }
    public func background<S: ShapeStyle, T: Shape>(_ style: S, in shape: T, fillStyle: FillStyle = FillStyle()) -> some View {
        background(shape.fill(style))
    }
    public func background<T: Shape>(in shape: T, fillStyle: FillStyle = FillStyle()) -> some View {
        _EnvironmentBackground(content: self, shape: shape, above: false)
    }
    @_disfavoredOverload
    public func overlay<S: ShapeStyle>(_ style: S, ignoresSafeAreaEdges edges: Edge.Set = .all) -> some View {
        overlay(Rectangle().fill(style))
    }
    public func overlay<S: ShapeStyle, T: Shape>(_ style: S, in shape: T, fillStyle: FillStyle = FillStyle()) -> some View {
        overlay(shape.fill(style))
    }
    public func backgroundStyle<S: ShapeStyle>(_ style: S) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.backgroundShapeStyle = AnyShapeStyle(style) }, onUpdate: nil))
    }
    public func containerShape<T: InsettableShape>(_ shape: T) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.containerShapeValue = AnyShape(shape) }, onUpdate: nil))
    }
    public func contentTransition(_ transition: ContentTransition) -> some View {
        _ModifiedView(content: self, modifier: EnvironmentModifier(apply: { $0.contentTransition = transition }, onUpdate: nil))
    }
}

extension EnvironmentValues {
    public var backgroundStyle: AnyShapeStyle? {
        get { backgroundShapeStyle }
        set { backgroundShapeStyle = newValue }
    }
}
