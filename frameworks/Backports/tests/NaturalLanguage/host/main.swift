import Foundation
import NaturalLanguage

func rounded(_ value: Double) -> String {
    return String(format: "%.5f", value)
}

func shown(_ hypotheses: [NLLanguage: Double]) -> String {
    return hypotheses.sorted { $0.key.rawValue < $1.key.rawValue }.map { "\($0.key.rawValue)=\(rounded($0.value))" }.joined(separator: ",")
}

let recognizer = NLLanguageRecognizer()
let samples = ["Hello world, this is a test of the language recognizer.",
               "Bonjour tout le monde, ceci est un test de reconnaissance.",
               "Привет, это тест распознавания языка.",
               "12345",
               ""]
for sample in samples {
    recognizer.processString(sample)
    print("hypotheses", shown(recognizer.languageHypotheses(withMaximum: 3)), recognizer.dominantLanguage?.rawValue ?? "nil")
    print("one", shown(recognizer.languageHypotheses(withMaximum: 1)))
    recognizer.reset()
}
recognizer.languageHints = [.english: 0.8, .french: 0.2]
print("hints", shown(recognizer.languageHints))
recognizer.processString("Bonjour, ceci est un test.")
print("hinted", shown(recognizer.languageHypotheses(withMaximum: 2)))
recognizer.reset()
recognizer.languageHints = [:]
print("cleared", shown(recognizer.languageHints))

let text = "Hello, world 42! 😀 Second sentence here. Third one?\n\nNew paragraph."
let whole = text.startIndex ..< text.endIndex
let probe = text.index(text.startIndex, offsetBy: 3)
for unit in [NLTokenUnit.word, .sentence, .paragraph] {
    let tokenizer = NLTokenizer(unit: unit)
    tokenizer.string = text
    var tokens: [String] = []
    tokenizer.enumerateTokens(in: whole) { range, attributes in
        tokens.append("\(text[range])|\(attributes.rawValue)")
        return true
    }
    print("unit", unit.rawValue, tokens.joined(separator: ";"))
    print("at", text[tokenizer.tokenRange(at: probe)])
    print("tokens", tokenizer.tokens(for: whole).map { String(text[$0]) })
    print("for", text[tokenizer.tokenRange(for: probe ..< text.index(probe, offsetBy: 12))])
    var seen = 0
    tokenizer.enumerateTokens(in: whole) { _, _ in
        seen += 1
        return false
    }
    print("stopped", seen)
}

let sentence = "Tim Cook visited Paris and loved it."
let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType, .language])
tagger.string = sentence
let sentenceRange = sentence.startIndex ..< sentence.endIndex
let tagged = tagger.tags(in: sentenceRange, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation])
print("tags", tagged.map { "\($0.0?.rawValue ?? "nil"):\(sentence[$0.1])" })
var enumerated: [String] = []
tagger.enumerateTags(in: sentenceRange, unit: .word, scheme: .nameType, options: [.omitWhitespace, .omitPunctuation, .omitOther, .joinNames]) { tag, range in
    enumerated.append("\(tag?.rawValue ?? "nil"):\(sentence[range])")
    return true
}
print("names", enumerated)
var enumeratedStop = 0
tagger.enumerateTags(in: sentenceRange, unit: .word, scheme: .lexicalClass) { _, _ in
    enumeratedStop += 1
    return enumeratedStop < 3
}
print("tag stop", enumeratedStop)
let first = tagger.tag(at: sentence.startIndex, unit: .word, scheme: .lexicalClass)
print("tag", first.0?.rawValue ?? "nil", sentence[first.1])
let mid = sentence.index(sentence.startIndex, offsetBy: 20)
print("tokenRange", sentence[tagger.tokenRange(at: mid, unit: .word)], sentence[tagger.tokenRange(for: mid ..< sentence.index(mid, offsetBy: 6), unit: .word)])
let hypotheses = tagger.tagHypotheses(at: sentence.startIndex, unit: .word, scheme: .nameType, maximumCount: 3)
print("tagHypotheses", hypotheses.0.sorted { $0.key < $1.key }.map { "\($0.key)=\(rounded($0.value))" }, sentence[hypotheses.1])
tagger.setLanguage(.english, range: sentenceRange)
print("language", tagger.tag(at: sentence.startIndex, unit: .paragraph, scheme: .language).0?.rawValue ?? "nil")
tagger.setOrthography(NSOrthography.defaultOrthography(forLanguage: "en"), range: sentenceRange)
print("orthography", tagger.tags(in: sentenceRange, unit: .word, scheme: .lexicalClass).count)

if let embedding = NLEmbedding.wordEmbedding(for: .english) {
    print("distance", rounded(embedding.distance(between: "cat", and: "dog")), rounded(embedding.distance(between: "cat", and: "cat", distanceType: .cosine)))
    print("neighbors", embedding.neighbors(for: "cat", maximumCount: 4).map { "\($0.0)=\(rounded($0.1))" })
    var visited = 0
    embedding.enumerateNeighbors(for: "cat", maximumCount: 4) { _, _ in
        visited += 1
        return visited < 2
    }
    print("visited", visited)
    let vector = embedding.vector(for: "cat")
    print("vector", vector?.count ?? -1, vector.map { rounded($0[0]) } ?? "nil")
    if let vector = vector {
        print("by vector", embedding.neighbors(for: vector, maximumCount: 3).map { "\($0.0)=\(rounded($0.1))" })
        var byVector = 0
        embedding.enumerateNeighbors(for: vector, maximumCount: 3) { _, _ in
            byVector += 1
            return false
        }
        print("by vector stop", byVector)
    }
    print("no vector", embedding.vector(for: "zzzzqqqq") == nil)
} else {
    print("no embedding")
}
