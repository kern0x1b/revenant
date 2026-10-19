#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

typedef struct {
    CGPathApplyBlock block;
} charon_path_context;

static void charon_path_apply(void *info, const CGPathElement *element)
{
    ((charon_path_context *)info)->block(element);
}

void CGPathApplyWithBlock(CGPathRef path, CGPathApplyBlock block)
{
    if (!path || !block)
        return;
    charon_path_context context = {block};
    CGPathApply(path, &context, charon_path_apply);
}
