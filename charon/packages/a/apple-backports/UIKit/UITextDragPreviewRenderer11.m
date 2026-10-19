#import <UIKit/UIKit.h>
#import <UIKit/NSLayoutManager.h>
#import <UIKit/UITextDragPreviewRenderer.h>

// The picture of a dragged range of text, and the three rectangles it is drawn in.
//
// The renderer measures the range with the release's own layout manager, so the rectangles it reports
// are the ones TextKit already has for those glyphs, and the picture is drawn by asking that layout
// manager to draw them: nothing here invents geometry a text view would disagree with.
//
// iOS 11, so the range is guarded: a renderer made with no layout manager or an empty range has no
// picture, and says so with nil rather than a blank one.

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wobjc-property-implementation"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation UITextDragPreviewRenderer {
@private
    NSLayoutManager *_layoutManager;
    UIImage *_image;
    CGRect _firstLineRect;
    CGRect _bodyRect;
    CGRect _lastLineRect;
}

// The designated initialiser. `unifyRects` says whether a range that covers one line is drawn as a
// body rather than as a first line: the three rectangles are the first line, the body between the
// first and the last, and the last, and a single line has no body of its own unless it is given one.
- (instancetype)initWithLayoutManager:(NSLayoutManager *)layoutManager
                                range:(NSRange)range
                          unifyRects:(BOOL)unifyRects
{
    if ((self = [super init])) {
        _layoutManager = layoutManager;
        [self charon_measureRange:range unify:unifyRects];
    }
    return self;
}

- (instancetype)initWithLayoutManager:(NSLayoutManager *)layoutManager range:(NSRange)range
{
    return [self initWithLayoutManager:layoutManager range:range unifyRects:NO];
}

// The rectangles, from the layout manager's own geometry: the bounding rectangle of the range, and
// the used rectangle of the line fragments at each end. A range of no glyphs, or a renderer with no
// layout manager, has none of the three.
- (void)charon_measureRange:(NSRange)range unify:(BOOL)unify
{
    // (void) so the two early exits below are unmistakably exits and not a value.
    if (!_layoutManager || range.location == NSNotFound || !range.length ||
        [_layoutManager numberOfGlyphs] == 0) {
        _firstLineRect = CGRectZero;
        _bodyRect = CGRectZero;
        _lastLineRect = CGRectZero;
        return;
    }
    NSUInteger first = [_layoutManager glyphIndexForCharacterAtIndex:range.location];
    if (first >= [_layoutManager numberOfGlyphs])
        return;
    NSRange lineRange = NSMakeRange(NSNotFound, 0);
    _firstLineRect = [_layoutManager lineFragmentRectForGlyphAtIndex:first effectiveRange:&lineRange];

    NSUInteger last = [_layoutManager numberOfGlyphs] - 1;
    NSRange lastRange = NSMakeRange(NSNotFound, 0);
    _lastLineRect = [_layoutManager lineFragmentRectForGlyphAtIndex:last effectiveRange:&lastRange];

    if (unify) {
        // One rectangle for the whole range, as the header's unifying means.
        CGRect whole = CGRectUnion(_firstLineRect, _lastLineRect);
        _bodyRect = whole;
        _firstLineRect = CGRectZero;
        _lastLineRect = CGRectZero;
        return;
    }

    CGRect body = CGRectMake(_firstLineRect.origin.x, CGRectGetMaxY(_firstLineRect),
                             _lastLineRect.size.width,
                             CGRectGetMinY(_lastLineRect) - CGRectGetMaxY(_firstLineRect));
    _bodyRect = CGRectIsNull(body) || CGRectIsEmpty(body) ? CGRectZero : body;
}

// Move the three rectangles by the text's origin, in place. A preview drawn at a position the text is
// not already in is asked for this, so the line that begins the drag starts at the caret rather than
// at its own line's origin.
- (void)adjustFirstLineRect:(inout CGRect *)firstLineRect
                    bodyRect:(inout CGRect *)bodyRect
                lastLineRect:(inout CGRect *)lastLineRect
                 textOrigin:(CGPoint)origin
{
    // An empty rectangle is left where it is. Which kind of nothing it is was measured, not
    // assumed: the host's own renderer, asked over a range it unified, reports firstLineRect and
    // lastLineRect as empty and not null -- CGRectIsNull is 0 and CGRectIsEmpty is 1 for all three
    // (tests/backports/host/renderer-differential, the firstShape/lastShape records) -- and it
    // leaves those rects untouched by the text origin. A CGRectIsNull test would never have fired
    // here and would have disagreed with the system in the other direction.
    if (firstLineRect && !CGRectIsEmpty(*firstLineRect))
        firstLineRect->origin = CGPointMake(firstLineRect->origin.x + origin.x,
                                            firstLineRect->origin.y + origin.y);
    if (bodyRect && !CGRectIsEmpty(*bodyRect))
        bodyRect->origin = CGPointMake(bodyRect->origin.x + origin.x,
                                       bodyRect->origin.y + origin.y);
    if (lastLineRect && !CGRectIsEmpty(*lastLineRect))
        lastLineRect->origin = CGPointMake(lastLineRect->origin.x + origin.x,
                                            lastLineRect->origin.y + origin.y);
    _firstLineRect = firstLineRect ? *firstLineRect : _firstLineRect;
    _bodyRect = bodyRect ? *bodyRect : _bodyRect;
    _lastLineRect = lastLineRect ? *lastLineRect : _lastLineRect;
}

- (NSLayoutManager *)layoutManager
{
    return _layoutManager;
}

- (CGRect)firstLineRect
{
    return _firstLineRect;
}

- (CGRect)bodyRect
{
    return _bodyRect;
}

- (CGRect)lastLineRect
{
    return _lastLineRect;
}

// The picture, drawn once with the layout manager's own glyph drawing into an image the size of the
// three rectangles. Each line fragment is drawn in its own place, so the text in the picture is where
// the text is in the view.
- (UIImage *)image
{
    if (_image)
        return _image;
    if (!_layoutManager)
        return nil;
    CGRect bounds = CGRectUnion(CGRectUnion(_firstLineRect, _bodyRect), _lastLineRect);
    if (CGRectIsNull(bounds) || CGRectIsEmpty(bounds))
        return nil;
    UIGraphicsBeginImageContextWithOptions(bounds.size, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) {
        UIGraphicsEndImageContext();
        return nil;
    }
    CGContextTranslateCTM(context, -bounds.origin.x, -bounds.origin.y);
    NSUInteger glyphs = [_layoutManager numberOfGlyphs];
    NSRange lineRange = NSMakeRange(NSNotFound, 0);
    NSUInteger glyph = 0;
    while (glyph < glyphs) {
        CGRect rect = [_layoutManager lineFragmentRectForGlyphAtIndex:glyph effectiveRange:&lineRange];
        if (!lineRange.length)
            break;
        [_layoutManager drawBackgroundForGlyphRange:NSMakeRange(glyph, lineRange.length) atPoint:rect.origin];
        [_layoutManager drawGlyphsForGlyphRange:NSMakeRange(glyph, lineRange.length) atPoint:rect.origin];
        glyph = NSMaxRange(lineRange);
    }
    _image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return _image;
}

@end
