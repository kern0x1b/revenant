#import "uirest.h"

@interface Source : NSObject <UITableViewDataSource, UITableViewDelegate, UICollectionViewDataSource, UICollectionViewDelegate>
@property (nonatomic, strong) NSMutableArray *events;
@property (nonatomic, strong) Class configurationClass;
@end

@implementation Source

- (instancetype)init
{
    if ((self = [super init]))
        self.events = [NSMutableArray array];
    return self;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 5;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
}

- (id)configuration
{
    return ((id (*)(Class, SEL, id, id, id))objc_msgSend)(self.configurationClass, @selector(configurationWithIdentifier:previewProvider:actionProvider:), @"id", nil, nil);
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point
{
    [self.events addObject:[NSString stringWithFormat:@"table configuration row %ld point %@", (long)indexPath.row, NSStringFromCGPoint(point)]];
    return [self configuration];
}

- (void)tableView:(UITableView *)tableView willDisplayContextMenuWithConfiguration:(UIContextMenuConfiguration *)configuration animator:(id<UIContextMenuInteractionAnimating>)animator
{
    [self.events addObject:@"table will display"];
}

- (void)tableView:(UITableView *)tableView willEndContextMenuInteractionWithConfiguration:(UIContextMenuConfiguration *)configuration animator:(id<UIContextMenuInteractionAnimating>)animator
{
    [self.events addObject:@"table will end"];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return 4;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
}

- (UIContextMenuConfiguration *)collectionView:(UICollectionView *)collectionView contextMenuConfigurationForItemAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point
{
    [self.events addObject:[NSString stringWithFormat:@"collection configuration item %ld", (long)indexPath.item]];
    return [self configuration];
}

- (void)collectionView:(UICollectionView *)collectionView willDisplayContextMenuWithConfiguration:(UIContextMenuConfiguration *)configuration animator:(id<UIContextMenuInteractionAnimating>)animator
{
    [self.events addObject:@"collection will display"];
}

- (void)collectionView:(UICollectionView *)collectionView willEndContextMenuInteractionWithConfiguration:(UIContextMenuConfiguration *)configuration animator:(id<UIContextMenuInteractionAnimating>)animator
{
    [self.events addObject:@"collection will end"];
}

@end

@interface NoMenu : NSObject <UITableViewDataSource, UITableViewDelegate>
@end

@implementation NoMenu

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
}

@end

@interface UIScrollView (CharonHostMenu)
- (UIContextMenuInteraction *)charonHostContextMenuInteraction;
@end

@interface NSObject (CharonHostMenuDelegate)
- (UIContextMenuConfiguration *)contextMenuInteraction:(id)interaction configurationForMenuAtLocation:(CGPoint)location;
- (void)contextMenuInteraction:(id)interaction willDisplayMenuForConfiguration:(id)configuration animator:(id)animator;
- (void)contextMenuInteraction:(id)interaction willEndForConfiguration:(id)configuration animator:(id)animator;
@end

void charon_windowed_run(UIWindow *window)
{
    @autoreleasepool {
        Class configurationClass = NSClassFromString(@"CharonHostUIContextMenuConfiguration"), interactionClass = NSClassFromString(@"CharonHostUIContextMenuInteraction");
        charon_check(configurationClass && interactionClass, "the port's classes are linked under their host names", @"missing");
        Source *source = [[Source alloc] init];
        source.configurationClass = configurationClass;
        UITableView *table = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 320, 400) style:UITableViewStylePlain];
        table.dataSource = source;
        table.rowHeight = 44;
        [window addSubview:table];
        table.delegate = source;
        [table reloadData];
        [table layoutIfNeeded];
        UIContextMenuInteraction *interaction = [table charonHostContextMenuInteraction];
        id owner = interaction.delegate;
        charon_check([interaction isKindOfClass:interactionClass] && owner != nil, "a table whose delegate wants a menu has an interaction of the port", @"it has not");
        charon_check(interaction == [table charonHostContextMenuInteraction], "the table answers one interaction", @"it answers another");
        charon_check([table.interactions containsObject:interaction], "the interaction is on the table", @"it is not");
        UIContextMenuConfiguration *configuration = [owner contextMenuInteraction:interaction configurationForMenuAtLocation:CGPointMake(10, 44 * 2 + 5)];
        charon_check(configuration != nil && [source.events.lastObject isEqualToString:@"table configuration row 2 point {10, 93}"], "the delegate is asked for the row under the point, with the point", ur_norm(source.events));
        [source.events removeAllObjects];
        charon_check([owner contextMenuInteraction:interaction configurationForMenuAtLocation:CGPointMake(10, 44 * 5 + 5)] == nil && source.events.count == 0, "no row, no question", ur_norm(source.events));
        [owner contextMenuInteraction:interaction willDisplayMenuForConfiguration:configuration animator:nil];
        [owner contextMenuInteraction:interaction willEndForConfiguration:configuration animator:nil];
        charon_check([source.events isEqual:@[@"table will display", @"table will end"]], "the delegate hears the menu appear and end", ur_norm(source.events));

        NoMenu *none = [[NoMenu alloc] init];
        UITableView *plain = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 320, 400) style:UITableViewStylePlain];
        plain.dataSource = none;
        plain.delegate = none;
        NSUInteger before = plain.interactions.count;
        UIContextMenuInteraction *made = [plain charonHostContextMenuInteraction];
        charon_check(made != nil && plain.interactions.count == before + 1, "asking a table with no menu delegate still answers an interaction of its own", @"it does not");
        charon_check([(id)made.delegate contextMenuInteraction:made configurationForMenuAtLocation:CGPointMake(10, 10)] == nil, "and that interaction shows nothing", @"it shows something");

        UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
        layout.itemSize = CGSizeMake(100, 50);
        UICollectionView *collection = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, 320, 400) collectionViewLayout:layout];
        [collection registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"cell"];
        collection.dataSource = source;
        [window addSubview:collection];
        [source.events removeAllObjects];
        collection.delegate = source;
        [collection reloadData];
        [collection layoutIfNeeded];
        UIContextMenuInteraction *citem = [collection charonHostContextMenuInteraction];
        id cowner = citem.delegate;
        charon_check([citem isKindOfClass:interactionClass] && [collection.interactions containsObject:citem], "a collection view whose delegate wants a menu has an interaction of the port", @"it has not");
        UIContextMenuConfiguration *cconfiguration = [cowner contextMenuInteraction:citem configurationForMenuAtLocation:CGPointMake(110, 10)];
        charon_check(cconfiguration != nil && [source.events.lastObject isEqualToString:@"collection configuration item 1"], "the delegate is asked for the item under the point", ur_norm(source.events));
        [source.events removeAllObjects];
        [cowner contextMenuInteraction:citem willDisplayMenuForConfiguration:cconfiguration animator:nil];
        [cowner contextMenuInteraction:citem willEndForConfiguration:cconfiguration animator:nil];
        charon_check([source.events isEqual:@[@"collection will display", @"collection will end"]], "the collection delegate hears the menu appear and end", ur_norm(source.events));
    }
}
