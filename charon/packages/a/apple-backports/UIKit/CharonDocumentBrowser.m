#import "CharonDocumentBrowser.h"

@interface CharonFileEntry : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *path;
@property (nonatomic) BOOL directory;
@property (nonatomic) unsigned long long size;
@end

@implementation CharonFileEntry
@synthesize name = _name;
@synthesize path = _path;
@synthesize directory = _directory;
@synthesize size = _size;
@end

@implementation CharonFileLocationsController {
    __weak UIDocumentPickerViewController *_picker;
    NSArray<NSDictionary *> *_locations;
}

- (instancetype)initWithPicker:(UIDocumentPickerViewController *)picker
{
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        _picker = picker;
        self.title = NSLocalizedStringFromTableInBundle(@"Locations", @"Localizable", [NSBundle bundleForClass:[UIView class]], nil);
        _locations = [picker charon_locations];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    UIDocumentPickerViewController *picker = _picker;
    self.navigationItem.rightBarButtonItem = [picker charon_cancelItem];
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
    CharonFileFolderController *folder = [[CharonFileFolderController alloc] initWithPath:location[@"path"] title:location[@"title"] picker:_picker];
    [self.navigationController pushViewController:folder animated:YES];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end

@implementation CharonFileFolderController {
    __weak UIDocumentPickerViewController *_picker;
    NSString *_path;
    NSArray<CharonFileEntry *> *_entries;
    NSMutableOrderedSet<NSString *> *_selected;
    UIBarButtonItem *_commit;
}

- (instancetype)initWithPath:(NSString *)path title:(NSString *)title picker:(UIDocumentPickerViewController *)picker
{
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        _picker = picker;
        _path = [path copy];
        // NSMutableOrderedSet arrived in iOS 5, so a band below it links this object with the class
        // symbol weak and NULL - the 4.3 gate names _OBJC_CLASS_$_NSMutableOrderedSet among the weak
        // imports the release it is checked against does not export - and this is an initialiser, so
        // the message goes out whatever the release has. The class is looked up once; a release
        // without it has no ordered set, and the selection is then nil, which every use below reads
        // as "nothing selected": the document row shows no check mark and the commit button stays
        // out, and that is what a release that cannot keep a selection gives.
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
    self.navigationItem.rightBarButtonItem = [picker charon_cancelItem];
    if (![picker charon_choosesFiles]) {
        _commit = [[UIBarButtonItem alloc] initWithTitle:[picker charon_destinationTitle] style:UIBarButtonItemStyleDone target:self action:@selector(commit)];
        self.navigationItem.rightBarButtonItems = nil;
        self.navigationItem.rightBarButtonItem = _commit;
        self.navigationItem.leftItemsSupplementBackButton = YES;
        self.navigationItem.leftBarButtonItem = [picker charon_cancelItem];
    } else if ([picker charon_allowsMultiple]) {
        _commit = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(commit)];
        _commit.enabled = NO;
        self.navigationItem.rightBarButtonItem = _commit;
        self.navigationItem.leftItemsSupplementBackButton = YES;
        self.navigationItem.leftBarButtonItem = [picker charon_cancelItem];
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
        CharonFileEntry *entry = [[CharonFileEntry alloc] init];
        entry.name = name;
        entry.path = full;
        entry.directory = directory;
        if (!directory)
            entry.size = [[manager attributesOfItemAtPath:full error:NULL] fileSize];
        [found addObject:entry];
    }
    [found sortUsingComparator:^NSComparisonResult(CharonFileEntry *left, CharonFileEntry *right) {
        if (left.directory != right.directory)
            return left.directory ? NSOrderedAscending : NSOrderedDescending;
        return [left.name localizedCaseInsensitiveCompare:right.name];
    }];
    _entries = found;
    [self.tableView reloadData];
}

- (BOOL)selectable:(CharonFileEntry *)entry
{
    UIDocumentPickerViewController *picker = _picker;
    return entry.directory || ([picker charon_choosesFiles] && [picker charon_acceptsPath:entry.path]);
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
    CharonFileEntry *entry = _entries[indexPath.row];
    UIDocumentPickerViewController *picker = _picker;
    NSString *shown = entry.name;
    if (!entry.directory && ![picker charon_showsExtensions] && entry.name.pathExtension.length && entry.name.stringByDeletingPathExtension.length)
        shown = entry.name.stringByDeletingPathExtension;
    cell.textLabel.text = shown;
    BOOL enabled = [self selectable:entry];
    cell.textLabel.textColor = enabled ? [UIColor blackColor] : [UIColor grayColor];
    // NSByteCountFormatter arrived in iOS 6, so a band below it links this object with the class
    // symbol weak and NULL (the 4.3 gate names it among the four weak imports it does not export).
    // Where it is not there the size is left off: a count nobody can format is not a number a
    // document list can show, and the name and the icon are the parts that read.
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
    CharonFileEntry *entry = _entries[indexPath.row];
    UIDocumentPickerViewController *picker = _picker;
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (entry.directory) {
        CharonFileFolderController *folder = [[CharonFileFolderController alloc] initWithPath:entry.path title:entry.name picker:picker];
        [self.navigationController pushViewController:folder animated:YES];
        return;
    }
    if (![self selectable:entry])
        return;
    if ([picker charon_allowsMultiple]) {
        if ([_selected containsObject:entry.path])
            [_selected removeObject:entry.path];
        else
            [_selected addObject:entry.path];
        _commit.enabled = _selected.count > 0;
        [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
        return;
    }
    [picker charon_pickPaths:@[entry.path]];
}

- (void)commit
{
    UIDocumentPickerViewController *picker = _picker;
    if ([picker charon_choosesFiles])
        [picker charon_pickPaths:_selected.array];
    else
        [picker charon_chooseFolder:_path];
}

@end
