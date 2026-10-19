#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import "check.h"

@interface Delegate : NSObject <UIDragInteractionDelegate, UIDropInteractionDelegate, UITableViewDragDelegate, UITableViewDropDelegate, UICollectionViewDragDelegate, UICollectionViewDropDelegate>
@end
@implementation Delegate
@end

static NSString *image_of(void *address)
{
    Dl_info info;
    return address && dladdr(address, &info) && info.dli_fname ? @(info.dli_fname).lastPathComponent : @"?";
}

static NSString *describe(UIDropProposal *proposal)
{
    return [NSString stringWithFormat:@"%lu %d %d", (unsigned long)proposal.operation, proposal.isPrecise, proposal.prefersFullSizePreview];
}

static void proposals(void)
{
    for (NSUInteger operation = 0; operation < 5; operation++) {
        UIDropProposal *proposal = [[UIDropProposal alloc] initWithDropOperation:(UIDropOperation)operation];
        CHECK_EQUAL(describe(proposal), ([NSString stringWithFormat:@"%lu 0 1", (unsigned long)operation]), "proposal starts precise NO and full size YES");
        proposal.precise = YES;
        proposal.prefersFullSizePreview = NO;
        UIDropProposal *copy = [proposal copy];
        CHECK_EQUAL(describe(copy), ([NSString stringWithFormat:@"%lu 1 0", (unsigned long)operation]), "proposal copy keeps every setting");
        CHECK(copy != proposal && [copy isKindOfClass:[UIDropProposal class]], "proposal copy is a new proposal");
    }
    CHECK_EQUAL(image_of((__bridge void *)[UIDropProposal class]), @"libUIKitBackports.dylib", "UIDropProposal comes from the backports");
}

static void items(void)
{
    NSItemProvider *provider = [[NSItemProvider alloc] init];
    UIDragItem *item = [[UIDragItem alloc] initWithItemProvider:provider];
    CHECK(item.itemProvider == provider, "the provider is kept by identity");
    CHECK(item.localObject == nil && item.previewProvider == nil, "local object and preview provider start nil");
    NSObject *local = [NSObject new];
    item.localObject = local;
    CHECK(item.localObject == local, "the local object is kept by identity");
    __block int calls = 0;
    item.previewProvider = ^UIDragPreview *{ calls++; return nil; };
    CHECK(item.previewProvider != nil && item.previewProvider() == nil && calls == 1, "the preview provider is kept and callable");
    item.previewProvider = nil;
    CHECK(item.previewProvider == nil, "the preview provider is cleared");
    UIDragItem *empty = [[UIDragItem alloc] initWithItemProvider:nil];
    CHECK(empty != nil && empty.itemProvider == nil, "an item with no provider is made");
    CHECK_EQUAL(image_of((__bridge void *)[UIDragItem class]), @"libUIKitBackports.dylib", "UIDragItem comes from the backports");
}

static void interactions(void)
{
    Delegate *delegate = [Delegate new];
    UIDragInteraction *drag = [[UIDragInteraction alloc] initWithDelegate:delegate];
    CHECK(drag.delegate == delegate && drag.view == nil, "the drag delegate is kept, no view yet");
    CHECK([UIDragInteraction isEnabledByDefault] == NO, "dragging is not enabled by default: nothing here carries a drag");
    CHECK(drag.isEnabled == NO && drag.allowsSimultaneousRecognitionDuringLift == NO, "a new drag interaction is not enabled");
    drag.enabled = YES;
    CHECK(drag.isEnabled, "enabled reads what was set");
    drag.enabled = NO;
    CHECK(!drag.isEnabled, "enabled reads NO once set to NO");
    drag.allowsSimultaneousRecognitionDuringLift = YES;
    CHECK(drag.allowsSimultaneousRecognitionDuringLift, "lift recognition is kept");
    UIView *view = [UIView new];
    [view addInteraction:drag];
    CHECK(drag.view == view && [view.interactions containsObject:drag], "the view holds the drag interaction");
    [view removeInteraction:drag];
    CHECK(drag.view == nil, "the view lets it go");
    Delegate *gone = [Delegate new];
    UIDragInteraction *weakDrag = [[UIDragInteraction alloc] initWithDelegate:gone];
    gone = nil;
    CHECK(weakDrag.delegate == nil, "the drag delegate is weak");
    UIDropInteraction *drop = [[UIDropInteraction alloc] initWithDelegate:delegate];
    CHECK(drop.delegate == delegate && drop.view == nil && drop.allowsSimultaneousDropSessions == NO, "a new drop interaction");
    drop.allowsSimultaneousDropSessions = YES;
    CHECK(drop.allowsSimultaneousDropSessions, "simultaneous drop sessions are kept");
    [view addInteraction:drop];
    CHECK(drop.view == view, "the view holds the drop interaction");
    [view removeInteraction:drop];
    CHECK(drop.view == nil, "the view lets the drop interaction go");
    UIDropInteraction *weakDrop = [[UIDropInteraction alloc] initWithDelegate:[Delegate new]];
    CHECK(weakDrop.delegate == nil, "the drop delegate is weak");
    CHECK_EQUAL(image_of((__bridge void *)[UIDragInteraction class]), @"libUIKitBackports.dylib", "UIDragInteraction comes from the backports");
    CHECK_EQUAL(image_of((__bridge void *)[UIDropInteraction class]), @"libUIKitBackports.dylib", "UIDropInteraction comes from the backports");
}

static void scroll_views(void)
{
    Delegate *delegate = [Delegate new];
    UITableView *table = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    CHECK(table.dragDelegate == nil && table.dropDelegate == nil && !table.hasActiveDrag && !table.hasActiveDrop, "a new table has no drag or drop");
    CHECK(table.dragInteractionEnabled == NO, "a new table does not enable dragging");
    table.dragDelegate = delegate;
    table.dropDelegate = delegate;
    table.dragInteractionEnabled = YES;
    CHECK(table.dragDelegate == delegate && table.dropDelegate == delegate && table.dragInteractionEnabled, "the table keeps what it was given");
    table.dragInteractionEnabled = NO;
    CHECK(!table.dragInteractionEnabled, "the table keeps NO");
    UITableView *other = [[UITableView alloc] initWithFrame:CGRectZero];
    CHECK(other.dragDelegate == nil, "another table is not affected");
    Delegate *gone = [Delegate new];
    other.dragDelegate = gone;
    gone = nil;
    CHECK(other.dragDelegate == nil, "the table delegate is weak");
    UICollectionView *collection = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, 100, 100) collectionViewLayout:[UICollectionViewFlowLayout new]];
    CHECK(collection.dragDelegate == nil && collection.dropDelegate == nil && !collection.hasActiveDrag && !collection.hasActiveDrop && !collection.dragInteractionEnabled, "a new collection view has no drag or drop");
    collection.dragDelegate = delegate;
    collection.dropDelegate = delegate;
    collection.dragInteractionEnabled = YES;
    CHECK(collection.dragDelegate == delegate && collection.dropDelegate == delegate && collection.dragInteractionEnabled, "the collection view keeps what it was given");
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"c"];
    CHECK(cell.userInteractionEnabledWhileDragging == NO, "a cell keeps its interaction while dragging off");
    cell.userInteractionEnabledWhileDragging = YES;
    CHECK(cell.userInteractionEnabledWhileDragging, "the cell keeps what it was given");
    [cell dragStateDidChange:UITableViewCellDragStateLifting];
    [[UICollectionViewCell new] dragStateDidChange:UICollectionViewCellDragStateDragging];
    CHECK(YES, "the drag state hooks do nothing");
    CHECK_EQUAL(image_of((void *)[UITableView instanceMethodForSelector:@selector(dragDelegate)]), @"libUIKitBackports.dylib", "the table's drag delegate comes from the backports");
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        proposals();
        items();
        interactions();
        scroll_views();
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
