#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static char CharonGestureRecognizerNameKey;

@implementation UIGestureRecognizer (CharonName)

- (NSString *)name
{
    return objc_getAssociatedObject(self, &CharonGestureRecognizerNameKey);
}

- (void)setName:(NSString *)name
{
    objc_setAssociatedObject(self, &CharonGestureRecognizerNameKey, [name copy], OBJC_ASSOCIATION_RETAIN);
}

@end
