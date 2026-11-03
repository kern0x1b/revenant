#import <UIKit/UIKit.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "RevenantDocumentBrowser.h"
#import "RevenantUTType.h"
#import "RevenantDocumentPickerRules.h"

@implementation UIDocumentPickerViewController {
    UIDocumentPickerMode _documentPickerMode;
    __weak id<UIDocumentPickerDelegate> _delegate;
    BOOL _allowsMultipleSelection;
    BOOL _shouldShowFileExtensions;
    NSURL *_directoryURL;
    NSArray<NSString *> *_documentTypes;
    NSArray<NSURL *> *_URLs;
    UINavigationController *_browser;
}

- (instancetype)initWithDocumentTypes:(NSArray<NSString *> *)allowedUTIs inMode:(UIDocumentPickerMode)mode
{
    if (mode != UIDocumentPickerModeImport && mode != UIDocumentPickerModeOpen)
        [NSException raise:NSInternalInconsistencyException format:@"-[UIDocumentPickerViewController initWithDocumentTypes:inMode:] can only be called with mode Import or Open"];
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _documentTypes = [allowedUTIs copy];
        _documentPickerMode = mode;
    }
    return self;
}

- (instancetype)initWithURLs:(NSArray<NSURL *> *)urls inMode:(UIDocumentPickerMode)mode calledBy:(NSString *)caller
{
    if (!urls)
        [NSException raise:NSInternalInconsistencyException format:@"-[UIDocumentPickerViewController %@] must be called with a valid URL", caller];
    for (NSURL *url in urls) {
        NSError *error = nil;
        if ([url isFileURL] && ![url checkResourceIsReachableAndReturnError:&error])
            [NSException raise:NSInternalInconsistencyException format:@"-[UIDocumentPickerViewController %@] must be called with a URL pointing to an existing file: %@", caller, error];
    }
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _URLs = [urls copy];
        _documentPickerMode = mode;
    }
    return self;
}

- (instancetype)initWithURL:(NSURL *)url inMode:(UIDocumentPickerMode)mode
{
    if (mode != UIDocumentPickerModeExportToService && mode != UIDocumentPickerModeMoveToService)
        [NSException raise:NSInternalInconsistencyException format:@"-[UIDocumentPickerViewController initWithURL:inMode:] can only be called with mode Export or Move"];
    return [self initWithURLs:url ? @[url] : nil inMode:mode calledBy:@"initWithURL:inMode:"];
}

- (instancetype)initWithURLs:(NSArray<NSURL *> *)urls inMode:(UIDocumentPickerMode)mode
{
    if (mode != UIDocumentPickerModeExportToService && mode != UIDocumentPickerModeMoveToService)
        [NSException raise:NSInternalInconsistencyException format:@"-[UIDocumentPickerViewController initWithURLs:inMode:] can only be called with mode Export or Move"];
    return [self initWithURLs:urls inMode:mode calledBy:@"initWithURLs:inMode:"];
}

- (instancetype)initForOpeningContentTypes:(NSArray<UTType *> *)contentTypes asCopy:(BOOL)asCopy
{
    NSMutableArray<NSString *> *identifiers = [NSMutableArray arrayWithCapacity:contentTypes.count];
    for (UTType *type in contentTypes)
        [identifiers addObject:type.identifier];
    return [self initWithDocumentTypes:identifiers inMode:asCopy ? UIDocumentPickerModeImport : UIDocumentPickerModeOpen];
}

- (instancetype)initForOpeningContentTypes:(NSArray<UTType *> *)contentTypes
{
    return [self initForOpeningContentTypes:contentTypes asCopy:NO];
}

- (instancetype)initForExportingURLs:(NSArray<NSURL *> *)urls asCopy:(BOOL)asCopy
{
    return [self initWithURLs:urls inMode:asCopy ? UIDocumentPickerModeExportToService : UIDocumentPickerModeMoveToService calledBy:@"initForExportingURLs:asCopy:"];
}

- (instancetype)initForExportingURLs:(NSArray<NSURL *> *)urls
{
    return [self initForExportingURLs:urls asCopy:NO];
}

- (instancetype)init
{
    [NSException raise:NSInvalidArgumentException format:@"You cannot initialize a UIDocumentPickerViewController except by the initWithDocumentTypes:inMode: and initWithURL:inMode: initializers."];
    return nil;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    [NSException raise:NSInvalidArgumentException format:@"You cannot initialize a UIDocumentPickerViewController except by the initWithDocumentTypes:inMode: and initWithURL:inMode: initializers."];
    return nil;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [super initWithCoder:coder];
}

- (UIDocumentPickerMode)documentPickerMode
{
    return _documentPickerMode;
}

- (id<UIDocumentPickerDelegate>)delegate
{
    return _delegate;
}

- (void)setDelegate:(id<UIDocumentPickerDelegate>)delegate
{
    _delegate = delegate;
}

- (BOOL)allowsMultipleSelection
{
    return _allowsMultipleSelection;
}

- (void)setAllowsMultipleSelection:(BOOL)allows
{
    _allowsMultipleSelection = allows;
}

- (BOOL)shouldShowFileExtensions
{
    return _shouldShowFileExtensions;
}

- (void)setShouldShowFileExtensions:(BOOL)shows
{
    _shouldShowFileExtensions = shows;
}

- (NSURL *)directoryURL
{
    return _directoryURL;
}

- (void)setDirectoryURL:(NSURL *)URL
{
    _directoryURL = [URL copy];
}

- (void)loadView
{
    UIView *view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    view.backgroundColor = [UIColor whiteColor];
    self.view = view;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    if (_browser)
        return;
    UIViewController *root = [[RevenantFileLocationsController alloc] initWithPicker:self];
    _browser = [[UINavigationController alloc] initWithRootViewController:root];
    NSString *start = [self revenant_startFolder];
    if (start) {
        NSDictionary *base = revenant_picker_base_location(start, [self revenant_locations]);
        NSString *floor = base[@"path"];
        NSMutableArray *stack = [NSMutableArray arrayWithObject:root];
        for (NSString *path in revenant_picker_folder_chain(start, floor))
            [stack addObject:[[RevenantFileFolderController alloc] initWithPath:path title:[path isEqualToString:floor] ? base[@"title"] : nil picker:self]];
        _browser.viewControllers = stack;
    }
    [self addChildViewController:_browser];
    _browser.view.frame = self.view.bounds;
    _browser.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_browser.view];
    [_browser didMoveToParentViewController:self];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    if (!CGRectEqualToRect(_browser.view.frame, self.view.bounds))
        _browser.view.frame = self.view.bounds;
}

- (UIModalPresentationStyle)modalPresentationStyle
{
    return [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad ? UIModalPresentationFormSheet : UIModalPresentationFullScreen;
}

- (BOOL)revenant_choosesFiles
{
    return _documentPickerMode == UIDocumentPickerModeImport || _documentPickerMode == UIDocumentPickerModeOpen;
}

- (BOOL)revenant_allowsMultiple
{
    return _allowsMultipleSelection && [self revenant_choosesFiles];
}

- (BOOL)revenant_showsExtensions
{
    return _shouldShowFileExtensions;
}

- (NSString *)revenant_destinationTitle
{
    return _documentPickerMode == UIDocumentPickerModeMoveToService ? @"Move" : @"Copy";
}

- (BOOL)revenant_acceptsPath:(NSString *)path
{
    return revenant_picker_accepts_path(path, _documentTypes);
}

- (NSArray<NSDictionary *> *)revenant_locations
{
    NSMutableArray *locations = [NSMutableArray array];
    NSString *home = NSHomeDirectory();
    NSMutableArray *candidates = [NSMutableArray array];
    [candidates addObject:@{@"title": @"On My Device", @"path": home}];
    NSFileManager *manager = [NSFileManager defaultManager];
    for (NSString *extra in @[@"/var/mobile/Media", @"/var/mobile/Documents", @"/var/mobile", @"/"]) {
        if ([extra isEqualToString:home])
            continue;
        BOOL directory = NO;
        if ([manager fileExistsAtPath:extra isDirectory:&directory] && directory && [manager isReadableFileAtPath:extra])
            [candidates addObject:@{@"title": [extra isEqualToString:@"/"] ? @"Root" : extra.lastPathComponent, @"path": extra}];
    }
    for (NSDictionary *candidate in candidates)
        if ([manager isReadableFileAtPath:candidate[@"path"]])
            [locations addObject:candidate];
    return locations;
}

- (NSString *)revenant_startFolder
{
    NSString *path = _directoryURL.isFileURL ? _directoryURL.path : nil;
    BOOL directory = NO;
    if (path && [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&directory] && directory)
        return path;
    return nil;
}

- (UIBarButtonItem *)revenant_cancelItem
{
    return [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(revenant_cancel)];
}

- (void)revenant_finish:(NSArray<NSURL *> *)urls
{
    id<UIDocumentPickerDelegate> delegate = _delegate;
    void (^report)(void) = ^{
        if ([delegate respondsToSelector:@selector(documentPicker:didPickDocumentsAtURLs:)])
            [delegate documentPicker:self didPickDocumentsAtURLs:urls];
        else if ([delegate respondsToSelector:@selector(documentPicker:didPickDocumentAtURL:)] && urls.count)
            [delegate documentPicker:self didPickDocumentAtURL:urls.firstObject];
    };
    if (self.presentingViewController)
        [self.presentingViewController dismissViewControllerAnimated:YES completion:report];
    else
        report();
}

- (void)revenant_pickPaths:(NSArray<NSString *> *)paths
{
    NSMutableArray *urls = [NSMutableArray array];
    NSFileManager *manager = [NSFileManager defaultManager];
    for (NSString *path in paths) {
        if (_documentPickerMode == UIDocumentPickerModeImport) {
            NSString *folder = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
            [manager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
            NSString *copy = [folder stringByAppendingPathComponent:path.lastPathComponent];
            if ([manager copyItemAtPath:path toPath:copy error:NULL])
                [urls addObject:[NSURL fileURLWithPath:copy]];
        } else {
            [urls addObject:[NSURL fileURLWithPath:path]];
        }
    }
    [self revenant_finish:urls];
}

- (void)revenant_chooseFolder:(NSString *)folder
{
    NSMutableArray *urls = [NSMutableArray array];
    NSFileManager *manager = [NSFileManager defaultManager];
    for (NSURL *source in _URLs) {
        NSString *name = source.lastPathComponent;
        NSString *target = [folder stringByAppendingPathComponent:name];
        NSUInteger n = 2;
        while ([manager fileExistsAtPath:target])
            target = [folder stringByAppendingPathComponent:revenant_picker_unique_name(name, n++)];
        BOOL ok = _documentPickerMode == UIDocumentPickerModeMoveToService ? [manager moveItemAtPath:source.path toPath:target error:NULL] : [manager copyItemAtPath:source.path toPath:target error:NULL];
        if (ok)
            [urls addObject:[NSURL fileURLWithPath:target]];
    }
    [self revenant_finish:urls];
}

- (void)revenant_cancel
{
    id<UIDocumentPickerDelegate> delegate = _delegate;
    void (^report)(void) = ^{
        if ([delegate respondsToSelector:@selector(documentPickerWasCancelled:)])
            [delegate documentPickerWasCancelled:self];
    };
    if (self.presentingViewController)
        [self.presentingViewController dismissViewControllerAnimated:YES completion:report];
    else
        report();
}

@end
