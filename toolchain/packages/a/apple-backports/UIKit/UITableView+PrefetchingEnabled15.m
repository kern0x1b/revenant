#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char CharonTablePrefetchEnabled15Key;

@interface UITableView (CharonPrefetchingEnabled15)
- (BOOL)isPrefetchingEnabled;
- (void)setPrefetchingEnabled:(BOOL)prefetchingEnabled;
- (BOOL)charon_prefetchingAllowed;
@end

@interface UITableView (CharonPrefetchRows10)
- (void)charon_prefetchRows;
@end

@interface CharonTablePrefetchEnabled15Installer : NSObject
@end

@implementation CharonTablePrefetchEnabled15Installer

+ (void)load
{
    if ([UITableView instancesRespondToSelector:@selector(isPrefetchingEnabled)])
        return;
    Method layout = class_getInstanceMethod([UITableView class], @selector(layoutSubviews));
    if (!layout)
        return;
    IMP original = method_getImplementation(layout);
    class_replaceMethod([UITableView class], @selector(layoutSubviews),
                        imp_implementationWithBlock(^(UITableView *table) {
        ((void (*)(id, SEL))original)(table, @selector(layoutSubviews));
        if (!table.charon_prefetchingAllowed)
            return;
        if ([table respondsToSelector:@selector(charon_prefetchRows)])
            [table charon_prefetchRows];
    }), "ccharon_layoutSubviews_prefetch15");
}

@end




@implementation UITableView (CharonPrefetchingEnabled15)

- (BOOL)isPrefetchingEnabled
{
    return [objc_getAssociatedObject(self, &CharonTablePrefetchEnabled15Key) boolValue];
}

- (void)setPrefetchingEnabled:(BOOL)prefetchingEnabled
{
    objc_setAssociatedObject(self, &CharonTablePrefetchEnabled15Key, @(prefetchingEnabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)charon_prefetchingAllowed
{
    return self.isPrefetchingEnabled;
}

@end
