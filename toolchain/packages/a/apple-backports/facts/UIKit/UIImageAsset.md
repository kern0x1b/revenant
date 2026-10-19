# UIImageAsset, iOS 8

Introduced in iOS 8.0 as the image set an asset catalogue gives for one name: an image registered for each trait
collection or each `UIImageConfiguration`, handed back for whichever variant fits. The SDK 16.4 header is the
contract: all eleven members are 8.0 in `declarations.tsv`.

The release has no asset catalogue to draw these from, and nothing in the release reads an asset on its own. The
class is carried so that an application can build and use one itself. The port keeps the variants in registration
order and answers by the rule below.

## Source of the answers

Measured on Mac Catalyst with one source, `tests/backports/host/uikit-imageasset/matrix.m`: every single
registration, every ordered pair of registrations with a lookup at every key, every unregister of every key over one
registration and over every pair, the refusals, and the nil cases. That is 67136 lines of output. The port is built from
the same source with its classes renamed beside the system's, and its output equals the host's on every line; the
planted control (one default changed in a scratch copy) makes the comparison fail. The rule below is what those lines
say. It was fitted to them, so a key the matrix does not hold (a scale-0 key looked up, a second registration of an
equal key) is not covered by a measurement.

The keys are the host's own trait collections over display scale 1, 2 and 3, idiom, style and layout direction, and
the symbol configurations of point size 12 and 99, bold weight and large scale. Each variant is an image of a known
width, so an answer names which variant it is and at what scale.

## Keys and what a key names

- A trait collection names a scale, an idiom, a style and a layout direction. It names only what was given: an idiom
  or style left out is unspecified, and a collection made without a display scale has scale 0.
- A configuration names none of them. It is held at scale 1 for the rule.
- A lookup reads what it does not name as the current environment: the display scale and idiom of the running device,
  and style light. On the Catalyst host the current values are scale 2 and pad, the measured instance here. A nil
  lookup is the same as a lookup that names nothing.

## The rule

A lookup answers one variant, or nil. The variants are the registered keys, in registration order.

1. A key is a candidate unless it names an idiom the lookup does not have, or a style the lookup does not have. A
   layout direction never excludes a key. A key that names no idiom or no style is always a candidate on that trait.
2. Among the candidates the best one is taken, compared in this order:
   a. a key that names a style beats one that does not;
   b. a key that names an idiom beats one that does not;
   c. the scale: a key whose scale equals the lookup's scale beats any key whose scale does not; of the others the
      highest scale wins. A key that names no scale counts as scale 1;
   d. a key that names a layout direction beats one that does not.
3. Equal keys rank equal, and then the one registered last wins. So two configurations answer the later one, and of
   two variants that name nothing but a scale of the same value, the later one.
4. No candidate, nil.

The answer is a new image with the same pixels, at the scale of the key it was registered for. A configuration, or a
key that names no scale, keeps the image's own scale. The answer is never the registered object: no answer in the
output is one.

The answers for the registrations of two variants, one row each. The first registered is variant 1; a cell is the
variant that answers and the scale of its copy, so `2@3` is variant 2 at scale 3. The nil lookup reads the current
environment (on the host: scale 2, pad, light). Every row is one pair of the matrix, and the rule above gives each cell.

| registered first, second            | lookup at scale 1 | at scale 2 | at scale 3 | nil lookup |
|-------------------------------------|-------------------|------------|------------|------------|
| scale 1, scale 2                    | 1@1               | 2@2        | 2@2        | 2@2        |
| scale 2, scale 1                    | 2@1               | 1@2        | 1@2        | 1@2        |
| scale 2, scale 3                    | 2@3               | 1@2        | 2@3        | 1@2        |
| scale 3, scale 2                    | 1@3               | 2@2        | 1@3        | 2@2        |
| scale 1, scale 3                    | 1@1               | 2@3        | 2@3        | 2@3        |
| scale 3, scale 1                    | 2@1               | 1@3        | 1@3        | 1@3        |
| configuration, configuration        | 2@1               | 2@1        | 2@1        | 2@1        |
| configuration, scale 1              | 2@1               | 2@1        | 2@1        | 2@1        |
| scale 1, configuration              | 2@1               | 2@1        | 2@1        | 2@1        |
| configuration, scale 2              | 1@1               | 2@2        | 2@2        | 2@2        |
| scale 2, configuration              | 2@1               | 1@2        | 1@2        | 1@2        |
| scale 1, scale 1 light              | 2@1               | 2@1        | 2@1        | 2@1        |
| scale 1 light, scale 1              | 1@1               | 1@1        | 1@1        | 1@1        |
| scale 2 pad, scale 1 light          | 2@1               | 2@1        | 2@1        | 2@1        |
| scale 1, scale 2 pad                | 2@2               | 2@2        | 2@2        | 2@2        |
| scale 2 pad, scale 1                | 1@2               | 1@2        | 1@2        | 1@2        |
| scale 1 phone, scale 2 pad          | 2@2               | 2@2        | 2@2        | 2@2        |
| scale 2 dark, scale 1               | 2@1               | 2@1        | 2@1        | 2@1        |
| scale 1, scale 2 dark               | 1@1               | 1@1        | 1@1        | 1@1        |

Read off the table: the scale rows are 2c alone; "configuration, scale 2" and "scale 2, configuration" show a
configuration holding scale 1 (it wins a scale-1 lookup and loses a scale-2 one); "scale 1, scale 2 pad" shows that an
idiom the lookup reads as its default beats an exact scale (2a-2c); "scale 1 light, scale 1" shows the named style
beating the unnamed one at the same scale.

Dark and light: a key that names dark is a candidate only for a lookup that names dark, since the default style is
light. A key that names light is a candidate for a lookup that names light or names no style.

## Unregister

- A nil key removes nothing.
- An unregister names a rendition: its scale (a key with no scale names scale 1), its idiom, its style and its layout
  direction. It removes every registered variant whose rendition is the same. A configuration is the rendition of
  scale 1 with nothing else named, so one configuration's unregister removes the other configuration too, when both are
  held.
- Measured: a variant registered for scale 1 with no idiom or style is removed by an unregister of scale 1, of a
  configuration, or of a collection that names scale 1 and nothing else. It stays for an unregister of scale 2, or of a
  collection that names a style (a light unregister does not remove the unnamed-style variant). A scale-1 phone variant is removed
  by an unregister of a phone collection that names no scale, which is the rendition of scale 1 and phone.

## Registration errors and the refusals

- A nil trait collection and a nil configuration raise `NSInternalInconsistencyException`, reason `scale must be > 0`.
- A trait collection with a negative scale raises `NSInternalInconsistencyException`, reason `scale 65535 in rendition
  key does not match with scale -1.000000 passed in the image description` for a scale of -1. The number is -1 read as
  an unsigned 16-bit value; only -1 is measured, and the port reads other negative scales the same way without a
  measurement.
- A scale of 0 registers without an error. So does a trait collection that names no scale, which has scale 0. Neither
  was measured as a key looked up on its own; the rule counts them as scale 1, as a configuration is counted.
- A nil image registers nothing and leaves the variant held for the key as it was.
- An unregister of nil removes nothing.
- A fresh asset answers nil for every lookup.
- `supportsSecureCoding` is YES.

Not measured: a second registration of a key that is equal to one held (the port replaces the held image, as the
release's `isEqual:` would suggest, and the matrix never does it); the keyed-archive round trip's lookup on a decoded
asset, beyond that it returns an image; any key whose scale is not 1, 2 or 3 or the registered collections with a
display scale 0 looked up on their own.

## Caveat on the defaults

The current environment is the running device's: its display scale and idiom, and light style. The Catalyst host's
values (scale 2, pad, light) are the ones measured here, read from the lookups that name nothing; the port answers
the same on the host. The 6.1.3 emulator (iPhone4,1, Shade) reads phone at scale 2: a probe that registers a phone
variant of 10 px and a pad variant of 20 px at scale 2 gets the 10 px one from a nil lookup, and the named lookups
get their own (10 px and 20 px). That is the one device measurement; no hardware is measured here. An application
that names every trait in its lookups does not depend on them.

## Device

Not run on a device. The asset that the release draws from its own catalogue is not the one a port keeps, so an
application that reads a catalogue image through an asset would see the release's own answer; this port's asset is
the application's own store.
