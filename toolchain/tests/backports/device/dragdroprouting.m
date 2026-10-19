#import <UIKit/UIKit.h>
#import <UIKit/UICollectionView.h>
#import <UIKit/UITableView.h>
#import "check.h"
#import "dragdroprouting-cases.h"

static NSString *CharonDescribe(NSIndexPath *path)
{
    return path ? [NSString stringWithFormat:@"{%ld, %ld}", (long)path.section, (long)path.item] : @"(nil)";
}

@interface UICollectionView (CharonDropSequenceForTest)
- (void)charon_driveDropSessionAtPoint:(CGPoint)point;
@end

@interface UITableView (CharonDropSequenceForTest)
- (void)charon_driveDropSessionAtPoint:(CGPoint)point;
@end

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

static int gCharonExit = 0;
static NSMutableArray<NSString *> *_order = nil;
static NSString *_held = nil;

@interface OrderProbe : NSObject <UIDropInteractionDelegate, UICollectionViewDataSource, UITableViewDataSource>
@property (nonatomic, strong) NSMutableArray<NSString *> *log;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, copy) NSString *host;
@property (nonatomic, copy) NSString *destination;
@end

@implementation OrderProbe
@synthesize log = _log;
@synthesize collectionView = _collectionView;
@synthesize tableView = _tableView;

- (BOOL)setDestinationForView:(UIView *)view atPoint:(CGPoint)point
{
    NSIndexPath *path = [view isKindOfClass:[UICollectionView class]]
        ? [(UICollectionView *)view indexPathForItemAtPoint:point]
        : [(UITableView *)view indexPathForRowAtPoint:point];
    self.destination = path ? [NSString stringWithFormat:@"%ld-%ld", (long)path.section, (long)path.item] : @"(nil)";
    return path != nil;
}

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
    UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
    window.rootViewController = [[UIViewController alloc] init];
    [window makeKeyAndVisible];
    [window.rootViewController.view addSubview:probe.collectionView];
    [window.rootViewController.view addSubview:probe.tableView];
    [probe.collectionView reloadData];
    [probe.collectionView layoutIfNeeded];
    [probe.tableView reloadData];
    [probe.tableView layoutIfNeeded];
    BOOL collectionHas = [probe setDestinationForView:probe.collectionView atPoint:CGPointMake(20, 20)];
    BOOL tableHas = [probe setDestinationForView:probe.tableView atPoint:CGPointMake(20, 20)];
    [self noteHeld:[NSString stringWithFormat:@"pointHasItem collection=%d table=%d",
                    (int)collectionHas, (int)tableHas]];

    probe.host = @"collection";
    UIDropInteraction *collectionDrop = [[UIDropInteraction alloc] initWithDelegate:probe];
    [probe.collectionView addInteraction:collectionDrop];
    probe.collectionView.dragInteractionEnabled = YES;
    probe.host = @"table";
    UIDropInteraction *tableDrop = [[UIDropInteraction alloc] initWithDelegate:probe];
    [probe.tableView addInteraction:tableDrop];
    probe.tableView.dragInteractionEnabled = YES;

    probe.host = @"collection";
    [probe setDestinationForView:probe.collectionView atPoint:CGPointMake(20, 20)];
    [probe.collectionView charon_driveDropSessionAtPoint:CGPointMake(20, 20)];
    NSUInteger afterCollection = probe.log.count;
    probe.host = @"table";
    [probe setDestinationForView:probe.tableView atPoint:CGPointMake(20, 20)];
    [probe.tableView charon_driveDropSessionAtPoint:CGPointMake(20, 20)];

    [self noteHeld:[NSString stringWithFormat:@"collection.interactionsHeld=%lu",
                    (unsigned long)probe.collectionView.interactions.count]];
    [self noteHeld:[NSString stringWithFormat:@"table.interactionsHeld=%lu",
                    (unsigned long)probe.tableView.interactions.count]];

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
        OrderDriver *driver = [[OrderDriver alloc] init];
        [driver run];
    }
    return gCharonExit;
}
