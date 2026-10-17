# CoreSpotlight's value classes: CSPerson and CSSearchQueryContext

Two classes of the query surface are plain values: an application builds them, reads them back, copies
them and encodes them, and no index is involved. They are carried here, in `CoreSpotlight/CSPerson.m` and
`CoreSpotlight/CSSearchQueryContext.m`, and the answers are the host's, measured with
`tests/backports/host/corespotlight-values`: one program, built once against the macOS CoreSpotlight
framework and once against the port's two sources, whose output must be the same line for line after the
object addresses are replaced. The run has 86 lines, and a planted control (copy drops the contact
identifier, the attribute list defaults to nil) differs from the host on 7 lines, so the comparison can fail.

The surface is the rendered header of CSPerson and CSSearchQuery.h from the 26.2 SDK. The release has
neither class: a `CSPerson` is an iOS 9 value and a `CSSearchQueryContext` an iOS 10 one, and nothing on
iOS 6.1.3 reads them, so the answers only matter to an application that builds them itself.

## CSPerson (iOS 9)

- `initWithDisplayName:handles:handleIdentifier:` keeps the three values it is given: the name, the handles
  array and the identifier are stored as they are, so a mutable string or array passed in is seen through the
  person afterwards (measured: a name and a handle list both change when the caller appends to them). A nil
  name, a nil handle list and a nil identifier are stored as nil and raise nothing.
- `contactIdentifier` is the one property copied on set (`copy`). It is atomic, as declared, so both of its
  accessors are written under `@synchronized`.
- `copy` returns a new person with the same four values; `isEqual:` on the copy is YES.
- Equality is value equality over the four properties. The handles compare in order, `["1","2"]` differs from
  `["2","1"]`. A nil name differs from an empty one, and a nil contact identifier differs from an empty one.
  Two persons with equal content hash alike. `isEqual:` against nil or a string is NO.
- `description` (and `debugDescription`, which prints the same) is `<CSPerson:ADDRESS NAME <HANDLE, HANDLE>`:
  the class name, the address, the name with `%@` (so a nil name prints `(null)`), then the handles joined by
  `", "` inside angle brackets. The closing angle bracket of the outer form is not printed. The port keeps
  this text as measured. A nil name or a nil handle list prints as `(null)`, because `componentsJoinedByString:` on nil is nil.
- Secure coding: `supportsSecureCoding` is YES, and a person coded and decoded reads back the same four values
  (a nil name stays nil). The archive's key names are the port's own; they are not measured against the host,
  and nothing in the tree reads them.

## CSSearchQueryContext (iOS 10)

- A new context has no filter queries (`filterQueries` is nil), an empty attribute list (`fetchAttributes` is
  `()`), no keyboard language (nil) and source options 0. The port starts with the attribute list empty and
  leaves the rest at the default of its type.
- Setting `fetchAttributes` to nil stores the empty list, measured; the port does the same.
- `filterQueries` is copied on set, measured: a mutable array passed in and then appended to is not seen
  through the context. Setting it to nil stores nil.
- `keyboardLanguage` and `sourceOptions` are stored as given.
- `copy` returns a new context with the same four values, and a context compares by identity: two contexts
  with the default values are not equal, and their hashes differ (measured). The port keeps both.
- Secure coding is supported, and the four values survive a round trip.

## What is not here

`CSSearchQuery`, `CSUserQuery`, `CSUserQueryContext`, `CSSuggestion` and the query constants need the index,
its query grammar and its ranking, so they are not part of this family. `CSUserQueryContext` and its class
method `userQueryContextWithCurrentSuggestion:` depend on `CSSuggestion`, which is the next slice.
