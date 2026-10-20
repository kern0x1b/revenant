#import <UIKit/UIKit.h>

static NSString *const kRevenantPickerServiceType = @"_universal._sub._ipp._tcp.";
static NSString *const kRevenantPickerDomain = @"local.";
static const NSTimeInterval kRevenantPickerResolveTimeout = 10;

static NSURL *revenant_printerURL(NSNetService *service)
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

@interface RevenantPrinterPickerRow : NSObject
@property (nonatomic, strong) NSNetService *service;
@property (nonatomic, strong) UIPrinter *printer;
@end

@implementation RevenantPrinterPickerRow
@synthesize service = _service;
@synthesize printer = _printer;
@end

@interface UIPrinterPickerController (RevenantList)
- (void)revenant_selectPrinter:(UIPrinter *)printer;
- (void)revenant_cancelWithError:(NSError *)error;
- (void)revenant_popoverDidDismiss;
- (BOOL)revenant_shouldShowPrinter:(UIPrinter *)printer;
@end

@interface RevenantPrinterPickerList : UIViewController <UITableViewDataSource, UITableViewDelegate,
    NSNetServiceBrowserDelegate, NSNetServiceDelegate, UIPopoverControllerDelegate>
@property (nonatomic, weak) UIPrinterPickerController *picker;
- (void)startBrowsing;
- (void)stopBrowsing;
@end

@implementation RevenantPrinterPickerList {
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
    [self.picker revenant_cancelWithError:nil];
}

- (void)startBrowsing
{
    if (_browser)
        return;
    _browser = [[NSNetServiceBrowser alloc] init];
    _browser.delegate = self;
    [_browser searchForServicesOfType:kRevenantPickerServiceType inDomain:kRevenantPickerDomain];
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

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didFindService:(NSNetService *)service moreComing:(BOOL)more
{
    [_resolving addObject:service];
    service.delegate = self;
    [service resolveWithTimeout:kRevenantPickerResolveTimeout];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didRemoveService:(NSNetService *)service moreComing:(BOOL)more
{
    [_resolving removeObject:service];
    for (RevenantPrinterPickerRow *row in [_rows copy]) {
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
    [self.picker revenant_cancelWithError:error];
}

- (void)netServiceDidResolveAddress:(NSNetService *)service
{
    [_resolving removeObject:service];
    NSURL *url = revenant_printerURL(service);
    if (!url)
        return;
    UIPrinter *printer = [UIPrinter printerWithURL:url];
    if (![self.picker revenant_shouldShowPrinter:printer])
        return;
    RevenantPrinterPickerRow *row = [[RevenantPrinterPickerRow alloc] init];
    row.service = service;
    row.printer = printer;
    [_rows addObject:row];
    [self reload];
}

- (void)netService:(NSNetService *)service didNotResolve:(NSDictionary *)errorDict
{
    [_resolving removeObject:service];
}

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
    static NSString *const kCell = @"RevenantPrinterPickerCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCell];
    if (!cell)
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kCell];
    cell.textLabel.text = [[[_rows objectAtIndex:indexPath.row] service] name];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self.picker revenant_selectPrinter:[[_rows objectAtIndex:indexPath.row] printer]];
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popover
{
    [self.picker revenant_popoverDidDismiss];
}

@end

@implementation UIPrinterPickerController {
    UIPrinter *_selectedPrinter;
    UIPrinterPickerCompletionHandler _completion;
    RevenantPrinterPickerList *_list;
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
    UIViewController *parent = [self revenant_parentViewController];
    if (!parent)
        return NO;
    [self revenant_beginWithCompletion:completion animated:animated];
    [self revenant_willPresent];
    [parent presentViewController:_navigation animated:animated completion:^{
        [self revenant_didPresent];
    }];
    if (!_navigation.presentingViewController) {
        [self revenant_abandon];
        return NO;
    }
    [_list startBrowsing];
    return YES;
}

- (BOOL)presentFromRect:(CGRect)rect inView:(UIView *)view animated:(BOOL)animated completionHandler:(UIPrinterPickerCompletionHandler)completion
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        return [self presentAnimated:animated completionHandler:completion];
    if (_up || !view)
        return NO;
    [self revenant_beginWithCompletion:completion animated:animated];
    _popover = [[UIPopoverController alloc] initWithContentViewController:_navigation];
    _popover.delegate = _list;
    [self revenant_willPresent];
    [_popover presentPopoverFromRect:rect inView:view permittedArrowDirections:UIPopoverArrowDirectionAny animated:animated];
    [self revenant_didPresent];
    [_list startBrowsing];
    return YES;
}

- (BOOL)presentFromBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated completionHandler:(UIPrinterPickerCompletionHandler)completion
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        return [self presentAnimated:animated completionHandler:completion];
    if (_up || !item)
        return NO;
    [self revenant_beginWithCompletion:completion animated:animated];
    _popover = [[UIPopoverController alloc] initWithContentViewController:_navigation];
    _popover.delegate = _list;
    [self revenant_willPresent];
    [_popover presentPopoverFromBarButtonItem:item permittedArrowDirections:UIPopoverArrowDirectionAny animated:animated];
    [self revenant_didPresent];
    [_list startBrowsing];
    return YES;
}

- (void)dismissAnimated:(BOOL)animated
{
    if (!_up)
        return;
    [self revenant_finish:NO error:nil animated:animated];
}

#pragma mark - the picker's state, shared with its list

- (void)revenant_beginWithCompletion:(UIPrinterPickerCompletionHandler)completion animated:(BOOL)animated
{
    _up = YES;
    _animated = animated;
    _completion = [completion copy];
    _list = [[RevenantPrinterPickerList alloc] init];
    _list.picker = self;
    _navigation = [[UINavigationController alloc] initWithRootViewController:_list];
}

- (void)revenant_abandon
{
    [_list stopBrowsing];
    _up = NO;
    _completion = nil;
    _list = nil;
    _navigation = nil;
}

- (UIViewController *)revenant_parentViewController
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

- (BOOL)revenant_shouldShowPrinter:(UIPrinter *)printer
{
    if (![self.delegate respondsToSelector:@selector(printerPickerController:shouldShowPrinter:)])
        return YES;
    return [self.delegate printerPickerController:self shouldShowPrinter:printer];
}

- (void)revenant_willPresent
{
    if ([self.delegate respondsToSelector:@selector(printerPickerControllerWillPresent:)])
        [self.delegate printerPickerControllerWillPresent:self];
}

- (void)revenant_didPresent
{
    if ([self.delegate respondsToSelector:@selector(printerPickerControllerDidPresent:)])
        [self.delegate printerPickerControllerDidPresent:self];
}

- (void)revenant_selectPrinter:(UIPrinter *)printer
{
    _selectedPrinter = printer;
    if ([self.delegate respondsToSelector:@selector(printerPickerControllerDidSelectPrinter:)])
        [self.delegate printerPickerControllerDidSelectPrinter:self];
    [self revenant_finish:YES error:nil animated:_animated];
}

- (void)revenant_cancelWithError:(NSError *)error
{
    [self revenant_finish:NO error:error animated:_animated];
}

- (void)revenant_popoverDidDismiss
{
    [self revenant_finish:NO error:nil animated:NO];
}

- (void)revenant_finish:(BOOL)selected error:(NSError *)error animated:(BOOL)animated
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
