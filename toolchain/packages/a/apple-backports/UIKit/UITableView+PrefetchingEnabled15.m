#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char RevenantTablePrefetchEnabled15Key;

@interface UITableView (RevenantPrefetchingEnabled15)
- (BOOL)isPrefetchingEnabled;
- (void)setPrefetchingEnabled:(BOOL)prefetchingEnabled;
- (BOOL)revenant_prefetchingAllowed;
@end

@interface UITableView (RevenantPrefetchRows10)
- (void)revenant_prefetchRows;
@end

@interface RevenantTablePrefetchEnabled15Installer : NSObject
@end

@implementation RevenantTablePrefetchEnabled15Installer

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
        if (!table.revenant_prefetchingAllowed)
            return;
        if ([table respondsToSelector:@selector(revenant_prefetchRows)])
            [table revenant_prefetchRows];
    }), "crevenant_layoutSubviews_prefetch15");
}

@end




@implementation UITableView (RevenantPrefetchingEnabled15)

- (BOOL)isPrefetchingEnabled
{
    return [objc_getAssociatedObject(self, &RevenantTablePrefetchEnabled15Key) boolValue];
}

- (void)setPrefetchingEnabled:(BOOL)prefetchingEnabled
{
    objc_setAssociatedObject(self, &RevenantTablePrefetchEnabled15Key, @(prefetchingEnabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)revenant_prefetchingAllowed
{
    return self.isPrefetchingEnabled;
}

@end
