# A term of address, iOS 17.0

The word an application uses to address the person it is speaking to, and the pronouns that go with
it. The class, the five factories and the two properties.

Source: the SDK 26.2 headers; the host's own `NSTermOfAddress`, measured through
`tests/backports/host/termofaddress`.

The localized words themselves come out of the inflection machinery, which is `NSMorphology`'s
business; what is here is the term, its language and its pronouns. Everything the host answers was
measured and is what the port does:

| | the host | the port |
| --- | --- | --- |
| `+neutral`, `+feminine`, `+masculine` | three distinct singletons, `languageIdentifier` nil, `pronouns` nil | the same |
| a term equal to itself | YES, and the hash is the same each time | the same |
| `+currentUser` | a singleton equal only to itself, no language | the same |
| `+localizedForLanguageIdentifier:withPronouns:` | equal to another with the same language and the same pronouns | the same |
| the same call with `@[]` instead of nil | **not** equal to the nil spelling | the same |
| two different languages | not equal | the same |

`-init` and `+new` are `NS_UNAVAILABLE` in the SDK's own header and are not carried: a term is one of
the five factories, and the compiler refuses the other two, which is the truth.

The class is carried up to iOS 16 and no further: 18.0 has it, and a band from there on answers with
the release's own.
