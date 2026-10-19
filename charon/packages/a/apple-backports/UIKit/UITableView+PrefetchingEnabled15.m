#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
// UITableView+PrefetchingEnabled15.m - the prefetching gate iOS 15.0 gave UITableView.
//
// One row: UITableView.prefetchingEnabled, introduced 15.0, minimum 6.0, so this file is one
// object's API and belongs to release 15 alone.
//
// WHY THIS ROW EXISTS AT ALL, which is the whole of it. The port already prefetches for table
// views - UITableView+Prefetching10.m holds the data source, computes the rows just past what is
// on screen, calls -tableView:prefetchRowsAtIndexPaths: and cancels what has scrolled away. It
// runs as soon as a prefetch data source is set, and it has no switch. The collection view's half
// of the same feature has one: UICollectionView+Prefetching10.m:121 gates its prefetch on
// `!source || !self.isPrefetchingEnabled`, and that file's own comment records where the gate's
// default came from - measured under Mac Catalyst, a freshly made collection view answers NO for
// isPrefetchingEnabled and nil for the data source.
//
// Apple's UITableView had no such switch in 10.0 and gained one in 15.0, so before this row the
// port's table prefetching was the one half of the feature that could not be turned off: a caller
// who set a prefetch data source and did not want prefetching had no way to say so, and a caller
// who wanted to know whether it was on could not ask. This is that switch, and the default is
// the one measured on the collection view's own side of the same port.
//
// The gate is applied by installing a layoutSubviews hook, the same way
// UITableView+Prefetching10.m:43 installs its own, and it REPLACES rather than adds: the
// collection view's file returns early at :35 when the release already answers the selector.
//
// Two hooks on one selector compose, and that was measured before this file was written rather
// than assumed: two classes each calling class_replaceMethod on -layoutSubviews in their +load,
// the second reading the IMP the first installed, and one -layoutSubviews call afterwards
// running the original, then the first hook, then the second. So the 10.0 hook and this one both
// run, in that order, and the prefetch pass still happens exactly once - the second hook finds
// every candidate already asked for, which is why asking for the gate first is what keeps a
// closed gate from reaching the data source at all.
//
// +load is required and is why the method is installed from a class and not from the category:
// +load runs before the library's own categories are attached, so a method added from a category
// would not be there yet (the reason UITableView+Prefetching10.m:15 spells out in its comment).

static const char CharonTablePrefetchEnabled15Key;

@interface UITableView (CharonPrefetchingEnabled15)
- (BOOL)isPrefetchingEnabled;
- (void)setPrefetchingEnabled:(BOOL)prefetchingEnabled;
- (BOOL)charon_prefetchingAllowed;
@end

// The pass the 10.0 object owns, declared here the way UITableView+Prefetching10.m:18 declares it
// for its own installer: it is a category method on UITableView, so it is reachable, and it is
// declared in that file rather than in a header because that file is the only thing that defines
// it. No C function crosses between the two files, which is what keeps this one safe to link into
// a band that does not keep the 10.0 one: a category method is resolved at message send, and a C
// symbol would not be.
@interface UITableView (CharonPrefetchRows10)
- (void)charon_prefetchRows;
@end

@interface CharonTablePrefetchEnabled15Installer : NSObject
@end

@implementation CharonTablePrefetchEnabled15Installer

+ (void)load
{
    // Nothing to install where the release already answers the selector itself.
    if ([UITableView instancesRespondToSelector:@selector(isPrefetchingEnabled)])
        return;
    Method layout = class_getInstanceMethod([UITableView class], @selector(layoutSubviews));
    if (!layout)
        return;
    IMP original = method_getImplementation(layout);
    class_replaceMethod([UITableView class], @selector(layoutSubviews),
                        imp_implementationWithBlock(^(UITableView *table) {
        ((void (*)(id, SEL))original)(table, @selector(layoutSubviews));
        // The gate, and only then the pass the 10.0 object already owns. Closed means the table
        // is laid out and nothing is asked of the data source.
        if (!table.charon_prefetchingAllowed)
            return;
        // Sent, not called: the 10.0 object that defines this is a separate object and a separate
        // band decision, so a band that kept this file and left that one out would have no
        // implementation to link against. A message send is a no-op when nothing implements it,
        // where a C call would be an undefined symbol at link time in exactly that band
        // (AGENTS.md, "A C function shared between backport files"). The gate is still the whole
        // of this row either way.
        if ([table respondsToSelector:@selector(charon_prefetchRows)])
            [table charon_prefetchRows];
    }), "ccharon_layoutSubviews_prefetch15");
}

@end

// The key is this file's own, so the 10.0 object and the 15.0 one cannot read each other's
// storage even where both are linked into one binary.




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
