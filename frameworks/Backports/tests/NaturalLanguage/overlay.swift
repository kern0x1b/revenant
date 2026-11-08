import Foundation
import NaturalLanguage

private let languageRecognizer = NLLanguageRecognizer()

func recognized(text: String, supported: [String]) -> [(String, Double)] {
    languageRecognizer.processString(text)
    let hypotheses = languageRecognizer.languageHypotheses(withMaximum: 3)
    languageRecognizer.reset()
    return hypotheses.filter { supported.contains($0.key.rawValue) }.sorted(by: { $0.value > $1.value }).map { ($0.key.rawValue, $0.value) }
}

func hinted() -> [NLLanguage: Double] {
    languageRecognizer.languageHints = [.english: 0.7, .german: 0.3]
    return languageRecognizer.languageHints
}

func words(in text: String) -> [Range<String.Index>] {
    let tokenizer = NLTokenizer(unit: .word)
    tokenizer.string = text
    var found: [Range<String.Index>] = []
    tokenizer.enumerateTokens(in: text.startIndex ..< text.endIndex) { range, attributes in
        if !attributes.contains(.numeric) {
            found.append(range)
        }
        return range.upperBound < text.endIndex
    }
    return found
}

@available(iOS 12.0, *)
func tokens(in text: String) -> [Range<String.Index>] {
    let tokenizer = NLTokenizer(unit: .sentence)
    tokenizer.string = text
    let first = tokenizer.tokenRange(at: text.startIndex)
    return [first] + tokenizer.tokens(for: text.startIndex ..< text.endIndex)
}

@available(iOS 14.0, *)
func covering(text: String) -> Range<String.Index> {
    let tokenizer = NLTokenizer(unit: .word)
    tokenizer.string = text
    return tokenizer.tokenRange(for: text.startIndex ..< text.endIndex)
}

@available(iOS 12.0, *)
func tagged(text: String) -> [(NLTag?, Range<String.Index>)] {
    let tagger = NLTagger(tagSchemes: [.lexicalClass])
    tagger.string = text
    let one = tagger.tag(at: text.startIndex, unit: .word, scheme: .lexicalClass)
    tagger.enumerateTags(in: text.startIndex ..< text.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace]) { _, _ in true }
    tagger.setLanguage(.english, range: text.startIndex ..< text.endIndex)
    tagger.setOrthography(NSOrthography.defaultOrthography(forLanguage: "en"), range: text.startIndex ..< text.endIndex)
    _ = tagger.tokenRange(at: text.startIndex, unit: .word)
    return [one] + tagger.tags(in: text.startIndex ..< text.endIndex, unit: .word, scheme: .lexicalClass)
}

@available(iOS 14.0, *)
func hypotheses(text: String, model: NLModel) -> ([String: Double], [[String: Double]]) {
    let tagger = NLTagger(tagSchemes: [.nameType])
    tagger.string = text
    let _ = tagger.tokenRange(for: text.startIndex ..< text.endIndex, unit: .word)
    let _: ([String: Double], Range<String.Index>) = tagger.tagHypotheses(at: text.startIndex, unit: .word, scheme: .nameType, maximumCount: 2)
    return (model.predictedLabelHypotheses(for: text, maximumCount: 2), model.predictedLabelHypotheses(forTokens: [text], maximumCount: 2))
}

@available(iOS 13.0, *)
func embedded(embedding: NLEmbedding, url: URL) throws -> [(String, NLDistance)] {
    let _: NLDistance = embedding.distance(between: "a", and: "b")
    let _: NLDistance = embedding.distance(between: "a", and: "b", distanceType: .cosine)
    embedding.enumerateNeighbors(for: "a", maximumCount: 3) { _, _ in false }
    embedding.enumerateNeighbors(for: [0.5, 0.25], maximumCount: 3, distanceType: .cosine) { _, _ in true }
    let _: [Double]? = embedding.vector(for: "a")
    try NLEmbedding.write(["a": [1, 2]], language: .english, revision: 1, to: url)
    let _: [(String, NLDistance)] = embedding.neighbors(for: [0.5, 0.25], maximumCount: 2)
    return embedding.neighbors(for: "a", maximumCount: 3)
}

@available(iOS 17.0, *)
func contextual(result: NLContextualEmbeddingResult, text: String) -> ([Double], Range<String.Index>)? {
    result.enumerateTokenVectors(in: text.startIndex ..< text.endIndex) { vector, range in !vector.isEmpty && !range.isEmpty }
    return result.tokenVector(at: text.startIndex)
}
