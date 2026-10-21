#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char RevenantAddedKeyCommandsKey;

@implementation UIViewController (RevenantKeyCommands9)

- (void)addKeyCommand:(UIKeyCommand *)keyCommand
{
    NSMutableArray *added = objc_getAssociatedObject(self, &RevenantAddedKeyCommandsKey);
    if (!added) {
        added = [NSMutableArray array];
        objc_setAssociatedObject(self, &RevenantAddedKeyCommandsKey, added, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (![added containsObject:keyCommand])
        [added addObject:keyCommand];
}

- (void)removeKeyCommand:(UIKeyCommand *)keyCommand
{
    [objc_getAssociatedObject(self, &RevenantAddedKeyCommandsKey) removeObject:keyCommand];
}

- (NSArray<UIKeyCommand *> *)revenant_addedKeyCommands
{
    return objc_getAssociatedObject(self, &RevenantAddedKeyCommandsKey) ?: @[];
}

@end
