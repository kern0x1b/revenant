#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const CGFloat RevenantUnbounded = 100000;

static void revenant_draw_in_rect(NSString *self, SEL selector, CGRect rect, NSDictionary<NSString *, id> *attributes)
{
    [[[NSAttributedString alloc] initWithString:self attributes:attributes] drawWithRect:rect options:NSStringDrawingUsesLineFragmentOrigin context:nil];
}

@interface RevenantStringDrawing : NSObject
@end

@implementation RevenantStringDrawing

+ (void)load
{
    if ([NSString instancesRespondToSelector:@selector(sizeWithAttributes:)])
        return;
    Method native = class_getInstanceMethod([NSString class], @selector(drawInRect:withAttributes:));
    if (native)
        method_setImplementation(native, (IMP)revenant_draw_in_rect);
}

@end

@implementation NSString (RevenantDrawing7)

- (NSAttributedString *)revenant_attributed:(NSDictionary<NSString *, id> *)attributes
{
    return [[NSAttributedString alloc] initWithString:self attributes:attributes];
}

- (CGSize)sizeWithAttributes:(NSDictionary<NSString *, id> *)attributes
{
    return [self boundingRectWithSize:CGSizeMake(RevenantUnbounded, RevenantUnbounded) options:NSStringDrawingUsesLineFragmentOrigin attributes:attributes context:nil].size;
}

- (CGRect)boundingRectWithSize:(CGSize)size options:(NSStringDrawingOptions)options attributes:(NSDictionary<NSString *, id> *)attributes context:(NSStringDrawingContext *)context
{
    if (!self.length) {
        CGRect line = [[@" " revenant_attributed:attributes] boundingRectWithSize:size options:options context:nil];
        line.size.width = 0;
        return line;
    }
    return [[self revenant_attributed:attributes] boundingRectWithSize:size options:options context:context];
}

- (void)drawAtPoint:(CGPoint)point withAttributes:(NSDictionary<NSString *, id> *)attributes
{
    [[self revenant_attributed:attributes] drawAtPoint:point];
}

- (void)drawInRect:(CGRect)rect withAttributes:(NSDictionary<NSString *, id> *)attributes
{
    revenant_draw_in_rect(self, _cmd, rect, attributes);
}

- (void)drawWithRect:(CGRect)rect options:(NSStringDrawingOptions)options attributes:(NSDictionary<NSString *, id> *)attributes context:(NSStringDrawingContext *)context
{
    [[self revenant_attributed:attributes] drawWithRect:rect options:options context:context];
}

@end
