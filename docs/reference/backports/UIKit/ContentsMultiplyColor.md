# `contentsMultiplyColor` on iOS 6

`contentsMultiplyColor` is a `CALayer` property that multiplies the layer's contents by a colour when the layer is drawn. It
is not public: no SDK header declares it, and an application reaches it by key-value coding
(`layer.setValue(color, forKey: "contentsMultiplyColor")`). QuartzCore of iOS 6.1.3 has no such property: the dyld cache holds
no string of that name, `CALayer` stores the value under the key like any unknown key, and nothing is drawn differently.

## Why it is here

Telegram 13 tints its text and icons this way: `layerTintColor` in `Display/Source/UIKitUtils.swift` reads and writes the key,
and `MultilineTextComponent`, `ASImageNode`, the navigation buttons, the chat action bubbles and about thirty other files set it.
`Transition.setTintColor(layer:color:)` (ComponentFlow) and `ContainedViewLayoutTransition` also animate the key path. The text is
drawn white and the tint gives it its colour, so without the property the text stays white: the "Edit" button of an alert on an
iPhone 4S with iOS 6.1.3 was white on the alert's light panel (`#D9D9DA`, a contrast of about 1.4 to 1). One property in the
backports fixes every caller, and any other application that uses the key.

## What iOS 13 and later do

Measured on macOS 27 (the QuartzCore of iOS 13 and later has the same property), by rendering layers with `CARenderer` into a
Metal texture and reading the pixels:

- Each premultiplied pixel of the contents is multiplied by the premultiplied colour: white times `(0.4, 0.6, 1.0, 0.7)` gives
  `(71, 107, 179, 179)`, a pixel `(51, 204, 128, 255)` times opaque red gives `(51, 0, 0, 255)`.
- Only the contents are tinted. The layer's background colour, border and sublayers are drawn as they are.
- A layer that never had the key set answers opaque white (`defaultValueForKey:` is white too). After the key is set to `nil`, it
  answers `nil`.
- Setting the key has no implicit animation (`actionForKey:` answers `nil`), and the key can be animated explicitly.

## What the backports do

`frameworks/Backports/src/UIKit/CALayer+ContentsMultiplyColor.m`, in `libUIKitBackports.dylib`, adds the accessors
`contentsMultiplyColor` and `setContentsMultiplyColor:` to `CALayer` as category methods. The library adds them only where
`CALayer` lacks them, before any code of the application runs, so iOS 13 and later keep their own property. Key-value coding
finds the setter: `setValue:forKey:` with this key calls it on iOS 6.1.3 (measured below). `CALayer` remembers per key whether it
has an accessor, so the methods have to exist before the key is first set; the library's constructor adds them at load.

- The colour is kept with the layer (an associated object). The getter answers it, opaque white for a layer that never had it set,
  and `nil` after it was set to `nil`. A `UIColor` given by key-value coding is taken as its `CGColor`. Any other value counts as `nil`.
- A colour other than `nil` or opaque white puts the QuartzCore filter `multiplyColor` of iOS 6, named
  `revenantContentsMultiplyColor`, first in the layer's `filters`, with the colour as its `inputColor`. A new colour changes
  `filters.revenantContentsMultiplyColor.inputColor`. `nil` or opaque white removes the filter, so a layer without a tint carries
  nothing. The change is made with implicit actions disabled, as on iOS 13.
- The filter stays when the application sets `filters` itself: once a layer has a tint, `setFilters:` puts the tint first and keeps
  the application's filters behind it, with one tint even when the application writes back the array it read.
- An animation whose key path is `contentsMultiplyColor` (`CABasicAnimation`, `CAKeyframeAnimation`) is added as a copy with the key
  path `filters.revenantContentsMultiplyColor.inputColor`, and `UIColor` values in it are taken as their `CGColor`. The filter is put
  on the layer first if it has none, with the layer's colour or white.

## Measured on the phone

iPhone 4S, iOS 6.1.3, with a probe library injected into Calculator: a window of test layers over the app, read back with
`UIGetScreenImage`, on a white screen. The rows were the four pixels above, scaled up:

| Layer | Pixels on white | iOS 13 composited on white |
| ----- | --------------- | -------------------------- |
| plain | `255,255,255` `255,255,255` `51,204,128` `195,175,165` | |
| `multiplyColor` red | `255,0,0` `255,127,127` `51,0,0` `195,155,155` | the same |
| `multiplyColor` `(0.4, 0.6, 1.0, 0.7)` | `148,184,255` `202,220,255` `91,163,166` `196,193,192` | `147.5,183.5,255` and the rest within one level |
| drawn layer (`drawLayer:inContext:`, a backing store), red | `255,0,0` `255,127,127` `51,0,0` | the same |
| layer at opacity 0.5, red | `255,127,127` `255,191,191` `153,127,127` | the same |

The filter is drawn by the render server of iOS 6 for image contents and for the backing store of a drawn layer, which is what
Telegram's text is (`TextView` draws in `draw(_:)`). `filters = nil` removes it. Setting
`filters.<name>.inputColor` by key path changes it, and a `CABasicAnimation` on that key path is drawn. On iOS 6.1.3, `setValue:forKey:`
with `contentsMultiplyColor` calls an accessor that was added with `class_addMethod`, and `valueForKey:` reads it back.
`defaultValueForKey:` answers `nil` there, and the backports do not change it.

## Cost

The filter is applied by the GPU when the layer is composited. No pixel is computed on the CPU and nothing is drawn again. Measured
on the same phone with 80 text layers of 150 by 20 points, each moving all the time (a position animation), 9.6 s per case, two runs:

| Case | GPU (`Device Utilization %`) | backboardd CPU | Frames |
| ---- | ---------------------------- | -------------- | ------ |
| white text, no tint | 12.7 %, 13.5 % | 24.4 %, 24.7 % | 60 |
| white text with the filter | 16.9 %, 16.9 % | 25.8 %, 25.9 % | 60 |
| text drawn in the colour | 13.4 %, 13.6 % | 24.7 %, 24.8 % | 60 |

The application's CPU was 1.5 % in every case. Eighty moving tinted layers cost about 4 points of GPU and 1 point of render-server
CPU, and no frame. A layer whose tint is `nil` or white costs nothing. Setting the property costs an associated-object store and,
when the filter is added or removed, one `filters` assignment.

The two hooks are installed the first time any layer of the process sets the property, not before. Then every `setFilters:` of a
layer that has a tint stored rebuilds the array, and every `setFilters:` of another layer costs one associated-object lookup.
Every `addAnimation:forKey:` costs one class check and, for a property animation, one comparison of its key path.

## Scope: who is affected

The property lives in `libUIKitBackports.dylib` and exists in every process that loads it: any application built with the
Revenant toolchain that links the Backports. Stock iOS 6 applications do not load the library. It acts only on layers whose
`contentsMultiplyColor` an application sets. A process that never sets it gets the two accessors and nothing else.

What an application sees that differs from iOS 13:

- The filter tints the whole layer as it is composited, not only its contents: a background colour, a border and the sublayers of a
  tinted layer are multiplied too. On the phone, a red tint on a layer with a green background and a blue sublayer turned the
  background under a half-transparent pixel to `128,0,0` (iOS 13: `128,127,0`) and the sublayer to black. A tinted layer with
  only contents, which is how Telegram uses the property for text and icons, is drawn as on iOS 13.
- `filters` lists the filter named `revenantContentsMultiplyColor` while a tint is set.
- An animation to `nil` or white keeps a white filter on the layer after it ends, until the property is set again.
- A presentation layer answers white: the colour is kept on the model layer.

## Tests

`frameworks/Backports/tests/QuartzCore/contents_multiply_color_test.m` (host, target
`QuartzCoreBackports_contents_multiply_color_test`) renders layers with `CARenderer` and compares the backport with the system's own
property of macOS, whose accessors it moves onto a subclass for the comparison. While rendering, it reads `CALayer`'s property
through the system's getter, because the host draws the system property as well and would multiply twice. It checks image and
drawn contents times five colours (opaque, translucent, half, clear, a quarter white), the default and `nil` answers, the white tint
that adds no filter, a new colour, the application's filters kept around the tint, and basic and keyframe animations of the key. 33
checks, and the negative run fails.
