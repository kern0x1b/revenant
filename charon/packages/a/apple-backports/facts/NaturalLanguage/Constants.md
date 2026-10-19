# NaturalLanguage's string constants: 71 names and the values the system's own framework gives them

`Foundation/NLConstants12.m`, `NLConstants13.m`, `NLConstants16.m` and `NLConstants17.m` carry the
tag schemes, the tags, the scripts and the one language SDK 26.2 declares that the port did not. The 57
`NLLanguage*` constants `Foundation/NLLanguage.m` already carried are not repeated here.

## Where every value came from, and why not a header

These names are `NSString * const` in every SDK header, and no header states a value.
`NaturalLanguage/Framework/Headers/NLTagScheme.h`, `NLScript.h` and `NLLanguage.h` declare the name, the
typedef (`NLTag`, `NLScript`, `NLLanguage`, all `NSString *`) and the release it arrived in -- nothing
more. So there is nothing in a header to read and a value taken from one would be an invention.

Each constant is a data symbol in `NaturalLanguage.framework`, so the value is reached with `dlsym` and
the host's own framework answers with the string its tagger, script table and language table use.
`tests/backports/host/naturaltags` does exactly that: one `dlsym` per constant, 71 of them, run twice.
The first run wrote `values.tsv` beside it; every run after compares the host against that table.

```
$ tests/backports/host/naturaltags/run.sh
naturaltags: 71 values compared against the host's own NaturalLanguage
naturaltags: tag names sharing one value: NLTagOtherPunctuation and NLTagPunctuation are both Punctuation
naturaltags: tag names sharing one value: NLTagOtherWhitespace and NLTagWhitespace are both Whitespace
naturaltags: 39 tag constants, 37 distinct values, 2 names sharing a value
naturaltags: 31 script constants, 31 distinct values, 0 names sharing a value
naturaltags: 1 language constants, 1 distinct values, 0 names sharing a value
naturaltags: 142 checks, 0 different
```

The two pairs that share a value are the system's own answer, not a transcription slip.
`NLTagScheme.h` says a tag is used with `==` comparison, and the host's `NLTagOtherPunctuation` *is* the
string `NLTagPunctuation` is, and its `NLTagOtherWhitespace` is the string `NLTagWhitespace` is. The
distinctness check is therefore a report and not an assertion, and the port carries the measured values
rather than the ones the names suggest.

## The values

| Constant | Value | Introduced |
| --- | --- | --- |
| `NLTagAdjective` | `Adjective` | 12.0 |
| `NLTagAdverb` | `Adverb` | 12.0 |
| `NLTagClassifier` | `Classifier` | 12.0 |
| `NLTagCloseParenthesis` | `CloseParenthesis` | 12.0 |
| `NLTagCloseQuote` | `CloseQuote` | 12.0 |
| `NLTagConjunction` | `Conjunction` | 12.0 |
| `NLTagDash` | `Dash` | 12.0 |
| `NLTagDeterminer` | `Determiner` | 12.0 |
| `NLTagIdiom` | `Idiom` | 12.0 |
| `NLTagInterjection` | `Interjection` | 12.0 |
| `NLTagNoun` | `Noun` | 12.0 |
| `NLTagNumber` | `Number` | 12.0 |
| `NLTagOpenParenthesis` | `OpenParenthesis` | 12.0 |
| `NLTagOpenQuote` | `OpenQuote` | 12.0 |
| `NLTagOrganizationName` | `OrganizationName` | 12.0 |
| `NLTagOther` | `Other` | 12.0 |
| `NLTagOtherPunctuation` | `Punctuation` | 12.0 |
| `NLTagOtherWhitespace` | `Whitespace` | 12.0 |
| `NLTagOtherWord` | `OtherWord` | 12.0 |
| `NLTagParagraphBreak` | `ParagraphBreak` | 12.0 |
| `NLTagParticle` | `Particle` | 12.0 |
| `NLTagPersonalName` | `PersonalName` | 12.0 |
| `NLTagPlaceName` | `PlaceName` | 12.0 |
| `NLTagPreposition` | `Preposition` | 12.0 |
| `NLTagPronoun` | `Pronoun` | 12.0 |
| `NLTagPunctuation` | `Punctuation` | 12.0 |
| `NLTagSchemeLanguage` | `Language` | 12.0 |
| `NLTagSchemeLemma` | `Lemma` | 12.0 |
| `NLTagSchemeLexicalClass` | `LexicalClass` | 12.0 |
| `NLTagSchemeNameType` | `NameType` | 12.0 |
| `NLTagSchemeNameTypeOrLexicalClass` | `NameTypeOrLexicalClass` | 12.0 |
| `NLTagSchemeScript` | `Script` | 12.0 |
| `NLTagSchemeTokenType` | `TokenType` | 12.0 |
| `NLTagSentenceTerminator` | `SentenceTerminator` | 12.0 |
| `NLTagVerb` | `Verb` | 12.0 |
| `NLTagWhitespace` | `Whitespace` | 12.0 |
| `NLTagWord` | `Word` | 12.0 |
| `NLTagWordJoiner` | `WordJoiner` | 12.0 |
| `NLTagSchemeSentimentScore` | `Sentiment` | 13.0 |
| `NLLanguageKazakh` | `kk` | 16.0 |
| `NLScriptArabic` | `Arab` | 17.0 |
| `NLScriptArmenian` | `Armn` | 17.0 |
| `NLScriptBengali` | `Beng` | 17.0 |
| `NLScriptCanadianAboriginalSyllabics` | `Cans` | 17.0 |
| `NLScriptCherokee` | `Cher` | 17.0 |
| `NLScriptCyrillic` | `Cyrl` | 17.0 |
| `NLScriptDevanagari` | `Deva` | 17.0 |
| `NLScriptEthiopic` | `Ethi` | 17.0 |
| `NLScriptGeorgian` | `Geor` | 17.0 |
| `NLScriptGreek` | `Grek` | 17.0 |
| `NLScriptGujarati` | `Gujr` | 17.0 |
| `NLScriptGurmukhi` | `Guru` | 17.0 |
| `NLScriptHebrew` | `Hebr` | 17.0 |
| `NLScriptJapanese` | `Jpan` | 17.0 |
| `NLScriptKannada` | `Knda` | 17.0 |
| `NLScriptKhmer` | `Khmr` | 17.0 |
| `NLScriptKorean` | `Kore` | 17.0 |
| `NLScriptLao` | `Laoo` | 17.0 |
| `NLScriptLatin` | `Latn` | 17.0 |
| `NLScriptMalayalam` | `Mlym` | 17.0 |
| `NLScriptMongolian` | `Mong` | 17.0 |
| `NLScriptMyanmar` | `Mymr` | 17.0 |
| `NLScriptOriya` | `Orya` | 17.0 |
| `NLScriptSimplifiedChinese` | `Hans` | 17.0 |
| `NLScriptSinhala` | `Sinh` | 17.0 |
| `NLScriptTamil` | `Taml` | 17.0 |
| `NLScriptTelugu` | `Telu` | 17.0 |
| `NLScriptThai` | `Thai` | 17.0 |
| `NLScriptTibetan` | `Tibt` | 17.0 |
| `NLScriptTraditionalChinese` | `Hant` | 17.0 |
| `NLScriptUndetermined` | `Zyyy` | 17.0 |

## How they are stored

`NSString * const`, each with its initializer at its definition, as the SDK's own headers declare them.
A `const` object cannot be assigned after its definition, so unlike the `UTType` catalogue constants
these are not filled in by a constructor.

## One object per release band

38 constants arrived in iOS 12, one in 13 (`NLTagSchemeSentimentScore`), one in 16
(`NLLanguageKazakh`) and 31 in 17 (the `NLScript*` set). An object holds the API of exactly one
release, so one object per band; the registry follows the same split, one file per band.
