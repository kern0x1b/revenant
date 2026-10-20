#import <UIKit/UIKit.h>
#import <UIKit/NSLayoutManager.h>
#import <UIKit/UITextDragPreviewRenderer.h>

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

- (instancetype)initWithLayoutManager:(NSLayoutManager *)layoutManager
                                range:(NSRange)range
                          unifyRects:(BOOL)unifyRects
{
    if ((self = [super init])) {
        _layoutManager = layoutManager;
        [self revenant_measureRange:range unify:unifyRects];
    }
    return self;
}

- (instancetype)initWithLayoutManager:(NSLayoutManager *)layoutManager range:(NSRange)range
{
    return [self initWithLayoutManager:layoutManager range:range unifyRects:NO];
}

- (void)revenant_measureRange:(NSRange)range unify:(BOOL)unify
{
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

- (void)adjustFirstLineRect:(inout CGRect *)firstLineRect
                    bodyRect:(inout CGRect *)bodyRect
                lastLineRect:(inout CGRect *)lastLineRect
                 textOrigin:(CGPoint)origin
{
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
