#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "UIAccessibilityBlocks17.h"

static id revenant_block_get(id object, const void *key)
{
    return objc_getAssociatedObject(object, key);
}

static void revenant_block_set(id object, const void *key, id block)
{
    objc_setAssociatedObject(object, key, block, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

