# -[NSTextList isOrdered], iOS 16.0

## The property name is not a selector

`NSTextList.h:55`:

```objc
// Yes if markerFormat is an ordered text list type
@property (readonly, getter=isOrdered) BOOL ordered API_AVAILABLE(macos(13.0), ios(16.0), tvos(16.0)) API_UNAVAILABLE(watchos);
```

`ordered` and `isOrdered` are two different strings and only the getter exists as a selector. The row
was spelled `NSTextList.ordered`; it is now spelled `NSTextList.isOrdered`, which is the getter, and
that is the spelling `spellings()` (`backports.lua:1571`) resolves to `-[NSTextList isOrdered]` — the
selector the object actually exports. `property_of()` bridges getter → property, not the other way,
so a row written with the property name asks the check for a selector that exists in neither the
release, nor the SDK, nor the port.

This is the shape `UIScrollView.isScrollAnimating` / `isZoomAnimating` and `MPMediaItem.isPreorder`
settled in this tree before, and the row follows them rather than inventing a third answer.

## What the release carries, measured

```
CHARON_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/6.1.3/dyld_shared_cache_armv7 > inv-6.1.3.tsv
CHARON_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/12.0/dyld_shared_cache_arm64  > inv-12.0.tsv
CHARON_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/16.0/dyld_shared_cache_arm64e > inv-16.0.tsv
awk -F'\t' '$1=="class" && $2=="NSTextList" {print $3, $5}' inv-6.1.3.tsv inv-12.0.tsv inv-16.0.tsv
```

```
6.1.3  UIFoundation  24 selectors  isOrdered: none  ordered: none  _isOrdered: present  controls: markerFormat, startingItemNumber, initWithMarkerFormat:options: all present
12.0   UIFoundation  25 selectors  isOrdered: none  ordered: none  _isOrdered: present  controls: as above
16.0   UIFoundation  28 selectors  isOrdered: -isOrdered  ordered: none  _isOrdered: present
```

The class is present on all three rungs, holding `-initWithMarkerFormat:options:`,
`-markerFormat`, `-markerForItemNumber:` and `-startingItemNumber`, so the reader is reading the
class and its selectors; the zero on every public spelling of the property is the release's.

## What the port does, and why it asks a private method

The release computes the answer already, and has for far longer than 16.0: its `NSTextList` carries
`-_isOrdered` at both band ends, and the 16.0 release carries both it and the public getter. So the
public getter is the release's own answer, and this object forwards to the one the release has rather
than storing a second copy of a value the release already keeps — a stored flag would be a second
source of truth for a property the release answers itself, and would go stale the moment the marker
format changed.

The private call is deliberate and is written down here with the measurement that forces it: there is
no public mechanism below 16.0, and `-[NSTextList _isOrdered]` is not declared in any SDK header, so
the call goes through `objc_msgSend` with a typed return — the same shape
`CharonConfigurationHost.m:267` and `UIApplicationDelegate+OpenURLOptions.m:28` use. A release whose
`NSTextList` lacks the selector answers NO rather than trapping, which is the honest answer for a list
that cannot say. On a device the port runs, the selector is present (measured above), so the guard is
never the path taken there.

Nothing else is carried for this row: `NSTextListMarkerFormat`'s own public surface on this release
is the marker format the list is made from, and no reader of that format is written.