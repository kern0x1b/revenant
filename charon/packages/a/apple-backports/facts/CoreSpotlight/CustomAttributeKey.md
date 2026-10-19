# CSCustomAttributeKey (iOS 9)

A custom attribute key names one custom property of a searchable item: its name, and four flags that say how the index treats
it. `CoreSpotlight/CSCustomAttributeKey.m` carries the class; the answers are the host's, measured with
`tests/backports/host/corespotlight-customkey`: one program, built once against the macOS CoreSpotlight framework and once against
the port's source, whose output must be the same line for line after object addresses are replaced. The run has 168 lines, and a
planted control (the hyphen is let through) differs from the host on 4 lines, so the comparison can fail.

The surface is the rendered header of CSSearchableItemAttributeSet.h from the 26.2 SDK. The class is an iOS 9 one; the release
of this port (6.1.3) does not hold it (the cache check finds no `_OBJC_CLASS_$_CSCustomAttributeKey` in the 6.1.3 cache), so the
port is the only copy an application on that release can use. The attribute set's custom-value API, which takes these keys,
is not part of this change.

## The name

- A name is accepted when every character is ASCII and none of these is in it:
  `! " # % & ' ( ) * , - . / : ; ? @ [ \ ] { }`. Measured one character at a time, between `a` and `b`.
- Every other ASCII character is accepted: the controls (including NUL and tab), the space, the digits and letters, `_`, and
  ``$ + < = > ^ ` | ~`` and the delete character.
- Any character outside ASCII is refused, measured for `é`, the no-break space, U+2028, `€`, a CJK character, an emoji (a
  surrogate pair) and a combining mark.
- The empty name is accepted. A nil name gives no key at all (the initializer answers nil; it does not raise).
- No length limit was found: names of 1000 and of 10010 characters are accepted.
- A name the rule refuses gives nil from both initializers. Nothing is raised.
- The name is stored as it was given: a mutable name changed after the key is made is seen through the key (measured).

## Initializers and flags

- `initWithKeyName:` gives searchable YES and the other three flags NO (measured).
- `initWithKeyName:searchable:searchableByDefault:unique:multiValued:` keeps the four flags it is given, measured for each
  combination tried.
- `init` (unavailable in the header) raises NSInvalidArgumentException with the reason
  `You must call -[CSCustomAttributeKey initWithKeyName...]` (measured). The port raises the same.

## Equality, hashing, copying

- Two keys are equal when their names are equal, whatever their flags (measured: same name, other flags, equal and hashed alike).
  The name is compared case-sensitively.
- A key is also equal to a string of its name, mutable or not (measured). This is the host's comparison: the key's name is
  compared with the other object, so a string equal to the name is equal to the key. A string of another case, a number and nil
  are not.
- The hash is the hash of the name.
- `copy` gives a new key with the same name and the same four flags, and the copy is equal to the original (measured).

## Text

`description` and `debugDescription` read `<CSCustomAttributeKey:ADDRESS NAME`, with no closing angle bracket. That is the same
form as CSPerson's description (see `facts/CoreSpotlight/Values.md`), measured here as well.

## Coding

The class supports secure coding (measured YES). A key coded and decoded keeps its name and its four flags. The port decodes with
`decodeObjectForKey:` and `decodeBoolForKey:`, the coder calls of the earliest release, as `Values.md` explains for CSPerson.
The archive's key names are the port's own; they are not measured against the host.

What the host does with an archive whose name it would refuse is not measured. The port answers nil for such an archive, because
its decoder goes through the same validation as the initializer.

## What is not here

The attribute set's custom-value methods (`setValue:forCustomKey:` and `valueForCustomKey:`), which take a key of this class, and
the search-side queries on a key, are not part of this change.
