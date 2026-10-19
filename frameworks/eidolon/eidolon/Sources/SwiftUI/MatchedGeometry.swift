import UIKit
import CoreGraphics

struct MatchedKey: Hashable {
    let namespace: Namespace.ID
    let id: AnyHashable
}

enum MatchedFrames {
    nonisolated(unsafe) static var last: [MatchedKey: (frame: CGRect, owner: Int)] = [:]
    nonisolated(unsafe) static var nextOwner = 0
}

struct MatchedGeometryModifier: NodeModifier {
    let key: MatchedKey
    let isSource: Bool
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { MatchedGeometryNode() }
}

final class MatchedGeometryNode: ContainerNode {
    var key: MatchedKey?
    var isSource = true
    var from: CGRect?
    var placedOnce = false
    // not ObjectIdentifier: a node that has gone can leave its address to the next one, which would then look like the same owner
    let owner: Int = { MatchedFrames.nextOwner += 1; return MatchedFrames.nextOwner }()

    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        let modifier = m.modifierValue as! MatchedGeometryModifier
        key = modifier.key
        isSource = modifier.isSource
        content = adopt(reconcile(content, m.modifiedContent, env))
        if !placedOnce, Updates.animationForFlush != nil, let recorded = MatchedFrames.last[modifier.key],
           recorded.owner != owner {
            from = recorded.frame
        }
    }

    override func computeSize(_ p: ProposedSize) -> CGSize { children.first?.sizeThatFits(p) ?? .zero }

    override func layoutContents(_ size: CGSize) {
        children.first?.place(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        placedOnce = true
        if let from, let superview = uiView.superview {
            self.from = nil
            let target = uiView.frame
            let start = topmost(uiView).convert(from, to: superview)
            UIView.setAnimationsEnabled(false)
            uiView.frame = start
            children.first?.place(CGRect(x: 0, y: 0, width: start.size.width, height: start.size.height))
            UIView.setAnimationsEnabled(true)
            uiView.frame = target
            children.first?.place(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        }
        if isSource, let key {
            MatchedFrames.last[key] = (uiView.convert(uiView.bounds, to: topmost(uiView)), owner)
        }
    }
}

public struct MatchedGeometryProperties: OptionSet {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    public static let position = MatchedGeometryProperties(rawValue: 1)
    public static let size = MatchedGeometryProperties(rawValue: 2)
    public static let frame: MatchedGeometryProperties = [.position, .size]
}

extension View {
    public func matchedGeometryEffect<ID: Hashable>(id: ID, in namespace: Namespace.ID, properties: MatchedGeometryProperties = .frame, anchor: UnitPoint = .center, isSource: Bool = true) -> some View {
        if !isSource { _Unsupported.pendingNote("matchedGeometryEffect(isSource: false)") }
        return _ModifiedView(content: self, modifier: MatchedGeometryModifier(key: MatchedKey(namespace: namespace, id: AnyHashable(id)), isSource: isSource))
    }
}
