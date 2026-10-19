#import "uirest.h"

@interface UIViewController (CharonHostAppearing)
- (void)charonHostViewIsAppearing:(BOOL)animated;
@end

static NSMutableArray *events;

@interface Base : UIViewController
@end

@implementation Base

- (void)viewWillAppear:(BOOL)animated
{
    [events addObject:[NSString stringWithFormat:@"%@ base will appear before super", NSStringFromClass([self class])]];
    [super viewWillAppear:animated];
    [events addObject:[NSString stringWithFormat:@"%@ base will appear after super", NSStringFromClass([self class])]];
}

- (void)charonHostViewIsAppearing:(BOOL)animated
{
    [events addObject:[NSString stringWithFormat:@"%@ is appearing", NSStringFromClass([self class])]];
    [super charonHostViewIsAppearing:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [events addObject:[NSString stringWithFormat:@"%@ did appear", NSStringFromClass([self class])]];
}

@end

@interface Derived : Base
@end

@implementation Derived

- (void)viewWillAppear:(BOOL)animated
{
    [events addObject:@"Derived will appear before super"];
    [super viewWillAppear:animated];
    [events addObject:@"Derived will appear after super"];
}

@end

@interface Plain : UIViewController
@end

@implementation Plain

- (void)charonHostViewIsAppearing:(BOOL)animated
{
    [events addObject:@"Plain is appearing"];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [events addObject:@"Plain did appear"];
}

@end

@interface Storyboardless : UIViewController
@end

@implementation Storyboardless

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [super initWithCoder:coder];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [events addObject:@"Storyboardless will appear"];
}

- (void)charonHostViewIsAppearing:(BOOL)animated
{
    [events addObject:@"Storyboardless is appearing"];
}

@end

static void show(UIWindow *window, UIViewController *controller)
{
    [events removeAllObjects];
    window.rootViewController = controller;
    ur_spin(^BOOL{ return [events.lastObject hasSuffix:@"is appearing"] || [events.lastObject hasSuffix:@"did appear"]; }, 3);
}

void charon_windowed_run(UIWindow *window)
{
    @autoreleasepool {
        events = [NSMutableArray array];
        show(window, [[Derived alloc] init]);
        NSArray *expected = @[@"Derived will appear before super", @"Derived base will appear before super", @"Derived base will appear after super", @"Derived will appear after super", @"Derived is appearing"];
        NSMutableArray *ours = [NSMutableArray array];
        for (NSString *entry in events) {
            if (![entry hasPrefix:@"Derived"])
                continue;
            [ours addObject:entry];
        }
        charon_check([ours isEqual:expected], "viewIsAppearing comes once, after the whole of viewWillAppear", ur_norm(events));
        show(window, [[Base alloc] init]);
        charon_check([[events filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF ENDSWITH 'is appearing'"]] count] == 1 && [events indexOfObject:@"Base is appearing"] > [events indexOfObject:@"Base base will appear after super"], "a class that overrides viewWillAppear only once is wrapped once", ur_norm(events));
        show(window, [[Plain alloc] init]);
        charon_check([events containsObject:@"Plain is appearing"], "a class that does not override viewWillAppear is called too", ur_norm(events));
        show(window, [[Derived alloc] init]);
        charon_check([[events filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF == 'Derived is appearing'"]] count] == 1, "and the second time it is once again", ur_norm(events));
        NSMutableData *data = [NSMutableData data];
        NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:NO];
        [archiver encodeObject:[[Storyboardless alloc] init] forKey:@"c"];
        [archiver finishEncoding];
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:archiver.encodedData error:NULL];
        unarchiver.requiresSecureCoding = NO;
        Storyboardless *decoded = [unarchiver decodeObjectForKey:@"c"];
        (void)data;
        show(window, decoded ?: [[Storyboardless alloc] init]);
        charon_check([events containsObject:@"Storyboardless is appearing"], "a controller made from a coder is called too", ur_norm(events));
    }
}
