#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const CGFloat CharonUnbounded = 100000;

static void charon_draw_in_rect(NSString *self, SEL selector, CGRect rect, NSDictionary<NSString *, id> *attributes)
{
    [[[NSAttributedString alloc] initWithString:self attributes:attributes] drawWithRect:rect options:NSStringDrawingUsesLineFragmentOrigin context:nil];
}

@interface CharonStringDrawing : NSObject
@end

@implementation CharonStringDrawing

+ (void)load
{
    if ([NSString instancesRespondToSelector:@selector(sizeWithAttributes:)])
        return;
    Method native = class_getInstanceMethod([NSString class], @selector(drawInRect:withAttributes:));
    if (native)
        method_setImplementation(native, (IMP)charon_draw_in_rect);
}

@end

@implementation NSString (CharonDrawing7)

- (NSAttributedString *)charon_attributed:(NSDictionary<NSString *, id> *)attributes
{
    return [[NSAttributedString alloc] initWithString:self attributes:attributes];
}

- (CGSize)sizeWithAttributes:(NSDictionary<NSString *, id> *)attributes
{
    return [self boundingRectWithSize:CGSizeMake(CharonUnbounded, CharonUnbounded) options:NSStringDrawingUsesLineFragmentOrigin attributes:attributes context:nil].size;
}

- (CGRect)boundingRectWithSize:(CGSize)size options:(NSStringDrawingOptions)options attributes:(NSDictionary<NSString *, id> *)attributes context:(NSStringDrawingContext *)context
{
    if (!self.length) {
        CGRect line = [[@" " charon_attributed:attributes] boundingRectWithSize:size options:options context:nil];
        line.size.width = 0;
        return line;
    }
    return [[self charon_attributed:attributes] boundingRectWithSize:size options:options context:context];
}

- (void)drawAtPoint:(CGPoint)point withAttributes:(NSDictionary<NSString *, id> *)attributes
{
    [[self charon_attributed:attributes] drawAtPoint:point];
}

- (void)drawInRect:(CGRect)rect withAttributes:(NSDictionary<NSString *, id> *)attributes
{
    charon_draw_in_rect(self, _cmd, rect, attributes);
}

- (void)drawWithRect:(CGRect)rect options:(NSStringDrawingOptions)options attributes:(NSDictionary<NSString *, id> *)attributes context:(NSStringDrawingContext *)context
{
    [[self charon_attributed:attributes] drawWithRect:rect options:options context:context];
}

@end
