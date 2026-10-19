# UIGraphicsRendererContext

Introduced in iOS 10.0. The CoreGraphics context a drawing block is handed, with
a few drawing calls of its own.

Source: UIKit of the armv7s cache of iOS 10.3.4.

| member | behaviour |
|---|---|
| `-initWithCGContext:format:` | private; keeps the context and a **copy** of the format. |
| `-CGContext`, `-format` | the two it was made with. |
| `-fillRect:` | `-fillRect:blendMode:` with `kCGBlendModeNormal`. |
| `-fillRect:blendMode:` | the current blend mode is read; it is set only if it differs, `CGContextFillRect` is called, and it is put back only if it was changed. |
| `-strokeRect:` | `-strokeRect:blendMode:` with `kCGBlendModeNormal`. |
| `-strokeRect:blendMode:` | see below. |
| `-clipToRect:` | `CGContextClipToRect`. |

## Stroking insets by half the line width

`-strokeRect:blendMode:` does not stroke the rectangle it is given. It reads the
context's current line width and strokes `CGRectInset(rect, width/2, width/2)`,
so the stroke lies **inside** the rectangle instead of straddling its edge, which
is what `CGContextStrokeRect` on its own does. With a line width of 4 a stroke of
a 20-point square covers 16 points plus the 4 of the line, not 24.

It also calls `CGContextSetLineWidth` with the width it read at the end, every
time, even though it never changed it. That is Apple's own code and is kept: a
`CGContextSetLineWidth` is not free of consequence in a context whose line width
was set through a path Charon does not see.

Both private members, `-__createsImages` and `-set__createsImages:`, are carried:
the renderer sets the flag from `-allowsImageOutput` and the base renderer pushes
the UIKit context only when it is set.
