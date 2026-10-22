#import "check.h"

@interface RevenantObservable : NSObject
@property (nonatomic) int value;
@end

@implementation RevenantObservable
@end

@interface RevenantWatcher : NSObject
@property (nonatomic) int seen;
@property (nonatomic) void *lastContext;
@end

@implementation RevenantWatcher

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    self.seen++;
    self.lastContext = context;
}

@end

static void revenant_set_shared(id object, NSKeyValueSharedObserversSnapshot *snapshot)
{
    SEL selector = @selector(setSharedObservers:);
    REVENANT_IMP(NSObject, selector, void (*)(id, SEL, id))(object, selector, snapshot);
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    RevenantWatcher *watcher = [[RevenantWatcher alloc] init];
    NSKeyValueSharedObservers *shared = [[NSKeyValueSharedObservers alloc] initWithObservableClass:[RevenantObservable class]];
    [shared addSharedObserver:watcher forKey:@"value" options:NSKeyValueObservingOptionNew context:(void *)0x42];
    NSKeyValueSharedObserversSnapshot *snapshot = [shared snapshot];
    RevenantObservable *first = [[RevenantObservable alloc] init];
    RevenantObservable *second = [[RevenantObservable alloc] init];
    revenant_set_shared(first, snapshot);
    revenant_set_shared(second, snapshot);
    first.value = 1;
    second.value = 2;
    revenant_check(watcher.seen == (revenant_negative ? 1 : 2) && watcher.lastContext == (void *)0x42, "one collection observes two objects with its context", [NSString stringWithFormat:@"%d", watcher.seen]);
    revenant_set_shared(first, nil);
    first.value = 3;
    revenant_check(watcher.seen == 2, "clearing the shared observers stops the notifications", [NSString stringWithFormat:@"%d", watcher.seen]);
    NSKeyValueSharedObservers *other = [[NSKeyValueSharedObservers alloc] initWithObservableClass:[RevenantObservable class]];
    [other addSharedObserver:watcher forKey:@"value" options:0 context:NULL];
    revenant_set_shared(second, [other snapshot]);
    second.value = 4;
    revenant_check(watcher.seen == 3, "a new collection replaces the old one", [NSString stringWithFormat:@"%d", watcher.seen]);
    BOOL nested = NO, mismatch = NO, unavailable = NO;
    @try {
        [shared addSharedObserver:watcher forKey:@"a.b" options:0 context:NULL];
    } @catch (NSException *exception) {
        nested = [exception.name isEqualToString:NSInvalidArgumentException];
    }
    @try {
        revenant_set_shared([[NSObject alloc] init], snapshot);
    } @catch (NSException *exception) {
        mismatch = [exception.name isEqualToString:NSInvalidArgumentException];
    }
    @try {
        REVENANT_IMP(NSKeyValueSharedObservers, @selector(addObserver:forKeyPath:options:context:), void (*)(id, SEL, id, id, NSKeyValueObservingOptions, void *))(shared, @selector(addObserver:forKeyPath:options:context:), watcher, @"value", 0, NULL);
    } @catch (NSException *exception) {
        unavailable = [exception.name isEqualToString:NSInvalidArgumentException];
    }
    revenant_check(nested, "a nested key path is refused", @"accepted");
    revenant_check(mismatch, "an object of another class is refused", @"accepted");
    revenant_check(unavailable, "the plain observer registration is unavailable", @"accepted");
    return revenant_finish();
}
