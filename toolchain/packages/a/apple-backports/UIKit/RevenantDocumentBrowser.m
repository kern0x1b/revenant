#import "RevenantDocumentBrowser.h"

@interface RevenantFileEntry : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *path;
@property (nonatomic) BOOL directory;
@property (nonatomic) unsigned long long size;
@end

@implementation RevenantFileEntry
@synthesize name = _name;
@synthesize path = _path;
@synthesize directory = _directory;
@synthesize size = _size;
@end

@implementation RevenantFileLocationsController {
    __weak UIDocumentPickerViewController *_picker;
    NSArray<NSDictionary *> *_locations;
}

- (instancetype)initWithPicker:(UIDocumentPickerViewController *)picker
{
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        _picker = picker;
        self.title = NSLocalizedStringFromTableInBundle(@"Locations", @"Localizable", [NSBundle bundleForClass:[UIView class]], nil);
        _locations = [picker revenant_locations];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    UIDocumentPickerViewController *picker = _picker;
    self.navigationItem.rightBarButtonItem = [picker revenant_cancelItem];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _locations.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"location"];
    if (!cell)
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"location"];
    NSDictionary *location = _locations[indexPath.row];
    cell.textLabel.text = location[@"title"];
    cell.detailTextLabel.text = location[@"path"];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *location = _locations[indexPath.row];
    RevenantFileFolderController *folder = [[RevenantFileFolderController alloc] initWithPath:location[@"path"] title:location[@"title"] picker:_picker];
    [self.navigationController pushViewController:folder animated:YES];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end

@implementation RevenantFileFolderController {
    __weak UIDocumentPickerViewController *_picker;
    NSString *_path;
    NSArray<RevenantFileEntry *> *_entries;
    NSMutableOrderedSet<NSString *> *_selected;
    UIBarButtonItem *_commit;
}

- (instancetype)initWithPath:(NSString *)path title:(NSString *)title picker:(UIDocumentPickerViewController *)picker
{
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        _picker = picker;
        _path = [path copy];
        static Class orderedSet = nil;
        static dispatch_once_t once;
        dispatch_once(&once, ^{ orderedSet = NSClassFromString(@"NSMutableOrderedSet"); });
        _selected = orderedSet ? [orderedSet orderedSet] : nil;
        self.title = title ?: (path.length <= 1 ? @"/" : path.lastPathComponent);
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    UIDocumentPickerViewController *picker = _picker;
    self.navigationItem.rightBarButtonItem = [picker revenant_cancelItem];
    if (![picker revenant_choosesFiles]) {
        _commit = [[UIBarButtonItem alloc] initWithTitle:[picker revenant_destinationTitle] style:UIBarButtonItemStyleDone target:self action:@selector(commit)];
        self.navigationItem.rightBarButtonItems = nil;
        self.navigationItem.rightBarButtonItem = _commit;
        self.navigationItem.leftItemsSupplementBackButton = YES;
        self.navigationItem.leftBarButtonItem = [picker revenant_cancelItem];
    } else if ([picker revenant_allowsMultiple]) {
        _commit = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(commit)];
        _commit.enabled = NO;
        self.navigationItem.rightBarButtonItem = _commit;
        self.navigationItem.leftItemsSupplementBackButton = YES;
        self.navigationItem.leftBarButtonItem = [picker revenant_cancelItem];
    }
    [self reload];
}

- (void)reload
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSArray *names = [manager contentsOfDirectoryAtPath:_path error:NULL] ?: @[];
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *name in names) {
        if ([name hasPrefix:@"."])
            continue;
        NSString *full = [_path stringByAppendingPathComponent:name];
        BOOL directory = NO;
        if (![manager fileExistsAtPath:full isDirectory:&directory])
            continue;
        RevenantFileEntry *entry = [[RevenantFileEntry alloc] init];
        entry.name = name;
        entry.path = full;
        entry.directory = directory;
        if (!directory)
            entry.size = [[manager attributesOfItemAtPath:full error:NULL] fileSize];
        [found addObject:entry];
    }
    [found sortUsingComparator:^NSComparisonResult(RevenantFileEntry *left, RevenantFileEntry *right) {
        if (left.directory != right.directory)
            return left.directory ? NSOrderedAscending : NSOrderedDescending;
        return [left.name localizedCaseInsensitiveCompare:right.name];
    }];
    _entries = found;
    [self.tableView reloadData];
}

- (BOOL)selectable:(RevenantFileEntry *)entry
{
    UIDocumentPickerViewController *picker = _picker;
    return entry.directory || ([picker revenant_choosesFiles] && [picker revenant_acceptsPath:entry.path]);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _entries.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"entry"];
    if (!cell)
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"entry"];
    RevenantFileEntry *entry = _entries[indexPath.row];
    UIDocumentPickerViewController *picker = _picker;
    NSString *shown = entry.name;
    if (!entry.directory && ![picker revenant_showsExtensions] && entry.name.pathExtension.length && entry.name.stringByDeletingPathExtension.length)
        shown = entry.name.stringByDeletingPathExtension;
    cell.textLabel.text = shown;
    BOOL enabled = [self selectable:entry];
    cell.textLabel.textColor = enabled ? [UIColor blackColor] : [UIColor grayColor];
    static Class byteCountFormatter = nil;
    static dispatch_once_t formatterOnce;
    dispatch_once(&formatterOnce, ^{ byteCountFormatter = NSClassFromString(@"NSByteCountFormatter"); });
    cell.detailTextLabel.text = (!entry.directory && byteCountFormatter)
        ? [byteCountFormatter stringFromByteCount:(long long)entry.size countStyle:NSByteCountFormatterCountStyleFile]
        : nil;
    cell.accessoryType = entry.directory ? UITableViewCellAccessoryDisclosureIndicator : ([_selected containsObject:entry.path] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone);
    cell.selectionStyle = enabled ? UITableViewCellSelectionStyleBlue : UITableViewCellSelectionStyleNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    RevenantFileEntry *entry = _entries[indexPath.row];
    UIDocumentPickerViewController *picker = _picker;
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (entry.directory) {
        RevenantFileFolderController *folder = [[RevenantFileFolderController alloc] initWithPath:entry.path title:entry.name picker:picker];
        [self.navigationController pushViewController:folder animated:YES];
        return;
    }
    if (![self selectable:entry])
        return;
    if ([picker revenant_allowsMultiple]) {
        if ([_selected containsObject:entry.path])
            [_selected removeObject:entry.path];
        else
            [_selected addObject:entry.path];
        _commit.enabled = _selected.count > 0;
        [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
        return;
    }
    [picker revenant_pickPaths:@[entry.path]];
}

- (void)commit
{
    UIDocumentPickerViewController *picker = _picker;
    if ([picker revenant_choosesFiles])
        [picker revenant_pickPaths:_selected.array];
    else
        [picker revenant_chooseFolder:_path];
}

@end
