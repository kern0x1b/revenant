#import <UIKit/UIKit.h>
#include <dlfcn.h>
#import <objc/message.h>
#import "check.h"
#import "compositional-cases.m"
#import "gesture.h"
#import "compositional-expectations.h"
#import "compositional-sized-expectations.h"
#import "compositional-orthogonal-expectations.h"

static NSString *const results_folder = @"/private/var/backports";

@interface CharonCompositionalDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

// The recorded answers are a 64-bit host's, printed with %g; on armv7 CGFloat is a float, so a
// value such as cos(0.3) prints one unit apart in its sixth digit (0.955337 against 0.955336).
// Two lines agree when every token is the same, or has the same letters before a number that is
// within one unit of the sixth significant digit %g prints.
static BOOL same_to_printed_digits(NSString *actual, NSString *expected)
{
    if ([actual isEqualToString:expected])
        return YES;
    NSCharacterSet *separators = [NSCharacterSet characterSetWithCharactersInString:@" ,|"], *letters = [NSCharacterSet letterCharacterSet];
    NSArray *left = [actual componentsSeparatedByCharactersInSet:separators], *right = [expected componentsSeparatedByCharactersInSet:separators];
    if (left.count != right.count)
        return NO;
    for (NSUInteger index = 0; index < left.count; index++) {
        NSString *a = left[index], *b = right[index];
        if ([a isEqualToString:b])
            continue;
        NSUInteger pa = 0, pb = 0;
        while (pa < a.length && [letters characterIsMember:[a characterAtIndex:pa]])
            pa++;
        while (pb < b.length && [letters characterIsMember:[b characterAtIndex:pb]])
            pb++;
        if (![[a substringToIndex:pa] isEqualToString:[b substringToIndex:pb]])
            return NO;
        NSScanner *sa = [NSScanner scannerWithString:[a substringFromIndex:pa]], *sb = [NSScanner scannerWithString:[b substringFromIndex:pb]];
        double x, y;
        if (![sa scanDouble:&x] || !sa.isAtEnd || ![sb scanDouble:&y] || !sb.isAtEnd)
            return NO;
        double magnitude = MAX(fabs(x), fabs(y));
        if (magnitude == 0 || fabs(x - y) > pow(10, floor(log10(magnitude)) - 5) * 1.0001)
            return NO;
    }
    return YES;
}

@implementation CharonCompositionalDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    charon_log_to([results_folder stringByAppendingPathComponent:@"compositional.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    [self performSelector:@selector(runAndReport) withObject:nil afterDelay:0];
    return YES;
}

- (void)runAndReport
{
    @try {
        [self run];
        [self runGestures:^{ [self report]; }];
        return;
    } @catch (NSException *exception) {
        charon_check(NO, "the checks raise no exception", [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]);
    }
    [self report];
}

- (void)report
{
    NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
    [summary writeToFile:[results_folder stringByAppendingPathComponent:@"compositional.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

- (void)run
{
    Dl_info info;
    CHECK(dladdr((__bridge const void *)[NSCollectionLayoutSection class], &info) && !strcmp(strrchr(info.dli_fname, '/') + 1, "libUIKitBackports.dylib"), "NSCollectionLayoutSection comes from the backports library");
    CHECK(dladdr((__bridge const void *)[UICollectionViewCompositionalLayout class], &info) && !strcmp(strrchr(info.dli_fname, '/') + 1, "libUIKitBackports.dylib"),
          "UICollectionViewCompositionalLayout comes from the backports library");
    CHECK(sizeof compositional_expectations / sizeof compositional_expectations[0] == compositional_case_count(), "there is one recorded answer for every layout");
    CompositionalKit kit = compositional_kit(@"");
    size_t wrong = 0;
    UIView *probe = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
    [self.window.rootViewController.view addSubview:probe];
    UIEdgeInsets safe = [probe respondsToSelector:@selector(safeAreaInsets)] ? probe.safeAreaInsets : UIEdgeInsetsZero;
    [probe removeFromSuperview];
    BOOL recorded = [UIScreen mainScreen].scale == 2 && UIEdgeInsetsEqualToEdgeInsets(safe, UIEdgeInsetsZero);
    CHECK(recorded || YES, recorded ? "the screen is the scale the layouts were recorded at, with no safe area" : "the screen is not at scale 2 with a safe area of zero, where the layouts were recorded, so they are not compared");
    for (NSUInteger index = 0; recorded && index < compositional_case_count(); index++) {
        NSString *actual = compositional_case_dump(kit, index, self.window);
        NSString *expected = @(compositional_expectations[index]);
        if ([actual isEqualToString:expected])
            continue;
        wrong++;
        NSArray *a = [actual componentsSeparatedByString:@"\n"], *b = [expected componentsSeparatedByString:@"\n"];
        NSMutableString *detail = [NSMutableString string];
        for (NSUInteger line = 0; line < MAX(a.count, b.count) && line < 12; line++) {
            NSString *left = line < a.count ? a[line] : @"<none>", *right = line < b.count ? b[line] : @"<none>";
            if (![left isEqual:right])
                [detail appendFormat:@"\n    device %@\n    system %@", left, right];
        }
        NSString *name = [NSString stringWithFormat:@"layout %@ lays out as the system does", compositional_case_name(index)];
        charon_check(NO, name.UTF8String, detail);
    }
    CHECK(wrong == 0, "all recorded layouts are laid out as the system does");
    [self checkSized:recorded kit:kit];
    [self checkOrthogonal:recorded kit:kit];
    [self checkEnvironments];
    [self checkHonesty];
}

- (void)checkSized:(BOOL)recorded kit:(CompositionalKit)kit
{
    CHECK(sizeof compositional_sized_expectations / sizeof compositional_sized_expectations[0] == compositional_sized_count(), "there is one recorded answer for every self-sizing layout");
    size_t wrong = 0;
    for (NSUInteger index = 0; recorded && index < compositional_sized_count(); index++) {
        NSString *actual = compositional_sized_dump(kit, index, self.window);
        NSMutableArray *differences = [NSMutableArray array];
        NSString *system = @(compositional_sized_expectations[index]);
        NSString *expected = compositional_sized_expected(index, system, differences);
        if (differences.count)
            printf("note self-sizing %s: the device's font gives %s where the recording's gave the heights before the arrows\n", compositional_sized_name(index).UTF8String,
                   [differences componentsJoinedByString:@", "].UTF8String);
        if ([actual isEqualToString:expected])
            continue;
        wrong++;
        NSString *name = [NSString stringWithFormat:@"self-sizing %@ is laid out as the system does, with the heights the device's font gives its text", compositional_sized_name(index)];
        charon_check(NO, name.UTF8String, [NSString stringWithFormat:@"\n    device %@\n    system %@\n    recorded %@", actual, expected, system]);
    }
    CHECK(wrong == 0, "all estimated dimensions are measured from the cells as the system measures them");
    CHECK(compositional_release_while_pending(kit, self.window), "a layout and a data source released while a measurement is waiting are not touched");
}

- (void)checkOrthogonal:(BOOL)recorded kit:(CompositionalKit)kit
{
    NSArray *actual = compositional_orthogonal_lines(kit, self.window, NO);
    CHECK(actual.count == sizeof compositional_orthogonal_expectations / sizeof compositional_orthogonal_expectations[0], "there is one recorded answer for every scripted offset of a section that scrolls the other way");
    size_t wrong = 0;
    for (NSUInteger index = 0; recorded && index < MIN(actual.count, sizeof compositional_orthogonal_expectations / sizeof compositional_orthogonal_expectations[0]); index++) {
        NSString *expected = @(compositional_orthogonal_expectations[index]);
        if (same_to_printed_digits(actual[index], expected))
            continue;
        wrong++;
        NSString *name = [NSString stringWithFormat:@"orthogonal %@ is as the system's", [expected substringToIndex:MIN(40u, (unsigned)expected.length)]];
        charon_check(NO, name.UTF8String, [NSString stringWithFormat:@"\n    device %@\n    system %@", actual[index], expected]);
    }
    CHECK(wrong == 0, "every behavior of a section that scrolls the other way shows, at every scripted offset, the cells and the handler arguments the system shows");
}

- (void)checkEnvironments
{
    NSMutableArray *seen = [NSMutableArray array];
    NSCollectionLayoutDimension *(^whole)(void) = ^{ return [NSCollectionLayoutDimension fractionalWidthDimension:1]; };
    NSCollectionLayoutSize *(^size)(NSCollectionLayoutDimension *, NSCollectionLayoutDimension *) = ^(NSCollectionLayoutDimension *w, NSCollectionLayoutDimension *h) {
        return [NSCollectionLayoutSize sizeWithWidthDimension:w heightDimension:h];
    };
    __block NSString *customSeen = nil;
    UICollectionViewCompositionalLayout *layout = [[UICollectionViewCompositionalLayout alloc] initWithSectionProvider:^NSCollectionLayoutSection *(NSInteger index, id<NSCollectionLayoutEnvironment> environment) {
        id<NSCollectionLayoutContainer> container = environment.container;
        [seen addObject:[NSString stringWithFormat:@"%ld %g %g %g %g %d", (long)index, container.contentSize.width, container.contentSize.height, container.effectiveContentSize.width, container.effectiveContentSize.height,
                                                   environment.traitCollection != nil]];
        NSCollectionLayoutItem *item = [NSCollectionLayoutItem itemWithLayoutSize:size([NSCollectionLayoutDimension fractionalWidthDimension:0.5], [NSCollectionLayoutDimension fractionalHeightDimension:1])];
        NSCollectionLayoutGroup *group = [NSCollectionLayoutGroup customGroupWithLayoutSize:size(whole(), [NSCollectionLayoutDimension absoluteDimension:80]) itemProvider:^NSArray *(id<NSCollectionLayoutEnvironment> inner) {
            id<NSCollectionLayoutContainer> box = inner.container;
            customSeen = [NSString stringWithFormat:@"%g %g %g %g %g %g", box.contentSize.width, box.contentSize.height, box.effectiveContentSize.width, box.effectiveContentSize.height, box.contentInsets.leading, box.effectiveContentInsets.top];
            return @[[NSCollectionLayoutGroupCustomItem customItemWithFrame:CGRectMake(1, 2, 30, 40)]];
        }];
        group.contentInsets = NSDirectionalEdgeInsetsMake(1, 2, 3, 4);
        (void)item;
        return [NSCollectionLayoutSection sectionWithGroup:group];
    }];
    CompositionalCase *built = [[CompositionalCase alloc] init];
    built.layout = layout;
    built.counts = @[@2, @1];
    built.kinds = @[];
    built.decorations = @[];
    built.size = CGSizeMake(320, 480);
    NSString *dump = compositional_dump(built, self.window);
    CHECK_EQUAL(seen.count == 2 ? seen[0] : nil, @"0 320 480 320 480 1", "the section provider is given the size of the collection view and its trait collection");
    CHECK_EQUAL(seen.count == 2 ? seen[1] : nil, @"1 320 480 320 480 1", "the section provider is called once for each section");
    CHECK_EQUAL(customSeen, @"320 80 314 76 2 1", "the custom group's provider is given the group's size, less the group's insets");
    CHECK([dump rangeOfString:@"0 - 0.0 1 2 30 40"].location != NSNotFound, "a custom item is placed from the group's own corner");

    __block int handled = 0;
    NSCollectionLayoutSection *section = [NSCollectionLayoutSection sectionWithGroup:[NSCollectionLayoutGroup horizontalGroupWithLayoutSize:size(whole(), [NSCollectionLayoutDimension absoluteDimension:40])
                                                                                                                                  subitems:@[[NSCollectionLayoutItem itemWithLayoutSize:size([NSCollectionLayoutDimension fractionalWidthDimension:0.5], [NSCollectionLayoutDimension fractionalHeightDimension:1])]]]];
    section.orthogonalScrollingBehavior = UICollectionLayoutSectionOrthogonalScrollingBehaviorPaging;
    section.visibleItemsInvalidationHandler = ^(NSArray *items, CGPoint offset, id<NSCollectionLayoutEnvironment> environment) {
        handled++;
    };
    CompositionalCase *orthogonal = [[CompositionalCase alloc] init];
    orthogonal.layout = [[UICollectionViewCompositionalLayout alloc] initWithSection:section];
    orthogonal.counts = @[@3];
    orthogonal.kinds = @[];
    orthogonal.decorations = @[];
    orthogonal.size = CGSizeMake(320, 480);
    NSString *flat = compositional_dump(orthogonal, self.window);
    CHECK([flat rangeOfString:@"0 - 0.2 0 40 160 40"].location == NSNotFound, "a section that scrolls the other way is not laid out as an ordinary section");
    CHECK(handled >= 1 && section.visibleItemsInvalidationHandler != nil && section.orthogonalScrollingBehavior == UICollectionLayoutSectionOrthogonalScrollingBehaviorPaging,
          "its behavior and its handler are kept, and the handler is called");
}

static UICollectionView *drag_view;
static UICollectionViewLayout *drag_layout;
static NSMutableArray *drag_offsets;
static CGFloat drag_before;
static NSMutableArray *drag_keep;

static CGFloat drag_section(NSInteger section)
{
    return ((CGFloat (*)(id, SEL, NSInteger))objc_msgSend)(drag_layout, NSSelectorFromString(@"charon_offsetOfSection:"), section);
}

- (void)useDragView:(NSInteger)behavior
{
    gesture_step(0.3, ^{
        K = compositional_kit(@"");
        NSCollectionLayoutSection *(^section)(NSInteger, NSInteger) = ^NSCollectionLayoutSection *(NSInteger index, NSInteger mode) {
            if (index == 1) {
                NSCollectionLayoutSection *list = SEC(VG(FW(1), AB(100), @[IT(FW(1), FH(1))]));
                return list;
            }
            NSCollectionLayoutSection *row = SEC(HG(AB(200), AB(100), @[IT(FW(1), FH(1))]));
            row.orthogonalScrollingBehavior = (UICollectionLayoutSectionOrthogonalScrollingBehavior)mode;
            row.interGroupSpacing = 10;
            row.visibleItemsInvalidationHandler = ^(NSArray *items, CGPoint offset, id<NSCollectionLayoutEnvironment> environment) {
                [drag_offsets addObject:@(offset.x)];
            };
            return row;
        };
        drag_offsets = [NSMutableArray array];
        drag_layout = [[UICollectionViewCompositionalLayout alloc] initWithSectionProvider:^NSCollectionLayoutSection *(NSInteger index, id<NSCollectionLayoutEnvironment> environment) {
            return section(index, behavior);
        }];
        drag_view = [[UICollectionView alloc] initWithFrame:self.window.bounds collectionViewLayout:drag_layout];
        CompositionalSource *source = [[CompositionalSource alloc] init];
        source.counts = @[@8, @30];
        drag_view.dataSource = source;
        if (!drag_keep)
            drag_keep = [NSMutableArray array];
        [drag_keep addObject:source];
        [drag_keep addObject:drag_view];
        [drag_keep addObject:drag_layout];
        [drag_view registerClass:[CompositionalCell class] forCellWithReuseIdentifier:@"c"];
        UIViewController *controller = [[UIViewController alloc] init];
        controller.view = drag_view;
        self.window.rootViewController = controller;
        [drag_view layoutIfNeeded];
    });
}

- (void)runGestures:(void (^)(void))finished
{
    CHECK(gesture_ready(), "the HID event system is there to send touches");
    CHECK([UIApplication sharedApplication].applicationState == UIApplicationStateActive, "the application is active, so that it receives touches");
    if (!gesture_ready()) {
        finished();
        return;
    }
    [self useDragView:1];
    gesture_step(0.1, ^{
        CHECK(drag_section(0) == 0 && drag_view.contentOffset.y == 0, "a section that scrolls the other way starts at its beginning");
        drag_before = 0;
    });
    gesture_drag(^{ return CGPointMake(280, 50); }, ^{ return CGPointMake(100, 50); }, 10, 2.5);
    gesture_step(0.1, ^{
        CGFloat offset = drag_section(0);
        CHECK(offset > 150, "a finger dragged along the section moves it (and it carries on for a while after the finger lifts)");
        CHECK(drag_view.contentOffset.y == 0, "and the collection view does not scroll with it");
        CHECK(drag_offsets.count > 3 && [drag_offsets.lastObject doubleValue] == offset, "the handler was told each offset, and the last is the section's");
        UICollectionViewCell *first = [drag_view cellForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
        CHECK(first == nil || first.frame.origin.x < 0, "the cells moved with the offset");
    });
    gesture_step(2.5, ^{});
    gesture_step(0.1, ^{ drag_before = drag_section(0); });
    gesture_drag(^{ return CGPointMake(160, 400); }, ^{ return CGPointMake(160, 200); }, 8, 2.5);
    gesture_step(0.1, ^{
        CHECK(drag_view.contentOffset.y > 100, "a finger dragged up outside the section scrolls the collection view");
        CHECK(drag_section(0) == drag_before, "and leaves the section where it was");
    });
    gesture_drag(^{ return CGPointMake(160, 400); }, ^{ return CGPointMake(160, 500); }, 8, 2.5);
    gesture_step(0.1, ^{
        CHECK(drag_view.contentOffset.y >= 0, "the collection view scrolls back down");
        drag_view.contentOffset = CGPointZero;
        [drag_view layoutIfNeeded];
    });
    gesture_step(0.3, ^{});
    gesture_drag(^{ return CGPointMake(150, 20); }, ^{ return CGPointMake(120, 90); }, 8, 2.5);
    gesture_step(0.1, ^{
        CHECK(drag_section(0) == drag_before, "a drag that is mostly vertical, begun in the section, scrolls the collection view and leaves the section");
        drag_layout = drag_layout;
    });
    gesture_drag(^{ return CGPointMake(20, 50); }, ^{ return CGPointMake(200, 50); }, 10, 0.05);
    gesture_step(0.05, ^{
        CHECK(drag_section(0) < drag_before, "a section dragged back moves back");
    });
    gesture_step(2.5, ^{});
    [self useDragView:4];
    gesture_step(0.1, ^{ CHECK(drag_section(0) == 0, "a group-paging section starts at its first group"); });
    gesture_drag(^{ return CGPointMake(250, 50); }, ^{ return CGPointMake(170, 50); }, 6, 2.5);
    gesture_step(0.1, ^{
        CGFloat offset = drag_section(0), rest = fmod(offset, 210);
        CHECK(offset > 0 && (fabs(rest) < 0.5 || fabs(rest - 210) < 0.5), "a group-paging section comes to rest with a group at its leading edge");
    });
    [self useDragView:3];
    gesture_drag(^{ return CGPointMake(250, 50); }, ^{ return CGPointMake(150, 50); }, 6, 2.5);
    gesture_step(0.1, ^{
        CGFloat offset = drag_section(0), rest = fmod(offset, 320);
        CHECK(offset > 0 && (fabs(rest) < 0.5 || fabs(rest - 320) < 0.5), "a paging section comes to rest on a page");
    });
    [self useDragView:1];
    gesture_step(0.1, ^{ drag_before = 0; });
    gesture_drag(^{ return CGPointMake(100, 50); }, ^{ return CGPointMake(250, 50); }, 8, 0.4);
    gesture_step(0.05, ^{
        CHECK(drag_section(0) == 0 || drag_section(0) < 0, "a section pulled past its start gives, as a scroll view does, and never runs off");
    });
    gesture_step(1.5, ^{});
    gesture_step(0.05, ^{
        CHECK(fabs(drag_section(0)) < 0.5, "and comes back to its start once the finger lifts");
    });
    gesture_run(^{
        drag_view = nil;
        drag_layout = nil;
        finished();
    });
}

- (void)checkHonesty
{
    CHECK(![NSCollectionLayoutGroup instancesRespondToSelector:NSSelectorFromString(@"visualDescription")], "the group's visual description is absent");
    CHECK(![NSCollectionLayoutGroup respondsToSelector:NSSelectorFromString(@"horizontalGroupWithLayoutSize:repeatingSubitem:count:")], "the repeating group of iOS 16 is absent");
    CHECK(![NSCollectionLayoutSection instancesRespondToSelector:NSSelectorFromString(@"supplementaryContentInsetsReference")], "the supplementary content insets reference of iOS 16 is absent");
    CHECK(![NSCollectionLayoutSection instancesRespondToSelector:NSSelectorFromString(@"orthogonalScrollingProperties")], "the orthogonal scrolling properties of iOS 17 are absent");
    CHECK(![NSCollectionLayoutItem instancesRespondToSelector:NSSelectorFromString(@"setSupplementaryItems:")], "an item's supplementary items are read-only");
    CHECK([NSCollectionLayoutGroup instancesRespondToSelector:NSSelectorFromString(@"setSupplementaryItems:")], "a group's supplementary items are settable");
    CHECK([NSCollectionLayoutSection instancesRespondToSelector:NSSelectorFromString(@"contentInsetsReference")] && [UICollectionViewCompositionalLayoutConfiguration instancesRespondToSelector:NSSelectorFromString(@"contentInsetsReference")],
          "the content insets reference of iOS 14 is there");
    UICollectionViewCompositionalLayoutConfiguration *configuration = [[UICollectionViewCompositionalLayoutConfiguration alloc] init];
    CHECK(configuration.contentInsetsReference == UIContentInsetsReferenceSafeArea && [NSCollectionLayoutSection sectionWithGroup:[NSCollectionLayoutGroup horizontalGroupWithLayoutSize:[NSCollectionLayoutSize sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1] heightDimension:[NSCollectionLayoutDimension absoluteDimension:1]] subitems:@[[NSCollectionLayoutItem itemWithLayoutSize:[NSCollectionLayoutSize sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1] heightDimension:[NSCollectionLayoutDimension absoluteDimension:1]]]]]].contentInsetsReference == UIContentInsetsReferenceAutomatic,
          "the layout refers to the safe area and a section to automatic, as the header says");
    CHECK([[NSCollectionLayoutDimension fractionalWidthDimension:0.5] isEqual:[NSCollectionLayoutDimension fractionalWidthDimension:0.5]] && ![[NSCollectionLayoutDimension fractionalWidthDimension:0.5] isEqual:[NSCollectionLayoutDimension absoluteDimension:0.5]],
          "dimensions are equal by kind and value");
    BOOL raised = NO;
    @try {
        [NSCollectionLayoutDimension fractionalWidthDimension:NAN];
    } @catch (NSException *exception) {
        raised = [exception.name isEqual:NSInternalInconsistencyException] && [exception.reason hasPrefix:@"Invalid fractional width: nan."];
    }
    CHECK(raised, "a dimension that is not finite raises as the system's does");
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
        return UIApplicationMain(argc, argv, nil, @"CharonCompositionalDelegate");
    }
}
