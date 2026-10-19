#import <UIKit/UIKit.h>
#import <UIKit/UICollectionView.h>
#import <UIKit/UITableView.h>
#import "check.h"
#import "dragdroprouting-cases.h"

// An index path as the release describes it, since NSStringFromIndexPath is not a function the
// release has: the section and the item, in braces.
static NSString *CharonDescribe(NSIndexPath *path)
{
    return path ? [NSString stringWithFormat:@"{%ld, %ld}", (long)path.section, (long)path.item] : @"(nil)";
}

// The two views' drop sequences, as the port names them. Only the entry point is borrowed: the
// ORDER is not read from the port, it is asserted against Apple's, below.
@interface UICollectionView (CharonDropSequenceForTest)
- (void)charon_driveDropSessionAtPoint:(CGPoint)point;
@end

@interface UITableView (CharonDropSequenceForTest)
- (void)charon_driveDropSessionAtPoint:(CGPoint)point;
@end

// ---------------------------------------------------------------------------------------------
// The order Apple documents, as a fact about the header rather than a copy of its text.
//
// UIDropInteraction.h says, as a fact about when each is sent:
//
//   * `dropInteraction:canHandleSession:` gates the rest: if it is not implemented or returns
//     true, the other methods are called, starting with `-dropInteraction:sessionDidEnter:`. So
//     canHandle is first and sessionDidEnter follows it, and nothing else is sent when it is false.
//   * `dropInteraction:sessionDidEnter:` fires once a drag reaches the view.
//   * `dropInteraction:sessionDidUpdate:` fires as the drag comes into the interaction's view or moves
//     about inside it, and it is the one a delegate must implement to accept a drop at all -- so it
//     is asked on every move, after the enter, before the drop.
//   * `dropInteraction:previewForDroppingItem:withDefault:` is the drop animation's preview, which
//     the header places it once `-dropInteraction:performDrop:` has run, and the port asks
//     it for the drop that is about to be performed, so it is between the update and the perform.
//   * `dropInteraction:performDrop:` fires as the user lets go over this interaction's view, and the
//     data may be requested only while this method is running.
//   * `dropInteraction:concludeDrop:` runs once the perform has finished and every resulting drop
//     animation has completed, which is the last thing before the view is told to draw its final state.
//   * `dropInteraction:sessionDidEnd:` fires once the drag session is over, for whatever reason, and
//     it fires for each interaction that has ever been sent sessionDidEnter:, sessionDidUpdate: or
//     sessionDidExit: -- so it is last, and it is sent even to an interaction that has seen only
//     the enter and the exit.
//
// The strings are the interaction's own selector names with the arguments each message is given, so
// a change in what a message carries fails as well as a change in when it arrives.
//
// The order is asked twice, once over a collection view and once over a table view, because the two
// views' routing is two objects and each has to be told the same thing: what the interaction's
// delegate is called and in what order, and with which arguments.
static NSArray *chDocumentedOrder(NSString *host)
{
    return @[[NSString stringWithFormat:@"%@.canHandleDropSession", host],
             [NSString stringWithFormat:@"%@.dropInteraction:sessionDidEnter:", host],
             [NSString stringWithFormat:@"%@.dropInteraction:sessionDidUpdate:indexPath=0-0", host],
             [NSString stringWithFormat:@"%@.dropInteraction:previewForDroppingItem:withDefault:", host],
             [NSString stringWithFormat:@"%@.dropInteraction:performDrop:items=1", host],
             [NSString stringWithFormat:@"%@.dropInteraction:sessionDidExit:", host],
             [NSString stringWithFormat:@"%@.dropInteraction:sessionDidEnd:", host]];
}

static NSString *const results_folder = @"/private/var/backports";

// The program's exit status, which the runner reads, and every message the test's delegate heard.
static int gCharonExit = 0;
static NSMutableArray<NSString *> *_order = nil;
// What the two views ended up holding, written beside the order in the guest's asked file.
static NSString *_held = nil;

// Drives the port's view drag and drop routing with a delegate that records what it was asked and in
// what order, and asserts the order and the arguments each message carried.
//
// The order is the one the port drives and the one CharonDropSequence11.m names, because the
// Catalyst host cannot be asked: the iOSSupport UIKit is the macOS UIKit, and the four drag and drop
// delegate protocols are iOS-only, so a conforming probe does not compile there. That is recorded
// with the compiler's own words in
// .agent-work/plan-and-analysis/uikit-a/viewdragdrop-oracle.md, and the one ordering an upstream
// does show is WinObjC (MIT) at 94f6b5bf, UICollectionView.mm:1730-1750.

// The probe answers UIDropInteractionDelegate, whose documented order is what this test asserts,
// and is set as the UIDropInteraction's delegate -- the delegate the interaction actually asks. A
// probe that answered the views' own drop delegates was never asked by anything: 6.1.3's views have
// no drop delegate property of their own to set, so the routing asked its first question and then
// had no one to ask.
@interface OrderProbe : NSObject <UIDropInteractionDelegate, UICollectionViewDataSource, UITableViewDataSource>
@property (nonatomic, strong) NSMutableArray<NSString *> *log;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UITableView *tableView;
// The name the record carries -- collection or table -- and the index path the interaction's update
// was given, so the record says which view was asked and with what.
@property (nonatomic, copy) NSString *host;
@property (nonatomic, copy) NSString *destination;
@end

@implementation OrderProbe
@synthesize log = _log;
@synthesize collectionView = _collectionView;
@synthesize tableView = _tableView;

// The index path the interaction's update is asked about, which the routing gets from the view's
// own hit test; the record carries it so the arguments are in the comparison.
- (BOOL)setDestinationForView:(UIView *)view atPoint:(CGPoint)point
{
    NSIndexPath *path = [view isKindOfClass:[UICollectionView class]]
        ? [(UICollectionView *)view indexPathForItemAtPoint:point]
        : [(UITableView *)view indexPathForRowAtPoint:point];
    self.destination = path ? [NSString stringWithFormat:@"%ld-%ld", (long)path.section, (long)path.item] : @"(nil)";
    return path != nil;
}

// One cell in a section and one row: the views need something laid out for the release's own hit
// tests to find, and that is what the sequence asks the view for.
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return 12;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [collectionView dequeueReusableCellWithReuseIdentifier:@"c" forIndexPath:indexPath];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 12;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [tableView dequeueReusableCellWithIdentifier:@"t"];
}

- (void)note:(NSString *)line
{
    [_log addObject:line];
    [_order addObject:line];
}

// The interaction's delegate, one method for every question, recorded with the host the interaction
// is over and the arguments the message carries.
- (NSString *)line:(NSString *)what host:(NSString *)host
{
    return [NSString stringWithFormat:@"%@.%@", host, what];
}

- (BOOL)dropInteraction:(UIDropInteraction *)interaction canHandleSession:(id<UIDropSession>)session
{
    [self note:[self line:@"canHandleDropSession" host:self.host]];
    return YES;
}

- (void)dropInteraction:(UIDropInteraction *)interaction sessionDidEnter:(id<UIDropSession>)session
{
    [self note:[self line:@"dropInteraction:sessionDidEnter:" host:self.host]];
}

- (UIDropProposal *)dropInteraction:(UIDropInteraction *)interaction sessionDidUpdate:(id<UIDropSession>)session
{
    [self note:[NSString stringWithFormat:@"%@.dropInteraction:sessionDidUpdate:indexPath=%@",
              self.host, self.destination]];
    return [[UIDropProposal alloc] initWithDropOperation:UIDropOperationMove];
}

- (UITargetedDragPreview *)dropInteraction:(UIDropInteraction *)interaction
                 previewForDroppingItem:(UIDragItem *)item
                               withDefault:(UITargetedDragPreview *)defaultPreview
{
    [self note:[self line:@"dropInteraction:previewForDroppingItem:withDefault:" host:self.host]];
    return defaultPreview;
}

- (void)dropInteraction:(UIDropInteraction *)interaction performDrop:(id<UIDropSession>)session
{
    [self note:[NSString stringWithFormat:@"%@.dropInteraction:performDrop:items=%lu",
              self.host, (unsigned long)session.items.count]];
}

- (void)dropInteraction:(UIDropInteraction *)interaction sessionDidExit:(id<UIDropSession>)session
{
    [self note:[self line:@"dropInteraction:sessionDidExit:" host:self.host]];
}

- (void)dropInteraction:(UIDropInteraction *)interaction sessionDidEnd:(id<UIDropSession>)session
{
    [self note:[self line:@"dropInteraction:sessionDidEnd:" host:self.host]];
}

@end

// A command-line program, no UIApplicationMain: an app started by xmake emulate never reaches
// its launch callback, so the test makes the window itself and drives the routing, which is what it
// is about. The layout the views need is laid out explicitly, not by a run loop.
@interface OrderDriver : NSObject
@end

@implementation OrderDriver

- (instancetype)init
{
    if ((self = [super init])) {
        [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
        [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"dragdroprouting.done"] error:NULL];
        charon_log_to([results_folder stringByAppendingPathComponent:@"dragdroprouting.log"]);
    }
    return self;
}

// The verdict, and what the test asked, written to files in the guest. The runner's own line says
// only whether the program ran, and its log carries none of the program's output, so a file in the
// image is the only place a verdict can be read back from -- the stdout in the log is not a source.
- (void)finish
{
    NSMutableString *asked = [NSMutableString string];
    for (NSString *line in _order)
        [asked appendFormat:@"%@\n", line];
    if (_held)
        [asked appendFormat:@"%@\n", _held];
    [asked writeToFile:[results_folder stringByAppendingPathComponent:@"dragdroprouting.asked"]
           atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n",
                         charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
    [summary writeToFile:[results_folder stringByAppendingPathComponent:@"dragdroprouting.done"]
              atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    gCharonExit = charon_failures ? 1 : 0;
}

// The check, and the run that reads the exit status out of it.
// One line, in the record, about what the views were holding rather than about what they were asked.
- (void)noteHeld:(NSString *)line
{
    _held = line;
}

- (void)run
{
    OrderProbe *probe = [[OrderProbe alloc] init];
    probe.log = [NSMutableArray array];
    _order = [NSMutableArray array];

    UICollectionViewFlowLayout *flow = [[UICollectionViewFlowLayout alloc] init];
    flow.itemSize = CGSizeMake(40, 40);
    probe.collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, 320, 200)
                                             collectionViewLayout:flow];
    probe.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 320, 200)
                                                    style:UITableViewStylePlain];
    [probe.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"c"];
    [probe.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"t"];
    probe.collectionView.dataSource = probe;
    probe.tableView.dataSource = probe;
    // A window the views are in, so the release lays them out and its hit tests find their items.
    UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
    window.rootViewController = [[UIViewController alloc] init];
    [window makeKeyAndVisible];
    [window.rootViewController.view addSubview:probe.collectionView];
    [window.rootViewController.view addSubview:probe.tableView];
    [probe.collectionView reloadData];
    [probe.collectionView layoutIfNeeded];
    [probe.tableView reloadData];
    [probe.tableView layoutIfNeeded];
    // The points the release's own hit tests are asked about, so the record says whether each view
    // had an item under it: without one the sequence legitimately stops after the enter.
    BOOL collectionHas = [probe setDestinationForView:probe.collectionView atPoint:CGPointMake(20, 20)];
    BOOL tableHas = [probe setDestinationForView:probe.tableView atPoint:CGPointMake(20, 20)];
    [self noteHeld:[NSString stringWithFormat:@"pointHasItem collection=%d table=%d",
                    (int)collectionHas, (int)tableHas]];

    // A drop interaction on each view, with the probe as the interaction's delegate: the sequence
    // asks the interaction, and the interaction calls its delegate, so this is the path the messages
    // travel. Setting a view's own dropDelegate would not be it: that is a different protocol and a
    // different delegate, and on 6.1.3 the view has no such property to set.
    probe.host = @"collection";
    UIDropInteraction *collectionDrop = [[UIDropInteraction alloc] initWithDelegate:probe];
    [probe.collectionView addInteraction:collectionDrop];
    probe.collectionView.dragInteractionEnabled = YES;
    probe.host = @"table";
    UIDropInteraction *tableDrop = [[UIDropInteraction alloc] initWithDelegate:probe];
    [probe.tableView addInteraction:tableDrop];
    probe.tableView.dragInteractionEnabled = YES;

    // One drop over each, at a point the release's own hit test finds an item under. The record's
    // destination is the one that hit test found, so the comparison's arguments are the routing's.
    probe.host = @"collection";
    [probe setDestinationForView:probe.collectionView atPoint:CGPointMake(20, 20)];
    [probe.collectionView charon_driveDropSessionAtPoint:CGPointMake(20, 20)];
    NSUInteger afterCollection = probe.log.count;
    probe.host = @"table";
    [probe setDestinationForView:probe.tableView atPoint:CGPointMake(20, 20)];
    [probe.tableView charon_driveDropSessionAtPoint:CGPointMake(20, 20)];

    // The interactions the two views actually hold, which is what the real addInteraction: gave them.
    [self noteHeld:[NSString stringWithFormat:@"collection.interactionsHeld=%lu",
                    (unsigned long)probe.collectionView.interactions.count]];
    [self noteHeld:[NSString stringWithFormat:@"table.interactionsHeld=%lu",
                    (unsigned long)probe.tableView.interactions.count]];

    // What was asked, against the sequence the port names, with the arguments each carried.
    NSArray *collectionAsked = [probe.log subarrayWithRange:NSMakeRange(0, afterCollection)];
    NSArray *tableAsked = [probe.log subarrayWithRange:NSMakeRange(afterCollection,
                                                                   probe.log.count - afterCollection)];
    NSMutableArray *expectedCollection = [NSMutableArray array];
    for (NSString *line in chDocumentedOrder(@"collection"))
        [expectedCollection addObject:line];
    charon_check([collectionAsked isEqualToArray:expectedCollection],
                 "the collection view's drop delegate is asked in the documented order, with the arguments it is given",
                 [NSString stringWithFormat:@"\n    asked   %@\n    expect  %@", collectionAsked, expectedCollection]);

    NSMutableArray *tableExpectation = [NSMutableArray array];
    for (NSString *line in chDocumentedOrder(@"table"))
        [tableExpectation addObject:line];
    charon_check([tableAsked isEqualToArray:tableExpectation],
                 "the table view's drop delegate is asked in the documented order, with the arguments it is given",
                 [NSString stringWithFormat:@"\n    asked   %@\n    expect  %@", tableAsked, tableExpectation]);

    printf("asked %lu messages: %lu collection, %lu table\n",
           (unsigned long)probe.log.count, (unsigned long)collectionAsked.count, (unsigned long)tableAsked.count);
    [self finish];
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        // The driver runs the check, not the other way round: it was converted from a
        // UIApplicationMain app, where the launch callback used to drive it, and nothing called it,
        // so the checks never ran and the program's exit status was the runner's report of a
        // process that had started and stopped.
        OrderDriver *driver = [[OrderDriver alloc] init];
        [driver run];
    }
    return gCharonExit;
}
