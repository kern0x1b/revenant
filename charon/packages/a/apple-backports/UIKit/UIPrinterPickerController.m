#import <UIKit/UIKit.h>

// The printer picker. AirPrint printers advertise over Bonjour as _ipp._tcp with the _universal subtype, so the picker
// browses that subtype with NSNetServiceBrowser (public in Foundation since iOS 2), resolves each service it finds, and
// lists the printers in the release's own UITableView inside a UINavigationController. Selecting one completes with a
// UIPrinter whose URL is built from the resolved service: ipp://<host>:<port>/<rp>, rp being the TXT record's resource
// path. The host's picker selects a placeholder at once instead; the port does not (facts/UIKit/UIPrinterPickerController.md).

static NSString *const kCharonPickerServiceType = @"_universal._sub._ipp._tcp.";
static NSString *const kCharonPickerDomain = @"local.";
static const NSTimeInterval kCharonPickerResolveTimeout = 10;

// The URL a resolved service is reached at, or nil when it has no host yet.
static NSURL *charon_printerURL(NSNetService *service)
{
    NSString *host = [service hostName];
    if (![host length])
        return nil;
    if ([host hasSuffix:@"."])
        host = [host substringToIndex:[host length] - 1];

    NSString *path = @"";
    NSData *txt = [service TXTRecordData];
    NSData *rp = txt ? [[NSNetService dictionaryFromTXTRecordData:txt] objectForKey:@"rp"] : nil;
    if (rp)
        path = [[NSString alloc] initWithData:rp encoding:NSUTF8StringEncoding] ?: @"";
    while ([path hasPrefix:@"/"])
        path = [path substringFromIndex:1];
    NSString *escaped = [path stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] ?: @"";
    return [NSURL URLWithString:[NSString stringWithFormat:@"ipp://%@:%ld/%@", host, (long)[service port], escaped]];
}

// One row of the list: the service it was found as, and the printer it completes with.
@interface CharonPrinterPickerRow : NSObject
@property (nonatomic, strong) NSNetService *service;
@property (nonatomic, strong) UIPrinter *printer;
@end

@implementation CharonPrinterPickerRow
@synthesize service = _service;
@synthesize printer = _printer;
@end

// What the list calls back on its picker; the picker implements them below.
@interface UIPrinterPickerController (CharonList)
- (void)charon_selectPrinter:(UIPrinter *)printer;
- (void)charon_cancelWithError:(NSError *)error;
- (void)charon_popoverDidDismiss;
- (BOOL)charon_shouldShowPrinter:(UIPrinter *)printer;
@end

// The list: the table, the browser and the resolutions, shown inside the navigation controller.
@interface CharonPrinterPickerList : UIViewController <UITableViewDataSource, UITableViewDelegate,
    NSNetServiceBrowserDelegate, NSNetServiceDelegate, UIPopoverControllerDelegate>
@property (nonatomic, weak) UIPrinterPickerController *picker;
- (void)startBrowsing;
- (void)stopBrowsing;
@end

@implementation CharonPrinterPickerList {
    __weak UIPrinterPickerController *_picker;
    UITableView *_table;
    NSNetServiceBrowser *_browser;
    NSMutableArray *_resolving;
    NSMutableArray *_rows;
}

@synthesize picker = _picker;

- (instancetype)init
{
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _resolving = [NSMutableArray array];
        _rows = [NSMutableArray array];
    }
    return self;
}

- (void)loadView
{
    _table = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 0, 0) style:UITableViewStylePlain];
    _table.dataSource = self;
    _table.delegate = self;
    self.view = _table;
    self.navigationItem.title = @"Printers";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                          target:self
                                                                                          action:@selector(cancel:)];
}

- (void)cancel:(id)sender
{
    [self.picker charon_cancelWithError:nil];
}

- (void)startBrowsing
{
    if (_browser)
        return;
    _browser = [[NSNetServiceBrowser alloc] init];
    _browser.delegate = self;
    [_browser searchForServicesOfType:kCharonPickerServiceType inDomain:kCharonPickerDomain];
}

- (void)stopBrowsing
{
    [_browser stop];
    _browser.delegate = nil;
    _browser = nil;
    for (NSNetService *service in _resolving) {
        service.delegate = nil;
        [service stop];
    }
    [_resolving removeAllObjects];
}

- (void)reload
{
    [_table reloadData];
}

// Browser: each service found is resolved before it can be listed.
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didFindService:(NSNetService *)service moreComing:(BOOL)more
{
    [_resolving addObject:service];
    service.delegate = self;
    [service resolveWithTimeout:kCharonPickerResolveTimeout];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didRemoveService:(NSNetService *)service moreComing:(BOOL)more
{
    [_resolving removeObject:service];
    for (CharonPrinterPickerRow *row in [_rows copy]) {
        if (row.service == service)
            [_rows removeObject:row];
    }
    [self reload];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didNotSearch:(NSDictionary *)errorDict
{
    NSError *error = [NSError errorWithDomain:NSNetServicesErrorDomain
                                         code:[[errorDict objectForKey:NSNetServicesErrorCode] integerValue]
                                     userInfo:nil];
    [self.picker charon_cancelWithError:error];
}

// Resolution: a resolved service with a URL is listed, unless the delegate filters it out.
- (void)netServiceDidResolveAddress:(NSNetService *)service
{
    [_resolving removeObject:service];
    NSURL *url = charon_printerURL(service);
    if (!url)
        return;
    UIPrinter *printer = [UIPrinter printerWithURL:url];
    if (![self.picker charon_shouldShowPrinter:printer])
        return;
    CharonPrinterPickerRow *row = [[CharonPrinterPickerRow alloc] init];
    row.service = service;
    row.printer = printer;
    [_rows addObject:row];
    [self reload];
}

- (void)netService:(NSNetService *)service didNotResolve:(NSDictionary *)errorDict
{
    [_resolving removeObject:service];
}

// Table: no rows until a service resolves, so a picker with no printer on the network lists nothing.
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_rows count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *const kCell = @"CharonPrinterPickerCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCell];
    if (!cell)
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kCell];
    cell.textLabel.text = [[[_rows objectAtIndex:indexPath.row] service] name];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self.picker charon_selectPrinter:[[_rows objectAtIndex:indexPath.row] printer]];
}

// A popover dismissed by a tap outside it is a cancel.
- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popover
{
    [self.picker charon_popoverDidDismiss];
}

@end

@implementation UIPrinterPickerController {
    UIPrinter *_selectedPrinter;
    UIPrinterPickerCompletionHandler _completion;
    CharonPrinterPickerList *_list;
    UINavigationController *_navigation;
    UIPopoverController *_popover;
    BOOL _up;
    BOOL _animated;
}

+ (UIPrinterPickerController *)printerPickerControllerWithInitiallySelectedPrinter:(UIPrinter *)printer
{
    UIPrinterPickerController *controller = [[UIPrinterPickerController alloc] init];
    controller->_selectedPrinter = printer;
    return controller;
}

- (UIPrinter *)selectedPrinter
{
    return _selectedPrinter;
}

- (BOOL)presentAnimated:(BOOL)animated completionHandler:(UIPrinterPickerCompletionHandler)completion
{
    if (_up)
        return NO;
    UIViewController *parent = [self charon_parentViewController];
    if (!parent)
        return NO;
    [self charon_beginWithCompletion:completion animated:animated];
    [self charon_willPresent];
    [parent presentViewController:_navigation animated:animated completion:^{
        [self charon_didPresent];
    }];
    if (!_navigation.presentingViewController) {
        [self charon_abandon];
        return NO;
    }
    [_list startBrowsing];
    return YES;
}

// On the phone there is no popover, so the picker is presented as presentAnimated: presents it.
- (BOOL)presentFromRect:(CGRect)rect inView:(UIView *)view animated:(BOOL)animated completionHandler:(UIPrinterPickerCompletionHandler)completion
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        return [self presentAnimated:animated completionHandler:completion];
    if (_up || !view)
        return NO;
    [self charon_beginWithCompletion:completion animated:animated];
    _popover = [[UIPopoverController alloc] initWithContentViewController:_navigation];
    _popover.delegate = _list;
    [self charon_willPresent];
    [_popover presentPopoverFromRect:rect inView:view permittedArrowDirections:UIPopoverArrowDirectionAny animated:animated];
    [self charon_didPresent];
    [_list startBrowsing];
    return YES;
}

- (BOOL)presentFromBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated completionHandler:(UIPrinterPickerCompletionHandler)completion
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        return [self presentAnimated:animated completionHandler:completion];
    if (_up || !item)
        return NO;
    [self charon_beginWithCompletion:completion animated:animated];
    _popover = [[UIPopoverController alloc] initWithContentViewController:_navigation];
    _popover.delegate = _list;
    [self charon_willPresent];
    [_popover presentPopoverFromBarButtonItem:item permittedArrowDirections:UIPopoverArrowDirectionAny animated:animated];
    [self charon_didPresent];
    [_list startBrowsing];
    return YES;
}

// A dismissal made by the caller is not a selection: the completion says userDidSelect NO.
- (void)dismissAnimated:(BOOL)animated
{
    if (!_up)
        return;
    [self charon_finish:NO error:nil animated:animated];
}

#pragma mark - the picker's state, shared with its list

- (void)charon_beginWithCompletion:(UIPrinterPickerCompletionHandler)completion animated:(BOOL)animated
{
    _up = YES;
    _animated = animated;
    _completion = [completion copy];
    _list = [[CharonPrinterPickerList alloc] init];
    _list.picker = self;
    _navigation = [[UINavigationController alloc] initWithRootViewController:_list];
}

// Presentation that failed: nothing was shown, so nothing is reported.
- (void)charon_abandon
{
    [_list stopBrowsing];
    _up = NO;
    _completion = nil;
    _list = nil;
    _navigation = nil;
}

- (UIViewController *)charon_parentViewController
{
    UIViewController *parent = nil;
    if ([self.delegate respondsToSelector:@selector(printerPickerControllerParentViewController:)])
        parent = [self.delegate printerPickerControllerParentViewController:self];
    if (!parent)
        parent = [[[UIApplication sharedApplication] keyWindow] rootViewController];
    while (parent.presentedViewController)
        parent = parent.presentedViewController;
    return parent;
}

- (BOOL)charon_shouldShowPrinter:(UIPrinter *)printer
{
    if (![self.delegate respondsToSelector:@selector(printerPickerController:shouldShowPrinter:)])
        return YES;
    return [self.delegate printerPickerController:self shouldShowPrinter:printer];
}

- (void)charon_willPresent
{
    if ([self.delegate respondsToSelector:@selector(printerPickerControllerWillPresent:)])
        [self.delegate printerPickerControllerWillPresent:self];
}

- (void)charon_didPresent
{
    if ([self.delegate respondsToSelector:@selector(printerPickerControllerDidPresent:)])
        [self.delegate printerPickerControllerDidPresent:self];
}

- (void)charon_selectPrinter:(UIPrinter *)printer
{
    _selectedPrinter = printer;
    if ([self.delegate respondsToSelector:@selector(printerPickerControllerDidSelectPrinter:)])
        [self.delegate printerPickerControllerDidSelectPrinter:self];
    [self charon_finish:YES error:nil animated:_animated];
}

// A cancel, or a browse that failed: the completion gets userDidSelect NO and the error (nil for a cancel).
- (void)charon_cancelWithError:(NSError *)error
{
    [self charon_finish:NO error:error animated:_animated];
}

- (void)charon_popoverDidDismiss
{
    [self charon_finish:NO error:nil animated:NO];
}

// The one way the picker ends: the picker is taken down, then the completion runs once.
- (void)charon_finish:(BOOL)selected error:(NSError *)error animated:(BOOL)animated
{
    if (!_up)
        return;
    [_list stopBrowsing];
    if ([self.delegate respondsToSelector:@selector(printerPickerControllerWillDismiss:)])
        [self.delegate printerPickerControllerWillDismiss:self];

    UIPrinterPickerCompletionHandler completion = _completion;
    UINavigationController *navigation = _navigation;
    UIPopoverController *popover = _popover;
    _up = NO;
    _completion = nil;
    _list = nil;
    _navigation = nil;
    _popover = nil;

    void (^didDismiss)(void) = ^{
        if ([self.delegate respondsToSelector:@selector(printerPickerControllerDidDismiss:)])
            [self.delegate printerPickerControllerDidDismiss:self];
        if (completion)
            completion(self, selected, error);
    };
    if (popover) {
        if (popover.popoverVisible)
            [popover dismissPopoverAnimated:animated];
        didDismiss();
    } else {
        [navigation dismissViewControllerAnimated:animated completion:didDismiss];
    }
}

@end
