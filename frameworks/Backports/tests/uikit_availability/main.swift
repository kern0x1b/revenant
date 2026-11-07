import UIKit
import Container

func keyboardTypes() -> [UIKeyboardType] {
    return [.webSearch, .asciiCapableNumberPad, .default]
}

func appendElements(of node: ContainerNode, to list: inout [Any]) {
    if let elements = node.accessibilityElements {
        list.append(contentsOf: elements)
    }
}

final class ElementsView: UIView {
    private var stored: [Any]?

    override var accessibilityElements: [Any]? {
        get { return stored }
        set { stored = newValue }
    }
}

final class ElementsObject: NSObject {
    override var accessibilityElements: [Any]? {
        get { return [] }
        set {}
    }
}

func assign(_ elements: [Any], to view: UIView) {
    view.accessibilityElements = elements
}

func elements(of object: NSObject) -> [Any]? {
    return object.accessibilityElements
}

func count(of node: ContainerNode) -> Int {
    return node.accessibilityElements().count
}
