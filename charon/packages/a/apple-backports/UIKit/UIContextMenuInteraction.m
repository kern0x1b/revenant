#import "CharonMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface CharonContextMenuAnimator : NSObject <UIContextMenuInteractionAnimating>
- (void)finish;
@end

@implementation CharonContextMenuAnimator {
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

@class CharonContextMenuSheet;

@interface UIContextMenuInteraction (CharonSheet)
- (void)charon_pressed:(UILongPressGestureRecognizer *)recognizer;
- (void)charon_sheetPresented;
- (void)charon_sheetWillDismissWithIndex:(NSInteger)index;
- (void)charon_sheetDidDismissWithIndex:(NSInteger)index;
@end

static const char charon_sheet_delegate_key;

@interface CharonContextMenuSheet : NSObject <UIActionSheetDelegate>
@property (nonatomic, weak) UIContextMenuInteraction *interaction;
@end

@implementation CharonContextMenuSheet {
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
    [_interaction charon_sheetPresented];
}

- (void)actionSheet:(UIActionSheet *)actionSheet willDismissWithButtonIndex:(NSInteger)buttonIndex
{
    [_interaction charon_sheetWillDismissWithIndex:buttonIndex];
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    [_interaction charon_sheetDidDismissWithIndex:buttonIndex];
}

@end

static BOOL charon_leaf(UIMenuElement *element)
{
    return [element isKindOfClass:[UIAction class]] || [element isKindOfClass:[UICommand class]];
}

static UIMenuElementAttributes charon_attributes(UIMenuElement *element)
{
    return [element isKindOfClass:[UIAction class]] ? ((UIAction *)element).attributes : ((UICommand *)element).attributes;
}

static UIMenuElementState charon_state(UIMenuElement *element)
{
    return [element isKindOfClass:[UIAction class]] ? ((UIAction *)element).state : ((UICommand *)element).state;
}

static void charon_collect_deferred(NSArray *elements, NSMutableArray *found)
{
    for (UIMenuElement *element in elements) {
        if ([element isKindOfClass:[UIDeferredMenuElement class]])
            [found addObject:element];
        else if ([element isKindOfClass:[UIMenu class]] && (((UIMenu *)element).options & UIMenuOptionsDisplayInline))
            charon_collect_deferred(((UIMenu *)element).children, found);
    }
}

static BOOL charon_menu_has_content(UIMenu *menu, NSDictionary *resolved)
{
    for (UIMenuElement *child in menu.children) {
        if (charon_leaf(child)) {
            if (!(charon_attributes(child) & (UIMenuElementAttributesDisabled | UIMenuElementAttributesHidden)))
                return YES;
        } else if ([child isKindOfClass:[UIMenu class]]) {
            if (charon_menu_has_content((UIMenu *)child, resolved))
                return YES;
        } else if ([child isKindOfClass:[UIDeferredMenuElement class]]) {
            if ([resolved[child] count])
                return YES;
        }
    }
    return NO;
}

static void charon_flatten(NSArray *elements, NSDictionary *resolved, NSMutableArray *out)
{
    for (UIMenuElement *element in elements) {
        if (charon_leaf(element)) {
            if (!(charon_attributes(element) & (UIMenuElementAttributesDisabled | UIMenuElementAttributesHidden)))
                [out addObject:element];
        } else if ([element isKindOfClass:[UIMenu class]]) {
            UIMenu *menu = (UIMenu *)element;
            if (menu.options & UIMenuOptionsDisplayInline)
                charon_flatten(menu.children, resolved, out);
            else if (charon_menu_has_content(menu, resolved))
                [out addObject:menu];
        } else if ([element isKindOfClass:[UIDeferredMenuElement class]]) {
            NSArray *items = resolved[element];
            NSMutableArray *plain = [NSMutableArray array];
            for (UIMenuElement *item in items) {
                if (![item isKindOfClass:[UIDeferredMenuElement class]])
                    [plain addObject:item];
            }
            charon_flatten(plain, resolved, out);
        }
    }
}

static NSString *charon_button_title(UIMenuElement *element)
{
    NSString *title = element.title;
    if (!title.length && [element isKindOfClass:[UIAction class]])
        title = ((UIAction *)element).discoverabilityTitle;
    if (!title.length)
        return nil;
    if ([element isKindOfClass:[UIMenu class]])
        return [title stringByAppendingString:@" ›"];
    UIMenuElementState state = charon_state(element);
    if (state == UIMenuElementStateOn)
        return [@"✓ " stringByAppendingString:title];
    if (state == UIMenuElementStateMixed)
        return [@"– " stringByAppendingString:title];
    return title;
}

static BOOL charon_destructive(UIMenuElement *element)
{
    if ([element isKindOfClass:[UIMenu class]])
        return (((UIMenu *)element).options & UIMenuOptionsDestructive) != 0;
    return (charon_attributes(element) & UIMenuElementAttributesDestructive) != 0;
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
    CharonContextMenuSheet *_sheetDelegate;
    NSArray *_entries;
    CharonContextMenuAnimator *_displayAnimator;
    CharonContextMenuAnimator *_endAnimator;
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
        _recognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(charon_pressed:)];
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

- (void)charon_pressed:(UILongPressGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateBegan)
        [self charon_beginAtLocation:[recognizer locationInView:_view]];
}

- (void)charon_beginAtLocation:(CGPoint)location
{
    id<UIContextMenuInteractionDelegate> delegate = _delegate;
    if (!_view.window || _busy || _sheet || !delegate)
        return;
    UIContextMenuConfiguration *configuration = [delegate contextMenuInteraction:self configurationForMenuAtLocation:location];
    if (!configuration)
        return;
    UIContextMenuActionProvider provider = [configuration charon_actionProvider];
    UIMenu *menu = provider ? provider(@[]) : nil;
    if (![menu isKindOfClass:[UIMenu class]])
        return;
    charon_menus_say_once(@"sheet", [NSString stringWithFormat:@"UIContextMenuInteraction: iOS %@ draws no menu preview, highlight or morph, so the menu is shown as an action sheet; the preview provider and the preview delegate methods are never called",
                                                               [UIDevice currentDevice].systemVersion]);
    _busy = YES;
    _configuration = configuration;
    _location = location;
    _locationKnown = YES;
    _first = YES;
    [self charon_show:menu];
}

- (void)charon_show:(UIMenu *)menu
{
    NSMutableArray *deferred = [NSMutableArray array];
    charon_collect_deferred(menu.children, deferred);
    if (!deferred.count) {
        [self charon_show:menu resolved:@{}];
        return;
    }
    NSMutableDictionary *resolved = [NSMutableDictionary dictionary];
    __block NSUInteger pending = deferred.count;
    __block BOOL shown = NO;
    void (^show)(void) = ^{
        if (shown)
            return;
        shown = YES;
        [self charon_show:menu resolved:resolved];
    };
    for (UIDeferredMenuElement *element in deferred) {
        [element charon_fulfillWithCompletion:^(NSArray<UIMenuElement *> *elements) {
            if (shown)
                return;
            resolved[element] = elements;
            if (--pending == 0)
                show();
        }];
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), show);
}

- (void)charon_show:(UIMenu *)menu resolved:(NSDictionary *)resolved
{
    UIView *view = _view;
    NSMutableArray *elements = [NSMutableArray array];
    charon_flatten(menu.children, resolved, elements);
    NSMutableArray *entries = [NSMutableArray array];
    NSMutableArray *titles = [NSMutableArray array];
    UIMenuElement *destructive = nil;
    NSString *destructiveTitle = nil;
    for (UIMenuElement *element in elements) {
        NSString *title = charon_button_title(element);
        if (!title)
            continue;
        if (!destructive && charon_destructive(element)) {
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
        [self charon_reset];
        return;
    }
    _visibleMenu = menu;
    _entries = entries;
    _sheetDelegate = [[CharonContextMenuSheet alloc] init];
    _sheetDelegate.interaction = self;
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:menu.title.length ? menu.title : nil delegate:_sheetDelegate cancelButtonTitle:nil
                                         destructiveButtonTitle:destructiveTitle otherButtonTitles:nil];
    // A sheet's delegate is not retained and UIKit still calls it after the interaction has let go of
    // the sheet, so the sheet itself keeps the delegate for as long as the sheet lives.
    objc_setAssociatedObject(sheet, &charon_sheet_delegate_key, _sheetDelegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    for (NSString *title in titles)
        [sheet addButtonWithTitle:title];
    NSString *cancel = [[NSBundle bundleForClass:[UIApplication class]] localizedStringForKey:@"Cancel" value:@"Cancel" table:nil];
    sheet.cancelButtonIndex = [sheet addButtonWithTitle:cancel];
    _sheet = sheet;
    if (_first) {
        _displayAnimator = [[CharonContextMenuAnimator alloc] init];
        id<UIContextMenuInteractionDelegate> delegate = _delegate;
        if ([delegate respondsToSelector:@selector(contextMenuInteraction:willDisplayMenuForConfiguration:animator:)])
            [delegate contextMenuInteraction:self willDisplayMenuForConfiguration:_configuration animator:_displayAnimator];
    }
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
        [sheet showFromRect:CGRectMake(_location.x, _location.y, 1, 1) inView:view animated:YES];
    else
        [sheet showInView:view.window];
}

- (void)charon_reset
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

- (void)charon_sheetPresented
{
    CharonContextMenuAnimator *animator = _displayAnimator;
    _displayAnimator = nil;
    _first = NO;
    [animator finish];
}

- (void)charon_sheetWillDismissWithIndex:(NSInteger)index
{
    if (_replacing)
        return;
    UIMenuElement *element = index >= 0 && (NSUInteger)index < _entries.count && index != _sheet.cancelButtonIndex ? _entries[(NSUInteger)index] : nil;
    if ([element isKindOfClass:[UIMenu class]]) {
        _pendingSubmenu = (UIMenu *)element;
        return;
    }
    _chosen = element;
    _endAnimator = [[CharonContextMenuAnimator alloc] init];
    id<UIContextMenuInteractionDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(contextMenuInteraction:willEndForConfiguration:animator:)])
        [delegate contextMenuInteraction:self willEndForConfiguration:_configuration animator:_endAnimator];
}

- (void)charon_sheetDidDismissWithIndex:(NSInteger)index
{
    if (_replacing)
        return;
    UIMenu *submenu = _pendingSubmenu;
    if (submenu) {
        _pendingSubmenu = nil;
        _sheet = nil;
        _sheetDelegate = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self charon_show:submenu];
        });
        return;
    }
    CharonContextMenuAnimator *animator = _endAnimator;
    UIMenuElement *chosen = _chosen;
    UIView *view = _view;
    [self charon_reset];
    [animator finish];
    if ([chosen isKindOfClass:[UIAction class]])
        [(UIAction *)chosen charon_performWithSender:view];
    else if ([chosen isKindOfClass:[UICommand class]])
        [(UICommand *)chosen charon_performWithSender:view target:nil];
}

- (UIMenu *)charon_visibleMenu
{
    return _visibleMenu;
}

- (void)charon_replaceVisibleMenu:(UIMenu *)menu
{
    if (!_sheet || !menu)
        return;
    _replacing = YES;
    [_sheet dismissWithClickedButtonIndex:_sheet.cancelButtonIndex animated:NO];
    _replacing = NO;
    _sheet = nil;
    _sheetDelegate = nil;
    [self charon_show:menu];
}

@end
