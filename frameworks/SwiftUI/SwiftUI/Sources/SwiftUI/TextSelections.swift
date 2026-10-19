import UIKit
import CoreGraphics

public struct TextSelection: Equatable, Hashable {
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

    public var isInsertion: Bool {
        if case .selection(let range) = indices { return range.isEmpty }
        return false
    }

    func nsRange(in text: String) -> NSRange {
        switch indices {
        case .selection(let range): return NSRange(range, in: text)
        case .multiSelection(let ranges):
            var lowest: Range<String.Index>?
            for range in ranges.ranges where lowest == nil || range.lowerBound < lowest!.lowerBound { lowest = range }
            guard let range = lowest else { return NSRange(location: 0, length: 0) }
            return NSRange(range, in: text)
        }
    }

    init(nsRange: NSRange, in text: String) {
        if let start = Range(nsRange, in: text) {
            self.init(range: start)
        } else {
            self.init(insertionPoint: text.endIndex)
        }
    }
}

extension EnvironmentValues {
    public var textSelection: TextSelection? {
        get { self[TextSelectionKey.self] }
        set { self[TextSelectionKey.self] = newValue }
    }
}

struct TextSelectionKey: EnvironmentKey {
    static var defaultValue: TextSelection? { nil }
}
