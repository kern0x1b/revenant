# NLLanguageRecognizer and the NLLanguage constants, iOS 12

Names the language of text. The recognizer takes strings with `-processString:` (more than one adds up), answers
`dominantLanguage` and `-languageHypothesesWithMaximum:`, may be given `languageHints` (prior probabilities) and
`languageConstraints` (the only languages to answer), and `-reset` forgets the text and keeps hints and constraints.

Source: the host's NaturalLanguage for what each answers and keeps; an iPad 2 running 6.1.3, where the recognizer's
languages come from `NSLinguisticTagger`, which names the language of a sentence and knew the seven tested (English,
German, Spanish, French, Italian, Russian, Japanese) as the host does.

## What it does

- The text is cut into sentences (`NLTokenizer`), the tagger names each, and the language of a text is the one with the
  most letters in the sentences that were named it. Digits, emoji and blanks name none: `dominantLanguage` is `nil`
  and the hypotheses are an empty dictionary, as on the host.
- The hypotheses are those shares. A `maximum` of 0 asks for all of them; more than the languages seen answers all.
- Constraints keep only the languages listed, and the shares are worked out among them; hints multiply each share by
  the prior given, and a language not in the hints counts for nothing; hints that name none of the languages seen
  are put aside. Both are kept as set, copied, and start empty, and a reset keeps them.
- The 57 language constants of iOS 12 are there with the host's values (`en`, `zh-Hans`, `und`, ...); Kazakh (iOS 16) is not.

## Where it differs

The system's recognizer is a model: it answers a probability for every language it knows, also for a text of one word,
and its answer for a short text is a guess (`a` is Hungarian). The port answers what the release's tagger says,
in shares that are not those probabilities, of the languages that tagger knows, which are fewer, and a short text
is judged as the tagger judges it. A text of clear sentences gets the same language as on the host.
