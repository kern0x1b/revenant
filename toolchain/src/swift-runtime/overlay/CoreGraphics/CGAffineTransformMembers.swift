import CoreFoundation

extension CGAffineTransform {
    @inlinable public init(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat, _ tx: CGFloat, _ ty: CGFloat) {
        self = CGAffineTransformMake(a, b, c, d, tx, ty)
    }
}
