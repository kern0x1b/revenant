#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "CharonCustomTransition.h"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wobjc-property-implementation"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@interface CharonDocumentMenuOption : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) void (^handler)(void);
@property (nonatomic, assign) UIDocumentMenuOrder order;
@end

@implementation CharonDocumentMenuOption
@synthesize title, handler, order;
@end

@implementation UIDocumentMenuViewController {
    NSArray *_types;
    NSURL *_url;
    UIDocumentPickerMode _mode;
    NSMutableArray<CharonDocumentMenuOption *> *_options;
    __weak id<UIDocumentMenuDelegate> _delegate;
    UIAlertController *_alert;
    UIPopoverPresentationController *_popover;
}

- (instancetype)initWithDocumentTypes:(NSArray *)allowedUTIs inMode:(UIDocumentPickerMode)mode
{
    if (mode != UIDocumentPickerModeImport && mode != UIDocumentPickerModeOpen)
        [NSException raise:NSInternalInconsistencyException format:@"-[UIDocumentMenuViewController initWithDocumentTypes:inMode:] can only be called with mode Import or Open"];
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _types = [allowedUTIs copy];
        _mode = mode;
        _options = [NSMutableArray array];
        self.modalPresentationStyle = (UIModalPresentationStyle)100;
    }
    return self;
}

- (instancetype)initWithURL:(NSURL *)url inMode:(UIDocumentPickerMode)mode
{
    if (mode != UIDocumentPickerModeExportToService && mode != UIDocumentPickerModeMoveToService)
        [NSException raise:NSInternalInconsistencyException format:@"-[UIDocumentMenuViewController initWithURL:inMode:] can only be called with mode Export or Move"];
    if (!url || ![[NSFileManager defaultManager] fileExistsAtPath:url.path])
        [NSException raise:NSInternalInconsistencyException format:@"-[UIDocumentMenuViewController initWithURL:inMode:] must be called with a URL pointing to an existing file"];
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _url = [url copy];
        _mode = mode;
        _options = [NSMutableArray array];
        self.modalPresentationStyle = (UIModalPresentationStyle)100;
    }
    return self;
}

- (instancetype)initWithNibName:(NSString *)nibName bundle:(NSBundle *)bundle
{
    [NSException raise:NSInvalidArgumentException format:@"You cannot initialize a UIDocumentMenuViewController except by the initWithDocumentTypes:inMode: and initWithURL:inMode: initializers."];
    return nil;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    [NSException raise:NSInvalidArgumentException format:@"You cannot initialize a UIDocumentMenuViewController except by the initWithDocumentTypes:inMode: and initWithURL:inMode: initializers."];
    return nil;
}

- (id<UIDocumentMenuDelegate>)delegate
{
    return _delegate;
}

- (void)setDelegate:(id<UIDocumentMenuDelegate>)delegate
{
    _delegate = delegate;
}

- (void)addOptionWithTitle:(NSString *)title image:(UIImage *)image order:(UIDocumentMenuOrder)order handler:(void (^)(void))handler
{
    CharonDocumentMenuOption *option = [[CharonDocumentMenuOption alloc] init];
    option.title = title;
    option.order = order;
    option.handler = handler;
    [_options addObject:option];
}

- (UIPopoverPresentationController *)popoverPresentationController
{
    if (!_popover) {
        _popover = [[UIPopoverPresentationController alloc] initWithPresentedViewController:self presentingViewController:nil];
        charon_set_presentation_controller(self, _popover);
    }
    return _popover;
}

- (UIAlertController *)charon_alertForPresenter:(UIViewController *)presenter
{
    __weak UIDocumentMenuViewController *weak = self;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    void (^addOption)(CharonDocumentMenuOption *) = ^(CharonDocumentMenuOption *option) {
        [alert addAction:[UIAlertAction actionWithTitle:option.title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            if (option.handler)
                option.handler();
        }]];
    };
    for (CharonDocumentMenuOption *option in _options)
        if (option.order == UIDocumentMenuOrderFirst)
            addOption(option);
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Browse", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UIDocumentMenuViewController *strong = weak;
        if (!strong)
            return;
        UIDocumentPickerViewController *picker = strong->_url ? [[UIDocumentPickerViewController alloc] initWithURL:strong->_url inMode:strong->_mode]
                                                              : [[UIDocumentPickerViewController alloc] initWithDocumentTypes:strong->_types inMode:strong->_mode];
        [strong->_delegate documentMenu:strong didPickDocumentPicker:picker];
    }]];
    for (CharonDocumentMenuOption *option in _options)
        if (option.order == UIDocumentMenuOrderLast)
            addOption(option);
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        UIDocumentMenuViewController *strong = weak;
        if ([strong->_delegate respondsToSelector:@selector(documentMenuWasCancelled:)])
            [strong->_delegate documentMenuWasCancelled:strong];
    }]];
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        UIPopoverPresentationController *source = _popover;
        UIPopoverPresentationController *target = alert.popoverPresentationController;
        if (source.barButtonItem) {
            target.barButtonItem = source.barButtonItem;
        } else {
            target.sourceView = source.sourceView ?: presenter.view;
            target.sourceRect = source.sourceView && !CGRectIsNull(source.sourceRect) ? source.sourceRect : (source.sourceView ? source.sourceView.bounds : CGRectMake(CGRectGetMidX(presenter.view.bounds), CGRectGetMidY(presenter.view.bounds), 1, 1));
        }
    }
    return alert;
}

@end
