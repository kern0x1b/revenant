#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char CharonDropPreviewUpdateCountKey;

@implementation UIDragItem (CharonDropPreviewUpdate17)

- (void)setNeedsDropPreviewUpdate
{
    NSUInteger asked = [objc_getAssociatedObject(self, &CharonDropPreviewUpdateCountKey) unsignedIntegerValue];
    objc_setAssociatedObject(self, &CharonDropPreviewUpdateCountKey,
                            @(asked + 1), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSUInteger)charon_dropPreviewUpdateCount
{
    return [objc_getAssociatedObject(self, &CharonDropPreviewUpdateCountKey) unsignedIntegerValue];
}

@end
