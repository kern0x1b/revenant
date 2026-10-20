# NSLinguisticTagger, units

Introduced in iOS 11.0. iOS 6 tags words only (`tagAtIndex:scheme:tokenRange:sentenceRange:`,
`enumerateTagsInRange:scheme:options:usingBlock:`); iOS 11 adds a unit to every call.

Source: the arm64 Foundation of 12.0 read through disassembly, the host's own tagger as a second
oracle, and the armv7 Foundation of 6.1.3 on an iPad 2.

## Behaviour

| member | behaviour |
|---|---|
| `-tokenRangeAtIndex:unit:` | word: the token range of the word tagger; sentence: `sentenceRangeForRange:`; paragraph: the string's paragraph range; document: the whole string. No string, or an index at or past the end, raises `NSRangeException` `*** -[NSLinguisticTagger tokenRangeAtIndex:unit:]: Range or index out of bounds`. |
| `-enumerateTagsInRange:unit:scheme:options:usingBlock:` | word: the word tagging of iOS 6, with the stop flag honoured even where the old enumeration ignores it. Larger units: one call per unit, Language and Script schemes only, tagged with the first tagged word of the unit read in the context of the whole string. Any other scheme above the word gives no calls. A range past the end raises `NSRangeException`. |
| `-tagAtIndex:unit:scheme:tokenRange:` | the same rules for one index; nil for a scheme that a unit above the word does not answer, the token range still set. |
| `-tagsInRange:unit:scheme:options:tokenRanges:` | the enumeration collected; a nil tag is stored as `NSNull`. |
| `+availableTagSchemesForUnit:language:` | word: `availableTagSchemesForLanguage:`; larger units: Language and Script. |
| `-dominantLanguage`, `+dominantLanguageForString:` | the Language tag most words carry; nil for an empty string or no string. |
| class conveniences | make a tagger for the string, give it the orthography for the whole range when one is passed, and call the instance method. |

## Differences

The Language and Script answers above the word come from the words of iOS 6's tagger, not from the
model of iOS 12. Text with a leading or trailing run of spaces, and a sentence that mixes German with
Japanese, are answered differently by the newest host engine; both are asserted literally in the
differential. The lexical class, lemma, name type and token type schemes above the word are not answered.
