# The attributed label, hint and value of accessibility, iOS 11.0

Introduced in iOS 11.0: the three strings VoiceOver reads out can be given as
attributed strings, so that an application can say how a word is pronounced,
which language it is in, or at what pitch it should be spoken.

Source: UIKit of the arm64 shared cache of iOS 11.0 (iPod7,1 15A372). The
accessors are one line each: `-accessibilityAttributedLabel` at `0x18a571e94`
calls `-_internalAccessibilityAttributedLabel` at `0x18a571e88`, which is an
associated-object read under a key of its own, and the setter at `0x18a5721d0`
writes it with the copy policy; the value and the hint are the same pair at
`0x18a571eac`/`0x18a571ea0` and `0x18a571ec4`/`0x18a571eb8`. The behaviour that
matters - how the attributed string and the plain one relate - was measured
against the host's UIKit (`tests/backports/host/interactions`), since the
relation is not in these four instructions but in what UIKit stores.

## One value with two faces

The attributed string and the plain string are not two properties but two
views of one. Measured, in both directions:

- a fresh object answers `nil` to both;
- setting the attributed label makes the plain label answer its `string`;
- setting the plain label makes the attributed label answer an attributed
  string of that text with **no** attributes;
- whichever was set last is what both answer;
- setting the attributed label to `nil` clears the plain one too;
- the attributed string is copied on the way in, so a mutable string the caller
  goes on editing does not change what the object answers;
- the hint and the value behave exactly as the label does;
- a `UILabel` with text answers `nil` to both: the text a control displays is
  not an accessibility label at this level.

The port keeps the attributed string in an associated object with the same copy
policy and writes its `string` into the release's own `accessibilityLabel`,
which is where iOS 6 has kept it since iOS 3. The getter hands back the stored
attributed string while its text still matches the plain one, and otherwise
builds a plain attributed string from what the plain property says now - which
is how "whichever was set last wins" comes out right without the port standing
in front of the release's own setter.

## What the attributes do here, and what they do not

The keys an application writes into such a string are exported constants, and
four of them belong to this range: `UIAccessibilitySpeechAttributeIPANotation`,
`UIAccessibilitySpeechAttributeQueueAnnouncement`,
`UIAccessibilityTextAttributeHeadingLevel` and
`UIAccessibilityTextAttributeCustom`. Each one's value is its own name, read
from UIKit 11.0, and the port carries them with those values; without them an
application that builds a speech-attributed string would put a `nil` key into a
dictionary and raise.

What they are for, this release cannot do: its VoiceOver reads
`accessibilityLabel` and knows nothing of pronunciation, pitch, queued
announcements or heading levels. So the text of the attributed string is spoken
and the attributes are not honoured. That is the whole of the limit, and it is
the release's, not the port's: the string reaches VoiceOver because the port
writes it where VoiceOver looks.

Three more keys of the same family - punctuation, language and pitch - are iOS
7.0 API and belong to another range; iOS 6 exports none of them.
