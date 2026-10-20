# How complete is it

Two numbers, and they measure different things.

- **By name:** 504 of Apple's 592 public types and every one of the 311 `View` modifier names are present; each API
  that iOS 6 cannot honour is *declared*, writes a line to a journal when used, and is listed with its reason. Nothing
  is a silent no-op — the build fails if an ignored or simplified API is not named in the ledger.
- **By declaration:** comparing Apple's SwiftUI interface for iOS 16.4 with this module signature by signature
  (`frameworks/SwiftUI/tools/api-surface.lua`) finds, of the 4740 declarations of Apple's public interface, **3233 (68%) callable as Apple writes them, 314 (7%) present with a different signature, 927 (20%) absent and still to write, and 266 (6%) of types that iOS 6 or a phone cannot have, listed with a reason in `frameworks/SwiftUI/tests/data/api/not-applicable.txt`**.
  A good part of the absent ones has nothing to correspond to on iOS 6 (widgets, documents, windows, accessibility
  rotors); the rest is the work queue.

The gap between the two is not hidden: counting by name alone overstated completeness, which is why the second measure
exists.
