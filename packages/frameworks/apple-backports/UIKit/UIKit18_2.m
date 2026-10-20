#import "RevenantUIKit18.h"
#import <objc/runtime.h>

@implementation UIWritingToolsCoordinator
@end

@implementation UIWritingToolsCoordinatorContext
@end

@implementation UIWritingToolsCoordinatorAnimationParameters
@end

@implementation UITextView (RevenantUIKit18_WritingTools)

static char RevenantTextViewWritingToolsCoordinatorKey;
static char RevenantTextViewWritingToolsCoordinatorSubclassKey;

- (id)writingToolsCoordinator
{
    return objc_getAssociatedObject(self, &RevenantTextViewWritingToolsCoordinatorKey);
}
- (void)setWritingToolsCoordinator:(id)coordinator
{
    objc_setAssociatedObject(self, &RevenantTextViewWritingToolsCoordinatorKey, coordinator,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (id)subclassForWritingToolsCoordinator
{
    return objc_getAssociatedObject(self, &RevenantTextViewWritingToolsCoordinatorSubclassKey);
}
- (void)setSubclassForWritingToolsCoordinator:(id)subclass
{
    objc_setAssociatedObject(self, &RevenantTextViewWritingToolsCoordinatorSubclassKey, subclass,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
