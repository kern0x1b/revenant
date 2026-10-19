#import "uirest.h"

static NSArray *focus_scenario(void)
{
    NSMutableArray *lines = [NSMutableArray array];
    UICollectionView *collection = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, 100, 100) collectionViewLayout:[[UICollectionViewFlowLayout alloc] init]];
    [lines addObject:ur_line(@"collection default", ur_yes(collection.selectionFollowsFocus))];
    collection.selectionFollowsFocus = YES;
    [lines addObject:ur_line(@"collection set YES", ur_yes(collection.selectionFollowsFocus))];
    collection.selectionFollowsFocus = NO;
    [lines addObject:ur_line(@"collection set NO", ur_yes(collection.selectionFollowsFocus))];
    UITableView *table = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 100, 100) style:UITableViewStylePlain];
    [lines addObject:ur_line(@"table default", ur_yes(table.selectionFollowsFocus))];
    table.selectionFollowsFocus = YES;
    [lines addObject:ur_line(@"table set YES", ur_yes(table.selectionFollowsFocus))];
    table.selectionFollowsFocus = NO;
    [lines addObject:ur_line(@"table set NO", ur_yes(table.selectionFollowsFocus))];
    return lines;
}
