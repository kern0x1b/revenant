# UIGraphicsRenderer

Introduced in iOS 10.0. The base of the renderers: it owns the format, makes the
context and runs the drawing block.

Source: UIKit of the armv7s cache of iOS 10.3.4.

| member | behaviour |
|---|---|
| `-init` | `-initWithBounds:` with `CGRectZero`. |
| `-initWithBounds:` | `-initWithBounds:format:` with `[UIGraphicsRendererFormat defaultFormat]`. Each subclass overrides this with its own format class. |
| `-initWithBounds:format:` | designated; copies the format and sets the bounds on the copy. |
| `-format` | the copy, not a further copy. |
| `-allowsImageOutput` | `NO` here. |
| `+rendererContextClass` | `UIGraphicsRendererContext`. |
| `+contextWithFormat:` | `NULL` here; a subclass makes the context. |
| `+prepareCGContext:withRendererContext:` | nothing here. |
| `-pushContext:` / `-popContext:` | `UIGraphicsPushContext` / `UIGraphicsPopContext`, but only when the context's private `__createsImages` is set. |

## Running the drawing

`-runDrawingActions:completionActions:error:` passes `self.format` to
`-runDrawingActions:completionActions:format:error:`, which runs in this order:

1. `[[self class] rendererContextClass]` must be a subclass of
   `UIGraphicsRendererContext`, or `NSInvalidArgumentException` is raised:
   `*** Attempting to use a Class (%@) that is not a UIGraphicsRendererContext subclass as a UIGraphicsRenderer context.`
2. the context is made with `+contextWithFormat:`. A `NULL` answer fills the
   `error` with domain `NSCocoaErrorDomain`, **code 0**, and
   `NSLocalizedDescriptionKey` of `Could not create CGContextRef`, and `NO` is
   returned. The drawing block is not run.
3. the renderer context is made, its `__createsImages` set from
   `-allowsImageOutput`, and `+prepareCGContext:withRendererContext:` called.
4. `-pushContext:`, the drawing block, `-popContext:`, then the completion block.
5. the CGContext is released and `YES` returned.

## What Charon does not carry

UIKit keeps a pool of CGContexts to hand out again: `+initialize` opens a
dispatch queue named `com.apple.UIKit.UIGraphicsRenderer.reuseCacheAccess` and a
memory pressure source named
`com.apple.UIKit.UIGraphicsRenderer.memoryPressureResponse`, and observes the
application going to the background to empty the pool.

That pool needs `_dispatch_source_type_memorypressure` and
`dispatch_queue_attr_make_with_autorelease_frequency`, and those are the only two
symbols of this whole family that iOS 6 does not export. It is not carried.
Nothing of it is declared API: no method reaches it, and the only difference it
makes is that every context here is freshly made rather than possibly reused,
which is strictly the safer of the two. Everything else the family needs -
including the private `CGBitmapGetAlignedBytesPerRow`, `CGContextGetBlendMode`
and `CGContextGetLineWidth` - iOS 6.0 exports.
