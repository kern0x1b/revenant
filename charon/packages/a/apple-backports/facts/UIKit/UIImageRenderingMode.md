# Template images, iOS 7.0

An image made with `-imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate` is shown as a mask: its alpha channel
is kept and its colour is the tint colour of the view that shows it. `UIImageRenderingModeAlwaysOriginal` and the
automatic mode show the image as it is in a plain image view.

Source: the host's own UIKit under Mac Catalyst, in an application with a window, recorded by `host/template/run.sh`
from `device/template-cases.m` (twenty-one records of the pixel a view draws) and read again on an iPhone 4S and an
iPad 2 running 6.1.3 by `device/template.m`, which holds each pixel to within three in a channel.

## What the system does, and the port with it

- A template image is drawn in the tint colour with the alpha of each pixel: a pixel of 50% alpha in green is
  `0,128,0` at alpha 128 in the premultiplied bitmap; the image's own colours are gone. The view's `image` answers the
  image that was set, template mode and all, not a tinted copy.
- The colour is `tintColor` of the image view: its own, or the one of a superview, or the default. It follows a change of
  the view's tint at once, a change made above the view, the view moving under another one, and dimming of the tint
  (see `UIViewTintColor.md`); the image is drawn again each time.
- `highlightedImage` is filled the same way and the highlighted view draws it, and `initWithImage:` and
  `initWithImage:highlightedImage:` fill a template as `-setImage:` does. Setting nil clears the view.
- A resizable image made from a template, or one with alignment insets, is a template as well, and stays resizable.
- A button's image view is such a view: a custom button that has a template image for a state draws it in the button's
  `tintColor`, and changes with it; `imageForState:` answers the image that was set. An image that is not a template is
  drawn as it is.

## What the port does to get there

The release has no template pass. The port replaces `-setImage:`, `-image`, `-setHighlightedImage:`, `-highlightedImage`,
the two `initWithImage` methods, `-didMoveToSuperview` and `-tintColorDidChange` on `UIImageView`, on a release that has no
`-imageWithRenderingMode:`, and keeps the image that was set beside the tinted copy the view shows. The copy is made by
drawing the image and filling its shape with the colour. `-resizableImageWithCapInsets:`, `-resizableImageWithCapInsets:resizingMode:`
and `-imageWithAlignmentRectInsets:` of `UIImage` are replaced so that their result keeps the mode. `UIButton` has a
`-setTintColor:` of its own on iOS 6, which the tint of the views below it never saw; the port calls the hierarchy's
setter first, and then the release's own.

## What differs

- The default tint is blue `0,122,255` as on iOS 7 and later; the host's is the system blue of its own release, so the test
  gives every view a colour of its own.
- A dimmed tint is grey at four fifths of the alpha on both, and the grey differs: see `UIViewTintColor.md`, where the
  release's CoreGraphics gives another grey than the newest; the test compares only that the pixel is grey with that alpha.
- The automatic mode is drawn as the original in a plain image view on both. In a button of the system type, and in the
  bars, the newest UIKit makes an automatic image a template; iOS 6 has no such button (the type value is the rounded
  rectangle) and its bars draw their images as masks already, so the port does nothing there.
- An image that is drawn with `-drawInRect:` is drawn as it is, template or not.
