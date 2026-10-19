#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static char CharonTargetContentKey;

@implementation NSUserActivity (CharonTargetContent)

- (NSString *)targetContentIdentifier
{
    return objc_getAssociatedObject(self, &CharonTargetContentKey);
}

- (void)setTargetContentIdentifier:(NSString *)identifier
{
    objc_setAssociatedObject(self, &CharonTargetContentKey, [identifier copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
