#import <UIKit/UIKit.h>
#import "check.h"
#import "collectiontransition-cases.h"
#import "collectionmovement-cases.h"
#import "collectiontransition-expectations.h"
#import "collectionmovement-expectations.h"

static NSString *const results_folder = @"/private/var/backports";

@interface TransitionSource : NSObject <UICollectionViewDataSource>
@property (nonatomic) NSInteger items;
@property (nonatomic) NSInteger sections;
@end

@implementation TransitionSource
- (instancetype)init
{
    if ((self = [super init]))
        _items = 12;
    return self;
}
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return _items;
}
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return _sections;
}
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
}
@end

// Records what the collection view answers while it runs a transition between two flow layouts:
// the progress the transition layout reports, where a cell sits at either end of it, that finishing
// settles on the layout it was going to and cancelling settles back on the one it came from, and
// what each completion block is handed.
@interface TransitionDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation TransitionDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"collectiontransition.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"collectiontransition.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSDictionary *expected = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:collectiontransition_expectations length:strlen(collectiontransition_expectations)] options:0 error:NULL];
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        collectiontransition_run(^(NSString *name, NSString *value) {
            records[name] = value;
            printf("record %s: %s\n", name.UTF8String, value.UTF8String);
        });
        for (NSString *name in [expected.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            if ([expected[name] isEqualToString:records[name]])
                charon_check(YES, name.UTF8String, nil);
            else
                charon_check(NO, name.UTF8String, [NSString stringWithFormat:@"\n    device %@\n    host   %@", records[name], expected[name]]]);
        }
        NSDictionary *movementExpected = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:collectionmovement_expectations length:strlen(collectionmovement_expectations)] options:0 error:NULL];
        NSMutableDictionary *movementRecords = [NSMutableDictionary dictionary];
        collectionmovement_run(^(NSString *name, NSString *value) {
            movementRecords[name] = value;
            printf("record %s: %s\n", name.UTF8String, value.UTF8String);
        });
        for (NSString *name in [movementExpected.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            if ([movementExpected[name] isEqualToString:movementRecords[name]])
                charon_check(YES, name.UTF8String, nil);
            else
                charon_check(NO, name.UTF8String, [NSString stringWithFormat:@"\n    device %@\n    host   %@", movementRecords[name], movementExpected[name]]]);
        }
        [self run_transition];
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
        [summary writeToFile:[results_folder stringByAppendingPathComponent:@"collectiontransition.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    });
    return YES;
}

- (UICollectionView *)make_view_with:(UICollectionViewLayout *)layout
{
    UICollectionView *view = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, 320, 480) collectionViewLayout:layout];
    [view registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"cell"];
    view.dataSource = [[TransitionSource alloc] init];
    [self.window.rootViewController.view addSubview:view];
    [view reloadData];
    [view layoutIfNeeded];
    return view;
}

- (void)run_transition
{
    UICollectionViewFlowLayout *small = [[UICollectionViewFlowLayout alloc] init];
    small.itemSize = CGSizeMake(40, 40);
    UICollectionViewFlowLayout *large = [[UICollectionViewFlowLayout alloc] init];
    large.itemSize = CGSizeMake(120, 90);
    UICollectionView *view = [self make_view_with:small];
    NSIndexPath *first = [NSIndexPath indexPathForItem:0 inSection:0];
    CGRect startFrame = [view layoutAttributesForItemAtIndexPath:first].frame;

    // A transition to another layout, driven to its end: the progress ends at the end, the cell
    // has moved to where the new layout puts it, the view keeps the new layout and the completion
    // is handed a completed and a finished.
    __block BOOL called = NO, completedSeen = NO, finishedSeen = NO;
    UICollectionViewTransitionLayout *transition = [view startInteractiveTransitionToCollectionViewLayout:large
                                                                                               completion:^(BOOL completed, BOOL finished) {
        called = YES;
        completedSeen = completed;
        finishedSeen = finished;
    }];
    charon_check(transition != nil, @"startInteractiveTransition returns a layout", nil);
    charon_check(transition.currentLayout == small, @"the transition starts from the layout in place", nil);
    charon_check(transition.nextLayout == large, @"the transition goes to the layout it was given", nil);
    charon_check(!called, @"the completion waits for the transition to end", nil);
    transition.transitionProgress = 0.5;
    CGRect middle = [transition layoutAttributesForItemAtIndexPath:first].frame;
    charon_check(!CGRectEqualToRect(middle, startFrame), @"half way through, the cell has moved", nil);
    [view finishInteractiveTransition];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        charon_check(called, @"finishing calls the completion", nil);
        charon_check(completedSeen, @"finishing hands a completed completion", nil);
        charon_check(finishedSeen, @"finishing hands a finished completion", nil);
        charon_check(view.collectionViewLayout == large, @"finishing settles on the layout it went to", nil);
        CGRect endFrame = [view layoutAttributesForItemAtIndexPath:first].frame;
        charon_check(!CGRectEqualToRect(endFrame, startFrame), @"the cell ends where the new layout puts it", nil);

        // A transition that is called off settles back where it started and says it did not complete.
        __block BOOL cancelled = NO, completedSeen2 = NO, finishedSeen2 = NO;
        UICollectionViewFlowLayout *third = [[UICollectionViewFlowLayout alloc] init];
        third.itemSize = CGSizeMake(60, 60);
        UICollectionViewTransitionLayout *second = [view startInteractiveTransitionToCollectionViewLayout:third
                                                                                                 completion:^(BOOL completed, BOOL finished) {
            cancelled = YES;
            completedSeen2 = completed;
            finishedSeen2 = finished;
        }];
        charon_check(second != nil, @"a second transition starts", nil);
        [view cancelInteractiveTransition];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            charon_check(cancelled, @"cancelling calls the completion", nil);
            charon_check(!completedSeen2, @"cancelling hands a completion that did not complete", nil);
            charon_check(finishedSeen2, @"cancelling hands a finished completion", nil);
            charon_check(view.collectionViewLayout == large, @"cancelling settles back on the layout it came from", nil);

            // Setting the layout with an animation is the transition run to its end, and the
            // block there is handed a finished alone.
            __block BOOL setCalled = NO, setFinished = NO;
            UICollectionViewFlowLayout *fourth = [[UICollectionViewFlowLayout alloc] init];
            fourth.itemSize = CGSizeMake(70, 70);
            [view setCollectionViewLayout:fourth animated:YES completion:^(BOOL finished) {
                setCalled = YES;
                setFinished = finished;
            }];
            charon_check(view.collectionViewLayout != large, @"an animated layout change is under way at once", nil);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                charon_check(setCalled, @"an animated layout change calls its completion", nil);
                charon_check(setFinished, @"an animated layout change hands a finished completion", nil);
                charon_check(view.collectionViewLayout == fourth, @"an animated layout change settles on the layout asked for", nil);
                printf("checks=%d failures=%d\n", charon_checks, charon_failures);
                NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
                [summary writeToFile:[results_folder stringByAppendingPathComponent:@"collectiontransition.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
            });
        });
    });
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([TransitionDelegate class]));
    }
}
