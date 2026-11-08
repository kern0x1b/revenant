import Foundation

private func required(_ string: String?) -> String {
    guard let string = string else {
        preconditionFailure("the string of the object is nil")
    }
    return string
}

private func numbers(_ values: [Double]) -> [NSNumber] {
    return values.map { NSNumber(value: $0) }
}

private func doubles(_ values: [NSNumber]) -> [Double] {
    return values.map { $0.doubleValue }
}

extension NLTokenizer {
    @available(iOS 12.0, *)
    @nonobjc public func tokenRange(at index: String.Index) -> Range<String.Index> {
        let string = required(self.string)
        return Range(__tokenRange(at: index.utf16Offset(in: string)), in: string)!
    }

    @available(iOS 14.0, *)
    @nonobjc public func tokenRange(for range: Range<String.Index>) -> Range<String.Index> {
        let string = required(self.string)
        return Range(__tokenRange(for: NSRange(range, in: string)), in: string)!
    }

    @nonobjc public func enumerateTokens(in range: Range<String.Index>, using block: (Range<String.Index>, NLTokenizer.Attributes) -> Bool) {
        let string = required(self.string)
        __enumerateTokens(in: NSRange(range, in: string)) { tokenRange, attributes, stop in
            if !block(Range(tokenRange, in: string)!, attributes) {
                stop.pointee = true
            }
        }
    }

    @available(iOS 12.0, *)
    @nonobjc public func tokens(for range: Range<String.Index>) -> [Range<String.Index>] {
        let string = required(self.string)
        return __tokens(for: NSRange(range, in: string)).map { Range($0.rangeValue, in: string)! }
    }
}

@available(iOS 17.0, *)
extension NLContextualEmbeddingResult {
    @nonobjc public func tokenVector(at index: String.Index) -> ([Double], Range<String.Index>)? {
        var tokenRange = NSRange(location: 0, length: 0)
        guard let vector = __tokenVector(at: index.utf16Offset(in: string), tokenRange: &tokenRange) else {
            return nil
        }
        return (doubles(vector), Range(tokenRange, in: string)!)
    }

    @nonobjc public func enumerateTokenVectors(in range: Range<String.Index>, using block: ([Double], Range<String.Index>) -> Bool) {
        let string = self.string
        __enumerateTokenVectors(in: NSRange(range, in: string)) { vector, tokenRange, stop in
            if !block(doubles(vector), Range(tokenRange, in: string)!) {
                stop.pointee = true
            }
        }
    }
}

@available(iOS 12.0, *)
extension NLTagger {
    @nonobjc public func tokenRange(at index: String.Index, unit: NLTokenUnit) -> Range<String.Index> {
        let string = required(self.string)
        return Range(__tokenRange(at: index.utf16Offset(in: string), unit: unit), in: string)!
    }

    @available(iOS 14.0, *)
    @nonobjc public func tokenRange(for range: Range<String.Index>, unit: NLTokenUnit) -> Range<String.Index> {
        let string = required(self.string)
        return Range(__tokenRange(for: NSRange(range, in: string), unit: unit), in: string)!
    }

    @nonobjc public func tag(at index: String.Index, unit: NLTokenUnit, scheme: NLTagScheme) -> (NLTag?, Range<String.Index>) {
        let string = required(self.string)
        var tokenRange = NSRange(location: 0, length: 0)
        let tag = __tag(at: index.utf16Offset(in: string), unit: unit, scheme: scheme, tokenRange: &tokenRange)
        return (tag, Range(tokenRange, in: string)!)
    }

    @available(iOS 14.0, *)
    @nonobjc public func tagHypotheses(at index: String.Index, unit: NLTokenUnit, scheme: NLTagScheme, maximumCount: Int) -> ([String: Double], Range<String.Index>) {
        let string = required(self.string)
        var tokenRange = NSRange(location: 0, length: 0)
        let hypotheses = __tagHypotheses(at: index.utf16Offset(in: string), unit: unit, scheme: scheme, maximumCount: maximumCount, tokenRange: &tokenRange)
        var result: [String: Double] = [:]
        for (tag, probability) in hypotheses {
            result[tag.rawValue] = probability.doubleValue
        }
        return (result, Range(tokenRange, in: string)!)
    }

    @nonobjc public func enumerateTags(in range: Range<String.Index>, unit: NLTokenUnit, scheme: NLTagScheme, options: NLTagger.Options = [], using block: (NLTag?, Range<String.Index>) -> Bool) {
        let string = required(self.string)
        __enumerateTags(in: NSRange(range, in: string), unit: unit, scheme: scheme, options: options) { tag, tokenRange, stop in
            if !block(tag, Range(tokenRange, in: string)!) {
                stop.pointee = true
            }
        }
    }

    @nonobjc public func tags(in range: Range<String.Index>, unit: NLTokenUnit, scheme: NLTagScheme, options: NLTagger.Options = []) -> [(NLTag?, Range<String.Index>)] {
        var result: [(NLTag?, Range<String.Index>)] = []
        enumerateTags(in: range, unit: unit, scheme: scheme, options: options) { tag, tokenRange in
            result.append((tag, tokenRange))
            return true
        }
        return result
    }

    @nonobjc public func setLanguage(_ language: NLLanguage, range: Range<String.Index>) {
        __setLanguage(language, range: NSRange(range, in: required(self.string)))
    }

    @nonobjc public func setOrthography(_ orthography: NSOrthography, range: Range<String.Index>) {
        __setOrthography(orthography, range: NSRange(range, in: required(self.string)))
    }
}

@available(iOS 14.0, *)
extension NLModel {
    @nonobjc public func predictedLabelHypotheses(for string: String, maximumCount maxCount: Int) -> [String: Double] {
        return __predictedLabelHypotheses(for: string, maximumCount: maxCount).mapValues { $0.doubleValue }
    }

    @nonobjc public func predictedLabelHypotheses(forTokens tokens: [String], maximumCount maxCount: Int) -> [[String: Double]] {
        return __predictedLabelHypotheses(forTokens: tokens, maximumCount: maxCount).map { $0.mapValues { $0.doubleValue } }
    }
}

@available(iOS 13.0, *)
extension NLEmbedding {
    @nonobjc public func distance(between firstString: String, and secondString: String, distanceType: NLDistanceType = .cosine) -> NLDistance {
        return __distanceBetweenString(firstString, andString: secondString, distanceType: distanceType)
    }

    @nonobjc public func enumerateNeighbors(for string: String, maximumCount maxCount: Int, distanceType: NLDistanceType = .cosine, using block: (String, NLDistance) -> Bool) {
        __enumerateNeighbors(for: string, maximumCount: maxCount, distanceType: distanceType) { neighbor, distance, stop in
            if !block(neighbor, distance) {
                stop.pointee = true
            }
        }
    }

    @nonobjc public func neighbors(for string: String, maximumCount maxCount: Int, distanceType: NLDistanceType = .cosine) -> [(String, NLDistance)] {
        var result: [(String, NLDistance)] = []
        enumerateNeighbors(for: string, maximumCount: maxCount, distanceType: distanceType) { neighbor, distance in
            result.append((neighbor, distance))
            return true
        }
        return result
    }

    @nonobjc public func enumerateNeighbors(for vector: [Double], maximumCount maxCount: Int, distanceType: NLDistanceType = .cosine, using block: (String, NLDistance) -> Bool) {
        __enumerateNeighbors(forVector: numbers(vector), maximumCount: maxCount, distanceType: distanceType) { neighbor, distance, stop in
            if !block(neighbor, distance) {
                stop.pointee = true
            }
        }
    }

    @nonobjc public func neighbors(for vector: [Double], maximumCount maxCount: Int, distanceType: NLDistanceType = .cosine) -> [(String, NLDistance)] {
        var result: [(String, NLDistance)] = []
        enumerateNeighbors(for: vector, maximumCount: maxCount, distanceType: distanceType) { neighbor, distance in
            result.append((neighbor, distance))
            return true
        }
        return result
    }

    @nonobjc public func vector(for string: String) -> [Double]? {
        return __vector(for: string).map(doubles)
    }

    @nonobjc public class func write(_ dictionary: [String: [Double]], language: NLLanguage?, revision: Int, to url: URL) throws {
        try __write(for: dictionary.mapValues(numbers), language: language, revision: revision, to: url)
    }
}

extension NLLanguageRecognizer {
    @nonobjc public var languageHints: [NLLanguage: Double] {
        get {
            return __languageHints.mapValues { $0.doubleValue }
        }
        set(newHints) {
            __languageHints = newHints.mapValues { NSNumber(value: $0) }
        }
    }

    @nonobjc public func languageHypotheses(withMaximum maxHypotheses: Int) -> [NLLanguage: Double] {
        return __languageHypotheses(withMaximum: maxHypotheses).mapValues { $0.doubleValue }
    }
}
