# NaturalLanguage on iOS 6: the Swift module

The Objective-C side of NaturalLanguage is the backport's classes: `NLLanguageRecognizer` (`frameworks/Backports/src/Foundation/NLLanguageRecognizer.m`),
`NLTokenizer` and the rest of what `lowered-members.txt` lists. The SDK refines the members that take or return a Swift
`Range`, a `Double` or an `NSNumber` with `NS_REFINED_FOR_SWIFT`, so the clang module imports them as `__`-prefixed names, and
the SDK's own Swift overlay supplies the public forms. That overlay is shipped for arm64e only (`usr/lib/swift/NaturalLanguage.swiftmodule`
holds `arm64e-apple-ios` alone), so an armv7 build sees the refined names and nothing else: Telegram's
`languageRecognizer.languageHypotheses(withMaximum: 3)` has no member to call. `src/NaturalLanguage/NaturalLanguage.swift` is the
backport's overlay, with the SDK's public surface and the SDK's signatures:

- `NLLanguageRecognizer.languageHints` and `languageHypotheses(withMaximum:)` as `[NLLanguage: Double]`;
- `NLTokenizer.tokenRange(at:)`, `tokenRange(for:)`, `enumerateTokens(in:using:)` and `tokens(for:)` over `Range<String.Index>`;
- `NLTagger.tokenRange(at:unit:)`, `tokenRange(for:unit:)`, `tag(at:unit:scheme:)`, `tagHypotheses(at:unit:scheme:maximumCount:)`,
  `enumerateTags(in:unit:scheme:options:using:)`, `tags(in:unit:scheme:options:)`, `setLanguage(_:range:)` and `setOrthography(_:range:)`;
- `NLModel.predictedLabelHypotheses(for:maximumCount:)` and `predictedLabelHypotheses(forTokens:maximumCount:)`;
- `NLEmbedding.distance(between:and:distanceType:)`, `enumerateNeighbors(for:...)`, `neighbors(for:...)` for a string and for a vector,
  `vector(for:)` and `write(_:language:revision:to:)`;
- `NLContextualEmbeddingResult.tokenVector(at:)` and `enumerateTokenVectors(in:using:)`.

The names of the refined members are the ones the compiler imports, found by calling them: for `NLEmbedding` they are
`__distanceBetweenString(_:andString:distanceType:)`, `__neighbors(for:...)`, `__neighbors(forVector:...)`,
`__enumerateNeighbors(for:...)`, `__enumerateNeighbors(forVector:...)`, `__vector(for:)` and `__write(for:language:revision:to:)`.

## Availability

The lowering removes the SDK availability of the members the backports implement. A Swift member whose Objective-C member is
lowered carries none (`languageHints`, `languageHypotheses(withMaximum:)`, `enumerateTokens(in:using:)`), and the others keep
the SDK's: `NLTokenizer.tokenRange(at:)` and `tokens(for:)` iOS 12.0, `tokenRange(for:)` iOS 14.0, and the `NLTagger`, `NLModel`,
`NLEmbedding` and `NLContextualEmbeddingResult` extensions carry the availability the SDK's interface puts on them (iOS 12.0, 14.0,
13.0 and 17.0), because the backports implement none of those four classes. A use of them is guarded, and on iOS 6 the guard is false.

The module is named like the SDK framework, so it is built with `-import-underlying-module` and its sources do not import it. A
consumer builds the `NaturalLanguage` target of the `Swift` component, passes its module folder with `-I` and links `libNaturalLanguage.a`.

## Checked

Measured: `frameworks/Backports/tests/natural_language_overlay_test.lua` compiles the overlay on the host as a module of the SDK's
name, links a program to it (`otool -L` is checked to show the overlay library), runs the same program against the SDK's overlay and
against ours, and requires identical output for the recognizer's hypotheses and hints, the three tokenizer units, the tagger's tags
and hypotheses, and the model and embedding forms the host has data for.
`frameworks/Backports/tests/framework_overlay_test.lua` builds the module for armv7 iOS 6.0 against the lowered SDK and typechecks
`frameworks/Backports/tests/NaturalLanguage/overlay.swift`, which calls every member above and repeats the recognizer
lines of Telegram's `Translate.swift`, and checks that the same file fails without it (`has no member 'languageHypotheses'`).

Not measured: a run on an iOS 6 device or the emulator. The recognizer's word-share model is the backport's, not Apple's
(`NLLanguageRecognizer.m`), so its probabilities differ from the system's; the overlay only converts them.
