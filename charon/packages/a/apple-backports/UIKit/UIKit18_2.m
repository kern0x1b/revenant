#import "CharonUIKit18.h"
#import <objc/runtime.h>

@implementation UIWritingToolsCoordinator
@end

@implementation UIWritingToolsCoordinatorContext
@end

@implementation UIWritingToolsCoordinatorAnimationParameters
@end

@implementation UITextView (CharonUIKit18_WritingTools)

static char CharonTextViewWritingToolsCoordinatorKey;
static char CharonTextViewWritingToolsCoordinatorSubclassKey;

- (id)writingToolsCoordinator
{
    return objc_getAssociatedObject(self, &CharonTextViewWritingToolsCoordinatorKey);
}
- (void)setWritingToolsCoordinator:(id)coordinator
{
    objc_setAssociatedObject(self, &CharonTextViewWritingToolsCoordinatorKey, coordinator,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (id)subclassForWritingToolsCoordinator
{
    return objc_getAssociatedObject(self, &CharonTextViewWritingToolsCoordinatorSubclassKey);
}
- (void)setSubclassForWritingToolsCoordinator:(id)subclass
{
    objc_setAssociatedObject(self, &CharonTextViewWritingToolsCoordinatorSubclassKey, subclass,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
