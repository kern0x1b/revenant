#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

typedef struct {
    CGPathApplyBlock block;
} revenant_path_context;

static void revenant_path_apply(void *info, const CGPathElement *element)
{
    ((revenant_path_context *)info)->block(element);
}

void CGPathApplyWithBlock(CGPathRef path, CGPathApplyBlock block)
{
    if (!path || !block)
        return;
    revenant_path_context context = {block};
    CGPathApply(path, &context, revenant_path_apply);
}
