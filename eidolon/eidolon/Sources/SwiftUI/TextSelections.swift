import UIKit
import CoreGraphics

// What is selected in a string: one range, or several, or just a caret. Apple's shape exactly
// (`SwiftUI.swiftinterface:20146` — `indices`, `affinity`, three initialisers, `isInsertion`,
// `Equatable` and `Hashable`), and the editor binds it to the `UITextView`'s own selection.
public struct TextSelection: Equatable, Hashable {
    /// The two shapes a selection can have, in the names Apple gives them.
    public enum Indices: Equatable, Hashable {
        case selection(Range<String.Index>)
        case multiSelection(RangeSet<String.Index>)
    }

    public var indices: Indices
    public var affinity: TextSelectionAffinity

    public init(range: Range<String.Index>) {
        self.indices = .selection(range)
        self.affinity = .automatic
    }

    public init(ranges: RangeSet<String.Index>) {
        self.indices = .multiSelection(ranges)
        self.affinity = .automatic
    }

    public init(insertionPoint: String.Index) {
        self.indices = .selection(insertionPoint..<insertionPoint)
        self.affinity = .automatic
    }

    /// A caret rather than a selection: the range is empty.
    public var isInsertion: Bool {
        if case .selection(let range) = indices { return range.isEmpty }
        return false
    }

    /// The selection as a `NSRange`, which is what `UITextView` speaks, against the text it is a
    /// selection in: one range maps to itself and several to the first of them, because iOS 6's text
    /// view carries exactly one selected range.
    func nsRange(in text: String) -> NSRange {
        switch indices {
        case .selection(let range): return NSRange(range, in: text)
        case .multiSelection(let ranges):
            // `RangeSet` is not a Sequence in this stdlib, and iOS 6's text view carries exactly one
            // selected range, so the lowest of the set's ranges is the one it is given
            var lowest: Range<String.Index>?
            for range in ranges.ranges where lowest == nil || range.lowerBound < lowest!.lowerBound { lowest = range }
            guard let range = lowest else { return NSRange(location: 0, length: 0) }
            return NSRange(range, in: text)
        }
    }

    /// The selection of a `UITextView`'s own `NSRange`, in a string.
    init(nsRange: NSRange, in text: String) {
        if let start = Range(nsRange, in: text) {
            self.init(range: start)
        } else {
            self.init(insertionPoint: text.endIndex)
        }
    }
}

extension EnvironmentValues {
    /// The selection in the editable text below. iOS 6's `UITextView` carries exactly one selected
    /// range, so a multi-range selection is stored and read back as its first range.
    public var textSelection: TextSelection? {
        get { self[TextSelectionKey.self] }
        set { self[TextSelectionKey.self] = newValue }
    }
}

struct TextSelectionKey: EnvironmentKey {
    static var defaultValue: TextSelection? { nil }
}
