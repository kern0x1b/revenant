#import "RevenantMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface RevenantContextMenuAnimator : NSObject <UIContextMenuInteractionAnimating>
- (void)finish;
@end

@implementation RevenantContextMenuAnimator {
@private
    NSMutableArray *_completions;
    BOOL _finished;
}

@dynamic previewViewController;

- (UIViewController *)previewViewController
{
    return nil;
}

- (void)addAnimations:(void (^)(void))animations
{
    if (animations)
        animations();
}

- (void)addCompletion:(void (^)(void))completion
{
    if (!completion)
        return;
    if (_finished) {
        completion();
        return;
    }
    if (!_completions)
        _completions = [NSMutableArray array];
    [_completions addObject:[completion copy]];
}

- (void)finish
{
    _finished = YES;
    NSArray *completions = _completions;
    _completions = nil;
    for (void (^completion)(void) in completions)
        completion();
}

@end

@class RevenantContextMenuSheet;

@interface UIContextMenuInteraction (RevenantSheet)
- (void)revenant_pressed:(UILongPressGestureRecognizer *)recognizer;
- (void)revenant_sheetPresented;
- (void)revenant_sheetWillDismissWithIndex:(NSInteger)index;
- (void)revenant_sheetDidDismissWithIndex:(NSInteger)index;
@end

static const char revenant_sheet_delegate_key;

@interface RevenantContextMenuSheet : NSObject <UIActionSheetDelegate>
@property (nonatomic, weak) UIContextMenuInteraction *interaction;
@end

@implementation RevenantContextMenuSheet {
@private
    __weak UIContextMenuInteraction *_interaction;
}

@dynamic interaction;

- (UIContextMenuInteraction *)interaction
{
    return _interaction;
}

- (void)setInteraction:(UIContextMenuInteraction *)interaction
{
    _interaction = interaction;
}

- (void)didPresentActionSheet:(UIActionSheet *)actionSheet
{
    [_interaction revenant_sheetPresented];
}

- (void)actionSheet:(UIActionSheet *)actionSheet willDismissWithButtonIndex:(NSInteger)buttonIndex
{
    [_interaction revenant_sheetWillDismissWithIndex:buttonIndex];
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    [_interaction revenant_sheetDidDismissWithIndex:buttonIndex];
}

@end

static BOOL revenant_leaf(UIMenuElement *element)
{
    return [element isKindOfClass:[UIAction class]] || [element isKindOfClass:[UICommand class]];
}

static UIMenuElementAttributes revenant_attributes(UIMenuElement *element)
{
    return [element isKindOfClass:[UIAction class]] ? ((UIAction *)element).attributes : ((UICommand *)element).attributes;
}

static UIMenuElementState revenant_state(UIMenuElement *element)
{
    return [element isKindOfClass:[UIAction class]] ? ((UIAction *)element).state : ((UICommand *)element).state;
}

static void revenant_collect_deferred(NSArray *elements, NSMutableArray *found)
{
    for (UIMenuElement *element in elements) {
        if ([element isKindOfClass:[UIDeferredMenuElement class]])
            [found addObject:element];
        else if ([element isKindOfClass:[UIMenu class]] && (((UIMenu *)element).options & UIMenuOptionsDisplayInline))
            revenant_collect_deferred(((UIMenu *)element).children, found);
    }
}

static BOOL revenant_menu_has_content(UIMenu *menu, NSDictionary *resolved)
{
    for (UIMenuElement *child in menu.children) {
        if (revenant_leaf(child)) {
            if (!(revenant_attributes(child) & (UIMenuElementAttributesDisabled | UIMenuElementAttributesHidden)))
                return YES;
        } else if ([child isKindOfClass:[UIMenu class]]) {
            if (revenant_menu_has_content((UIMenu *)child, resolved))
                return YES;
        } else if ([child isKindOfClass:[UIDeferredMenuElement class]]) {
            if ([resolved[child] count])
                return YES;
        }
    }
    return NO;
}

static void revenant_flatten(NSArray *elements, NSDictionary *resolved, NSMutableArray *out)
{
    for (UIMenuElement *element in elements) {
        if (revenant_leaf(element)) {
            if (!(revenant_attributes(element) & (UIMenuElementAttributesDisabled | UIMenuElementAttributesHidden)))
                [out addObject:element];
        } else if ([element isKindOfClass:[UIMenu class]]) {
            UIMenu *menu = (UIMenu *)element;
            if (menu.options & UIMenuOptionsDisplayInline)
                revenant_flatten(menu.children, resolved, out);
            else if (revenant_menu_has_content(menu, resolved))
                [out addObject:menu];
        } else if ([element isKindOfClass:[UIDeferredMenuElement class]]) {
            NSArray *items = resolved[element];
            NSMutableArray *plain = [NSMutableArray array];
            for (UIMenuElement *item in items) {
                if (![item isKindOfClass:[UIDeferredMenuElement class]])
                    [plain addObject:item];
            }
            revenant_flatten(plain, resolved, out);
        }
    }
}

static NSString *revenant_button_title(UIMenuElement *element)
{
    NSString *title = element.title;
    if (!title.length && [element isKindOfClass:[UIAction class]])
        title = ((UIAction *)element).discoverabilityTitle;
    if (!title.length)
        return nil;
    if ([element isKindOfClass:[UIMenu class]])
        return [title stringByAppendingString:@" ›"];
    UIMenuElementState state = revenant_state(element);
    if (state == UIMenuElementStateOn)
        return [@"✓ " stringByAppendingString:title];
    if (state == UIMenuElementStateMixed)
        return [@"– " stringByAppendingString:title];
    return title;
}

static BOOL revenant_destructive(UIMenuElement *element)
{
    if ([element isKindOfClass:[UIMenu class]])
        return (((UIMenu *)element).options & UIMenuOptionsDestructive) != 0;
    return (revenant_attributes(element) & UIMenuElementAttributesDestructive) != 0;
}

@implementation UIContextMenuInteraction {
@private
    __weak id<UIContextMenuInteractionDelegate> _delegate;
    __weak UIView *_view;
    UILongPressGestureRecognizer *_recognizer;
    UIContextMenuConfiguration *_configuration;
    UIMenu *_visibleMenu;
    UIMenu *_pendingSubmenu;
    UIMenuElement *_chosen;
    UIActionSheet *_sheet;
    RevenantContextMenuSheet *_sheetDelegate;
    NSArray *_entries;
    RevenantContextMenuAnimator *_displayAnimator;
    RevenantContextMenuAnimator *_endAnimator;
    CGPoint _location;
    BOOL _locationKnown;
    BOOL _busy;
    BOOL _replacing;
    BOOL _first;
}

@dynamic menuAppearance;

- (instancetype)initWithDelegate:(id<UIContextMenuInteractionDelegate>)delegate
{
    if ((self = [super init]))
        _delegate = delegate;
    return self;
}

- (id<UIContextMenuInteractionDelegate>)delegate
{
    return _delegate;
}

- (UIView *)view
{
    return _view;
}

- (void)willMoveToView:(UIView *)view
{
}

- (void)didMoveToView:(UIView *)view
{
    if (_view == view)
        return;
    if (_sheet)
        [self dismissMenu];
    if (_recognizer) {
        [_view removeGestureRecognizer:_recognizer];
        _recognizer = nil;
    }
    _view = view;
    if (view) {
        _recognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(revenant_pressed:)];
        [view addGestureRecognizer:_recognizer];
    }
}

- (CGPoint)locationInView:(UIView *)view
{
    UIView *held = _view;
    if (!_locationKnown || !held)
        return CGPointMake(CGFLOAT_MAX, CGFLOAT_MAX);
    return [held convertPoint:_location toView:view];
}

- (void)dismissMenu
{
    if (_sheet)
        [_sheet dismissWithClickedButtonIndex:_sheet.cancelButtonIndex animated:YES];
}

- (void)revenant_pressed:(UILongPressGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateBegan)
        [self revenant_beginAtLocation:[recognizer locationInView:_view]];
}

- (void)revenant_beginAtLocation:(CGPoint)location
{
    id<UIContextMenuInteractionDelegate> delegate = _delegate;
    if (!_view.window || _busy || _sheet || !delegate)
        return;
    UIContextMenuConfiguration *configuration = [delegate contextMenuInteraction:self configurationForMenuAtLocation:location];
    if (!configuration)
        return;
    UIContextMenuActionProvider provider = [configuration revenant_actionProvider];
    UIMenu *menu = provider ? provider(@[]) : nil;
    if (![menu isKindOfClass:[UIMenu class]])
        return;
    revenant_menus_say_once(@"sheet", [NSString stringWithFormat:@"UIContextMenuInteraction: iOS %@ draws no menu preview, highlight or morph, so the menu is shown as an action sheet; the preview provider and the preview delegate methods are never called",
                                                               [UIDevice currentDevice].systemVersion]);
    _busy = YES;
    _configuration = configuration;
    _location = location;
    _locationKnown = YES;
    _first = YES;
    [self revenant_show:menu];
}

- (void)revenant_show:(UIMenu *)menu
{
    NSMutableArray *deferred = [NSMutableArray array];
    revenant_collect_deferred(menu.children, deferred);
    if (!deferred.count) {
        [self revenant_show:menu resolved:@{}];
        return;
    }
    NSMutableDictionary *resolved = [NSMutableDictionary dictionary];
    __block NSUInteger pending = deferred.count;
    __block BOOL shown = NO;
    void (^show)(void) = ^{
        if (shown)
            return;
        shown = YES;
        [self revenant_show:menu resolved:resolved];
    };
    for (UIDeferredMenuElement *element in deferred) {
        [element revenant_fulfillWithCompletion:^(NSArray<UIMenuElement *> *elements) {
            if (shown)
                return;
            resolved[element] = elements;
            if (--pending == 0)
                show();
        }];
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), show);
}

- (void)revenant_show:(UIMenu *)menu resolved:(NSDictionary *)resolved
{
    UIView *view = _view;
    NSMutableArray *elements = [NSMutableArray array];
    revenant_flatten(menu.children, resolved, elements);
    NSMutableArray *entries = [NSMutableArray array];
    NSMutableArray *titles = [NSMutableArray array];
    UIMenuElement *destructive = nil;
    NSString *destructiveTitle = nil;
    for (UIMenuElement *element in elements) {
        NSString *title = revenant_button_title(element);
        if (!title)
            continue;
        if (!destructive && revenant_destructive(element)) {
            destructive = element;
            destructiveTitle = title;
            continue;
        }
        [entries addObject:element];
        [titles addObject:title];
    }
    if (destructive)
        [entries insertObject:destructive atIndex:0];
    if (!view.window || !entries.count) {
        [self revenant_reset];
        return;
    }
    _visibleMenu = menu;
    _entries = entries;
    _sheetDelegate = [[RevenantContextMenuSheet alloc] init];
    _sheetDelegate.interaction = self;
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:menu.title.length ? menu.title : nil delegate:_sheetDelegate cancelButtonTitle:nil
                                         destructiveButtonTitle:destructiveTitle otherButtonTitles:nil];
    objc_setAssociatedObject(sheet, &revenant_sheet_delegate_key, _sheetDelegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    for (NSString *title in titles)
        [sheet addButtonWithTitle:title];
    NSString *cancel = [[NSBundle bundleForClass:[UIApplication class]] localizedStringForKey:@"Cancel" value:@"Cancel" table:nil];
    sheet.cancelButtonIndex = [sheet addButtonWithTitle:cancel];
    _sheet = sheet;
    if (_first) {
        _displayAnimator = [[RevenantContextMenuAnimator alloc] init];
        id<UIContextMenuInteractionDelegate> delegate = _delegate;
        if ([delegate respondsToSelector:@selector(contextMenuInteraction:willDisplayMenuForConfiguration:animator:)])
            [delegate contextMenuInteraction:self willDisplayMenuForConfiguration:_configuration animator:_displayAnimator];
    }
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
        [sheet showFromRect:CGRectMake(_location.x, _location.y, 1, 1) inView:view animated:YES];
    else
        [sheet showInView:view.window];
}

- (void)revenant_reset
{
    _sheet = nil;
    _sheetDelegate = nil;
    _entries = nil;
    _visibleMenu = nil;
    _pendingSubmenu = nil;
    _chosen = nil;
    _configuration = nil;
    _displayAnimator = nil;
    _endAnimator = nil;
    _locationKnown = NO;
    _busy = NO;
    _first = NO;
}

- (void)revenant_sheetPresented
{
    RevenantContextMenuAnimator *animator = _displayAnimator;
    _displayAnimator = nil;
    _first = NO;
    [animator finish];
}

- (void)revenant_sheetWillDismissWithIndex:(NSInteger)index
{
    if (_replacing)
        return;
    UIMenuElement *element = index >= 0 && (NSUInteger)index < _entries.count && index != _sheet.cancelButtonIndex ? _entries[(NSUInteger)index] : nil;
    if ([element isKindOfClass:[UIMenu class]]) {
        _pendingSubmenu = (UIMenu *)element;
        return;
    }
    _chosen = element;
    _endAnimator = [[RevenantContextMenuAnimator alloc] init];
    id<UIContextMenuInteractionDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(contextMenuInteraction:willEndForConfiguration:animator:)])
        [delegate contextMenuInteraction:self willEndForConfiguration:_configuration animator:_endAnimator];
}

- (void)revenant_sheetDidDismissWithIndex:(NSInteger)index
{
    if (_replacing)
        return;
    UIMenu *submenu = _pendingSubmenu;
    if (submenu) {
        _pendingSubmenu = nil;
        _sheet = nil;
        _sheetDelegate = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self revenant_show:submenu];
        });
        return;
    }
    RevenantContextMenuAnimator *animator = _endAnimator;
    UIMenuElement *chosen = _chosen;
    UIView *view = _view;
    [self revenant_reset];
    [animator finish];
    if ([chosen isKindOfClass:[UIAction class]])
        [(UIAction *)chosen revenant_performWithSender:view];
    else if ([chosen isKindOfClass:[UICommand class]])
        [(UICommand *)chosen revenant_performWithSender:view target:nil];
}

- (UIMenu *)revenant_visibleMenu
{
    return _visibleMenu;
}

- (void)revenant_replaceVisibleMenu:(UIMenu *)menu
{
    if (!_sheet || !menu)
        return;
    _replacing = YES;
    [_sheet dismissWithClickedButtonIndex:_sheet.cancelButtonIndex animated:NO];
    _replacing = NO;
    _sheet = nil;
    _sheetDelegate = nil;
    [self revenant_show:menu];
}

@end
