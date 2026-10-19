# NLTokenizer, iOS 12

A tokenizer of a **unit** (word, sentence, paragraph, document) over a string, answering the ranges of its tokens
and, for words, the attributes numeric, symbolic and emoji.

Source: the host's NaturalLanguage, compared with the port over 1445 checks (`tests/backports/host/naturallanguage`):
natural text in Latin, Cyrillic, Japanese, Chinese, Korean, Thai and Arabic, emoji sequences, three hundred random
strings, every index and several ranges of each, four units each; and an iPad 2 running 6.1.3, held to 99 answers
the host recorded (`tests/backports/device/naturallanguage.m`).

## What it does

- Words, sentences and paragraphs are the tokens of `CFStringTokenizer` of the unit, the language being the one set
  with `-setLanguage:` or the release's own guess from the text. The document is one token, the whole string, also
  when the string is empty.
- A word token that is only signs is not a token. The attributes of a word are the ones of its characters:
  numeric for a digit, symbolic for a sign that joins digits (the point in 3.14), emoji for an emoji. The keycap
  of a digit is neither, and one of `#` or `*` is emoji. The table of characters is the host's, taken from what its
  tokenizer answered for every code point up to U+2FFFF.
- Emoji sequences are cut as the system cuts them, over the whole string: a base with its modifiers, skin tones and
  tags, joined by zero width joiners, a flag of two regional indicators, a keycap. Text next to an emoji is cut off it.
- `-tokenRangeAtIndex:` answers the token that holds the index, and a range with location `NSNotFound` and length 0
  where none does, at the end of the string and past it included. `-tokensForRange:` and
  `-enumerateTokensInRange:usingBlock:` answer the tokens that intersect the range, in order; the block may stop
  the walk. A range that ends past the string answers nothing, and no call raises. An empty range answers the token
  it lies strictly inside, and for the document, the whole string.
- Two ways of the system's paragraphs are kept: a leading line break is joined to the first paragraph when the range
  asked for does not take it in, and a pair CR LF is one token to `-tokenRangeAtIndex:` and two to the walk.
- `-setString:` and `-setLanguage:` make the next call tokenize again. `-tokenRangeForRange:` is iOS 14 and not carried.

## Where iOS 6 answers differently

- The dictionary of the release's `CFStringTokenizer` is smaller than the system's, so a script it cuts with one
  ends up in more pieces (你好 is two words). Set to a language the text is not in, the two cut it in different places.
- The release does not know the abbreviations the system's sentence breaker leaves alone; the port joins the sentences
  around forty of them (Mr., Dr., e.g., a.m., ...), taken from what the system's breaker does with each.
- A sign that stands alone (™) is a word to the system in some places; the port drops it. A full stop followed by a
  symbol ends a sentence for the port and not for the system (both pinned in the differential).
- Emoji newer than the host's table, and Unicode the release does not know, are what the release's tokenizer makes of them.
