#import <UIKit/UIKit.h>
#import <objc/message.h>

void host_attach_prefixed(const char *prefix);

static int failures, checks;

static void compare(NSString *name, NSString *system, NSString *ours)
{
    checks++;
    if ([system isEqual:ours]) {
        printf("ok   %s: %s\n", name.UTF8String, system.UTF8String);
        return;
    }
    failures++;
    printf("FAIL %s: the system answers %s, the backport answers %s\n", name.UTF8String, system.UTF8String, ours.UTF8String);
}

@interface BatchSource : NSObject <UITableViewDataSource>
@property (nonatomic) NSInteger rows;
@end

@implementation BatchSource
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return _rows; }
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path
{
    return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
}
@end

static void run(BOOL ours, NSMutableArray *order, NSInteger *rowsAfter)
{
    BatchSource *source = [BatchSource new];
    source.rows = 3;
    UITableView *table = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 320, 480) style:UITableViewStylePlain];
    table.dataSource = source;
    [table reloadData];
    [table layoutIfNeeded];

    SEL selector = ours ? NSSelectorFromString(@"charonHost_performBatchUpdates:completion:") : @selector(performBatchUpdates:completion:);
    [order addObject:@"before"];
    source.rows = 5;
    void (^updates)(void) = ^{
        [order addObject:@"inside"];
        [table insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:3 inSection:0], [NSIndexPath indexPathForRow:4 inSection:0]]
                     withRowAnimation:UITableViewRowAnimationNone];
    };
    void (^completion)(BOOL) = ^(BOOL finished) { [order addObject:@"completion"]; };
    ((void (*)(id, SEL, id, id))objc_msgSend)(table, selector, updates, completion);
    [order addObject:@"after the call"];
    [table layoutIfNeeded];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    [order addObject:@"after the run loop"];

    NSString *nilBlocks = @"survived";
    @try {
        ((void (*)(id, SEL, id, id))objc_msgSend)(table, selector, (id)nil, (id)nil);
    } @catch (NSException *exception) {
        nilBlocks = [NSString stringWithFormat:@"raised %@", exception.name];
    }
    [order addObject:nilBlocks];

    source.rows = 6;
    ((void (*)(id, SEL, id, id))objc_msgSend)(table, selector, ^{
        [order addObject:@"outer"];
        ((void (*)(id, SEL, id, id))objc_msgSend)(table, selector, ^{
            [order addObject:@"inner"];
            [table insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:5 inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
        }, (id)nil);
    }, (id)nil);
    [table layoutIfNeeded];

    source.rows = 4;
    ((void (*)(id, SEL, id, id))objc_msgSend)(table, selector, ^{
        [table deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:0], [NSIndexPath indexPathForRow:1 inSection:0]]
                     withRowAnimation:UITableViewRowAnimationNone];
    }, (id)nil);
    [table layoutIfNeeded];
    [order addObject:[NSString stringWithFormat:@"after deleting two: %ld", (long)[table numberOfRowsInSection:0]]];

    ((void (*)(id, SEL, id, id))objc_msgSend)(table, selector, ^{
        [table moveRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] toIndexPath:[NSIndexPath indexPathForRow:3 inSection:0]];
    }, (id)nil);
    [table layoutIfNeeded];
    [order addObject:[NSString stringWithFormat:@"after moving one: %ld", (long)[table numberOfRowsInSection:0]]];

    __block NSInteger completions = 0;
    ((void (*)(id, SEL, id, id))objc_msgSend)(table, selector, ^{
        [table reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
    }, ^(BOOL finished) { completions++; });
    [table layoutIfNeeded];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    [order addObject:[NSString stringWithFormat:@"completions for one call: %ld", (long)completions]];

    NSString *empty = @"survived";
    @try {
        ((void (*)(id, SEL, id, id))objc_msgSend)(table, selector, ^{}, (id)nil);
    } @catch (NSException *exception) {
        empty = [NSString stringWithFormat:@"raised %@", exception.name];
    }
    [order addObject:[@"an empty block: " stringByAppendingString:empty]];

    *rowsAfter = [table numberOfRowsInSection:0];
}

int main(void)
{
    @autoreleasepool {
        host_attach_prefixed("");
        NSMutableArray *systemOrder = [NSMutableArray array], *ourOrder = [NSMutableArray array];
        NSInteger systemRows = 0, ourRows = 0;
        run(NO, systemOrder, &systemRows);
        run(YES, ourOrder, &ourRows);
        compare(@"the order of everything", [systemOrder componentsJoinedByString:@" | "], [ourOrder componentsJoinedByString:@" | "]);
        compare(@"the rows the table ends up with", [NSString stringWithFormat:@"%ld", (long)systemRows], [NSString stringWithFormat:@"%ld", (long)ourRows]);
        printf("%d of %d checks failed\n", failures, checks);
        return failures > 0;
    }
}
