// The list, grid and map templates and the interface controller, on iOS 6, as the real view
// controllers the header says they are, in the shapes the SDK declares.
//
// The buttons of CarPlay are NSObjects and not views (CarPlayTemplates12.m draws them), so each of
// these three templates draws the buttons it holds:
//
//   CPListTemplate    a UITableViewController over the template's own sections and rows, with each
//                     row's own handler called when the row is chosen, and the leading bar buttons
//                     the CPBarButtonProviding protocol asks for drawn in the template's own bar;
//   CPGridTemplate    a UICollectionViewController over the template's own grid buttons, each drawn
//                     by the button itself and its own handler called when it is chosen;
//   CPMapTemplate     the release's own MKMapView -- the only map this port has -- with the
//                     template's own map buttons drawn over it inside the window's own safe area,
//                     and the release's own navigation alert shown over the map when there is one.
//
// CPInterfaceController owns a CPWindow, keeps the root template and the tab templates and the
// pushed stack, draws the bar buttons of whatever template is on top, and sends the delegate the
// four template lifecycle messages the header declares. The scene it belongs to is the wall, and
// that is the registry's, not this file's.
#import <CarPlay/CarPlay.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "CharonCarPlayTemplate.h"

// The three buttons' own drawing and their own taps, which are implemented in
// CarPlayTemplates12.m and declared here so the templates that hold them can ask. Every member is
// prefixed, so none of it is API the package carries.
@interface CPBarButton (CharonDrawing)
- (void)charon_drawInRect:(CGRect)rect alpha:(CGFloat)alpha;
- (void)charon_tap;
@end

@interface CPGridButton (CharonDrawing)
- (void)charon_drawInRect:(CGRect)rect;
- (void)charon_tap;
@end

@interface CPMapButton (CharonDrawing)
- (void)charon_drawInRect:(CGRect)rect;
- (void)charon_tap;
@end

// The template's own view controller, asked for by the interface controller when it pushes it.
// Declared and not implemented here; each template implements it, which is where its drawing is.
@interface CPTemplate (CharonDrawing)
- (UIViewController *)charon_viewControllerForInterfaceController:(CPInterfaceController *)controller;
@end

// A row's handler, as the object the header's handler type is: the call the list template makes
// when a row is chosen, so the handler is a real object with a real message and not a cast block.
@interface CharonListItemHandler : NSObject
- (void)charon_call:(id)item completion:(id)completion;
@end

// The grid source, declared before the grid template that uses it.
@interface CharonGridSource : NSObject <UICollectionViewDataSource, UICollectionViewDelegate>
+ (instancetype)sourceForTemplate:(CPGridTemplate *)template;
@end

// The interface controller this port is currently pushing through, so a template that has to
// dismiss itself can ask the one that presented it. Charon's own, so it carries no API.
@interface CharonCarPlayInterface : NSObject
+ (instancetype)current;
@property (nonatomic, weak) CPInterfaceController *controller;
@end

// The map template's own map buttons, drawn over its map, inside the window's own safe area.
@interface CharonMapButtons : UIView
@property (nonatomic, copy) NSArray<CPMapButton *> *charon_buttons;
@end

// The interface controller's own content window, which is the window its templates are drawn into.
@interface CPInterfaceController (CharonWindow)
@property (nonatomic, readonly, strong) CPWindow *contentWindow;
@end

// ============================ the list item ============================

// The row's own state, held beside the row because a category cannot add an ivar and the row is a
// CATEGORY on the release's own name (see CPListItem.m for why it has to be one). Charon's own, and
// every member prefixed, so it carries no API.
@interface CharonListRowState : NSObject
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSString *detailText;
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, strong) UIImage *accessoryImage;
@property (nonatomic, assign) NSInteger accessoryType;
@property (nonatomic, assign) BOOL showsDisclosureIndicator;
@property (nonatomic, strong) id userInfo;
@property (nonatomic, copy) id handler;
@property (nonatomic, assign) BOOL explicitContent;
@property (nonatomic, assign) double playbackProgress;
@property (nonatomic, assign) BOOL playing;
@property (nonatomic, assign) NSInteger playingIndicatorLocation;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) BOOL showsExplicitLabel;
@end

@implementation CharonListRowState
@synthesize text = _text;
@synthesize detailText = _detailText;
@synthesize image = _image;
@synthesize accessoryImage = _accessoryImage;
@synthesize accessoryType = _accessoryType;
@synthesize showsDisclosureIndicator = _showsDisclosureIndicator;
@synthesize userInfo = _userInfo;
@synthesize handler = _handler;
@synthesize explicitContent = _explicitContent;
@synthesize playbackProgress = _playbackProgress;
@synthesize playing = _playing;
@synthesize playingIndicatorLocation = _playingIndicatorLocation;
@synthesize enabled = _enabled;
@synthesize showsExplicitLabel = _showsExplicitLabel;
@end

// A CATEGORY on the name, and not a class implementation: the release carries a class of another
// framework under this name, so the name is an alias (CPListItem.m) and ld64 merges a category
// written on it in this image into the alias's own class, which is the row. A class implementation
// here would define a second class of that name and the runtime would take one of the two.
@implementation CPListItem (CharonRow)

- (CharonListRowState *)charon_state
{
    static const void *key = &key;
    CharonListRowState *state = objc_getAssociatedObject(self, key);
    if (!state) {
        state = [[CharonListRowState alloc] init];
        state.enabled = YES;
        state.showsDisclosureIndicator = YES;
        objc_setAssociatedObject(self, key, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return state;
}

- (CharonListRowState *)charon_stateInitWithText:(NSString *)text
                               detailText:(NSString *)detailText
                                    image:(UIImage *)image
                           accessoryImage:(UIImage *)accessoryImage
                            accessoryType:(NSInteger)accessoryType
{
    CharonListRowState *state = [[CharonListRowState alloc] init];
    state.text = text ?: @"";
    state.detailText = detailText ?: @"";
    state.image = image;
    state.accessoryImage = accessoryImage;
    // The header's own rule: an accessory image sets the accessory type to none, because the two are
    // the same slot and the caller's own image is what should be in it.
    state.accessoryType = accessoryImage ? 0 : accessoryType;
    state.enabled = YES;
    state.showsDisclosureIndicator = accessoryType == 1;
    return state;
}

- (instancetype)initWithText:(NSString *)text
                    detailText:(NSString *)detailText
                         image:(UIImage *)image
                accessoryImage:(UIImage *)accessoryImage
                 accessoryType:(NSInteger)accessoryType
{
    // The alias's own -initWithText:... answers as the release's class does (see charon_alias.h), so
    // the row is set up beside it, which is what a category on an aliased name is for. Going through
    // NSObject's -init directly, because [self alloc] inside a category is the alias's -alloc and
    // would answer the release's class, which is not a row.
    self = ((id (*)(id, SEL))objc_msgSend)([CPListItem class], @selector(alloc));
    self = ((id (*)(id, SEL, id))objc_msgSend)(self, @selector(init), @"");
    [self charon_setState:[self charon_stateInitWithText:text detailText:detailText image:image
                                     accessoryImage:accessoryImage accessoryType:accessoryType]];
    return self;
}

- (void)charon_setState:(CharonListRowState *)state
{
    static const void *key = &key;
    objc_setAssociatedObject(self, key, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)text { return [self charon_state].text; }
- (void)setText:(NSString *)text { [self charon_state].text = text ?: @""; }
- (NSString *)detailText { return [self charon_state].detailText; }
- (void)setDetailText:(NSString *)detailText { [self charon_state].detailText = detailText ?: @""; }
- (UIImage *)image { return [self charon_state].image; }
- (void)setImage:(UIImage *)image { [self charon_state].image = image; }
- (UIImage *)accessoryImage { return [self charon_state].accessoryImage; }
- (void)setAccessoryImage:(UIImage *)image
{
    [self charon_state].accessoryImage = image;
    if (image) {
        [self charon_state].accessoryType = 0;
    }
}
- (NSInteger)accessoryType { return [self charon_state].accessoryType; }
- (void)setAccessoryType:(NSInteger)accessoryType { [self charon_state].accessoryType = accessoryType; }
- (BOOL)showsDisclosureIndicator { return [self charon_state].showsDisclosureIndicator; }
- (void)setShowsDisclosureIndicator:(BOOL)shows { [self charon_state].showsDisclosureIndicator = shows; }
- (id)userInfo { return [self charon_state].userInfo; }
- (void)setUserInfo:(id)userInfo { [self charon_state].userInfo = userInfo; }
- (id)handler { return [self charon_state].handler; }
- (void)setHandler:(id)handler { [self charon_state].handler = handler; }
- (BOOL)isExplicitContent { return [self charon_state].explicitContent; }
- (void)setExplicitContent:(BOOL)explicitContent { [self charon_state].explicitContent = explicitContent; }
- (double)playbackProgress { return [self charon_state].playbackProgress; }
- (void)setPlaybackProgress:(double)progress { [self charon_state].playbackProgress = progress; }
- (BOOL)isPlaying { return [self charon_state].playing; }
- (void)setPlaying:(BOOL)playing { [self charon_state].playing = playing; }
- (NSInteger)playingIndicatorLocation { return [self charon_state].playingIndicatorLocation; }
- (void)setPlayingIndicatorLocation:(NSInteger)location { [self charon_state].playingIndicatorLocation = location; }
- (BOOL)isEnabled { return [self charon_state].enabled; }
- (void)setEnabled:(BOOL)enabled { [self charon_state].enabled = enabled; }
- (BOOL)isShowingExplicitLabel { return [self charon_state].showsExplicitLabel; }
- (void)setShowsExplicitLabel:(BOOL)shows { [self charon_state].showsExplicitLabel = shows; }

// The header's own class property: the largest image a row's image may be. Charon's own, so no API.
+ (CGSize)maximumImageSize
{
    return CGSizeMake(60.0, 60.0);
}

// The row's own handler, called when the row is chosen, with the item and the completion the
// handler's own signature takes. Charon's own, so it carries no API.
- (void)charon_selected
{
    id handler = [self charon_state].handler;
    void (*call)(id, SEL, id, id) = (void (*)(id, SEL, id, id))objc_msgSend;
    SEL selector = NSSelectorFromString(@"charon_call");
    if (handler && [handler respondsToSelector:selector]) {
        call(handler, selector, self, ^{
        });
    }
}

@end

@implementation CharonListItemHandler
- (void)charon_call:(id)item completion:(id)completion { }
@end

// ============================ the list section ============================

@implementation CPListSection {
    NSArray<id<CPListTemplateItem>> *_items;
    NSString *_header;
    NSString *_headerSubtitle;
    NSString *_sectionIndexTitle;
    UIImage *_headerImage;
    CPButton *_headerButton;
}

@synthesize header = _header;
@synthesize headerSubtitle = _headerSubtitle;
@synthesize headerImage = _headerImage;
@synthesize headerButton = _headerButton;
@synthesize sectionIndexTitle = _sectionIndexTitle;
@synthesize items = _items;

- (instancetype)initWithItems:(NSArray<id<CPListTemplateItem>> *)items
{
    self = [super init];
    if (self) {
        _items = [items copy] ?: @[];
    }
    return self;
}

- (instancetype)initWithItems:(NSArray<id<CPListTemplateItem>> *)items
                      header:(NSString *)header
                 sectionIndexTitle:(NSString *)sectionIndexTitle
{
    self = [self initWithItems:items];
    if (self) {
        _header = [header copy];
        _sectionIndexTitle = [sectionIndexTitle copy];
    }
    return self;
}

- (NSUInteger)indexOfItem:(id<CPListTemplateItem>)item
{
    return [_items indexOfObject:item];
}

- (id<CPListTemplateItem>)itemAtIndex:(NSUInteger)index
{
    return index < _items.count ? _items[index] : nil;
}

// The header's own section update, which the template's own -updateSections: goes through.
- (void)updateItems:(NSArray<id<CPListTemplateItem>> *)items
              header:(NSString *)header
     headerSubtitle:(NSString *)headerSubtitle
        headerImage:(UIImage *)headerImage
       sectionIndexTitle:(NSString *)sectionIndexTitle
        headerButton:(CPButton *)headerButton
{
    _items = [items copy] ?: @[];
    _header = [header copy];
    _headerSubtitle = [headerSubtitle copy];
    _headerImage = headerImage;
    _sectionIndexTitle = [sectionIndexTitle copy];
    _headerButton = headerButton;
}

// The 15.0 object's storage, reached from CarPlayTemplates150.m. It is declared in
// CharonCarPlayTemplate.h, and every name is Charon-prefixed, so none of it is API and none of it
// appears in this object's exports. The strings copy on the way in, which is what CPListSection.h:82-97's
// own `copy` would do anyway; the image and the button take what they are given, and a nil in clears.
- (void)charon_setHeaderSubtitle:(NSString *)headerSubtitle { _headerSubtitle = [headerSubtitle copy]; }
- (void)charon_setHeaderImage:(UIImage *)headerImage { _headerImage = headerImage; }
- (void)charon_setHeaderButton:(CPButton *)headerButton { _headerButton = headerButton; }

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_items forKey:@"CPListSectionItems"];
    [coder encodeObject:_header forKey:@"CPListSectionHeader"];
    [coder encodeObject:_headerSubtitle forKey:@"CPListSectionHeaderSubtitle"];
    [coder encodeObject:_sectionIndexTitle forKey:@"CPListSectionIndexTitle"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _items = [coder decodeObjectForKey:@"CPListSectionItems"] ?: @[];
        _header = [coder decodeObjectForKey:@"CPListSectionHeader"];
        _headerSubtitle = [coder decodeObjectForKey:@"CPListSectionHeaderSubtitle"];
        _sectionIndexTitle = [coder decodeObjectForKey:@"CPListSectionIndexTitle"];
    }
    return self;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

@end

// ============================ the bar a template draws its buttons in ============================

// The bar the templates put their leading buttons in. It is a view the templates own and add to
// themselves, and it draws CPBarButton objects -- which are NSObjects, not views -- by asking each
// one to draw itself. Charon's own, so it carries no API.
@interface CharonCarPlayBar : UIView
@property (nonatomic, copy) NSArray<CPBarButton *> *charon_buttons;
@end

@implementation CharonCarPlayBar {
    NSArray<CPBarButton *> *_buttons;
}

@synthesize charon_buttons = _buttons;

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // A CPBarButton is an NSObject and not a view, so the bar cannot hand it a touch. The bar
        // takes the touch itself, works out which mark is under it -- the same arithmetic its own
        // -drawRect: used to lay them out -- and calls that button's own handler.
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                action:@selector(charon_tappedAtPoint:)];
        [self addGestureRecognizer:tap];
    }
    return self;
}

- (void)setCharon_buttons:(NSArray<CPBarButton *> *)buttons
{
    _buttons = [buttons copy] ?: @[];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    CGFloat width = MIN(88.0, CGRectGetWidth(rect) / (CGFloat)MAX((NSUInteger)_buttons.count, 1U));
    CGFloat at = 0.0;
    for (CPBarButton *button in _buttons) {
        // The header's own rule: the bar shows at most two leading buttons, and only the first two.
        if (at >= 2.0 * width) {
            break;
        }
        if (button.isEnabled) {
            [(CPBarButton *)button charon_drawInRect:CGRectMake(at, 0.0, width, CGRectGetHeight(rect)) alpha:1.0];
        } else {
            [(CPBarButton *)button charon_drawInRect:CGRectMake(at, 0.0, width, CGRectGetHeight(rect)) alpha:0.4];
        }
        at += width;
    }
}

- (void)charon_tappedAtPoint:(UITapGestureRecognizer *)gesture
{
    CGPoint point = [gesture locationInView:self];
    CGFloat width = MIN(88.0, CGRectGetWidth(self.bounds) / (CGFloat)MAX((NSUInteger)_buttons.count, 1U));
    NSUInteger index = width > 0.0 ? (NSUInteger)(point.x / width) : 0U;
    if (index >= _buttons.count) {
        return;
    }
    CPBarButton *button = _buttons[index];
    if (!button.isEnabled) {
        return;
    }
    // The button's own handler, which a program gave the button, called by the button.
    [(CPBarButton *)button charon_tap];
}

@end

@interface CharonListSource : NSObject <UITableViewDataSource, UITableViewDelegate>
+ (instancetype)sourceForTemplate:(CPListTemplate *)template;
@end

// The list template's own navigation bar, kept so the leading bar buttons go into it rather than
// into a controller that has no bar of its own on this release.
static UINavigationBar *_listNavigationBar;

// ============================ the list template ============================

@interface CPListTemplate (CharonRows)
- (NSArray<CPListItem *> *)charon_items;
@property (nonatomic, copy) NSString *title;
@end

@implementation CPListTemplate {
    NSArray<CPListSection *> *_sections;
    __weak id<CPListTemplateDelegate> _delegate;
    NSArray<NSString *> *_emptyViewTitleVariants;
    NSArray<NSString *> *_emptyViewSubtitleVariants;
    CPAssistantCellConfiguration *_assistantCellConfiguration;
    UITableViewController *_list;
    CharonCarPlayBar *_charon_bar;
    // The storage the 18.4 and 26.0 objects reach (CarPlayListTemplate184.m, CarPlayGrid260.m). A
    // category cannot add an ivar and the class's @implementation is this file, so the values those
    // members keep live here behind the Charon-prefixed accessors of CharonCarPlayTemplate.h - the same
    // shape CarPlayNavigationSession12.m already uses for _turnCardColor. Every name is Charon-prefixed,
    // so none of it is API and none of it appears in this object's exports: this file is 12.0 and stays
    // 12.0, and the 18.4 and 26.0 selectors live in their own objects.
    BOOL _charon_showsSpinnerWhileEmpty;
    NSArray<CPGridButton *> *_charon_headerGridButtons;
}

@synthesize delegate = _delegate;
@synthesize emptyViewTitleVariants = _emptyViewTitleVariants;
@synthesize emptyViewSubtitleVariants = _emptyViewSubtitleVariants;
@synthesize assistantCellConfiguration = _assistantCellConfiguration;

- (instancetype)initWithTitle:(NSString *)title sections:(NSArray<CPListSection *> *)sections
{
    self = [super init];
    if (self) {
        self.title = title;
        _sections = [sections copy] ?: @[];
        _emptyViewTitleVariants = @[];
        _emptyViewSubtitleVariants = @[];
    }
    return self;
}

- (NSArray<CPListSection *> *)sections
{
    return _sections;
}

- (void)updateSections:(NSArray<CPListSection *> *)sections
{
    _sections = [sections copy] ?: @[];
    [_list.tableView reloadData];
}

- (NSUInteger)sectionCount
{
    return _sections.count;
}

- (NSUInteger)itemCount
{
    return [self charon_items].count;
}

// The header's own class properties, which are limits and not counts of this template: a list
// template takes at most so many sections and so many items, and the number here is Apple's own.
+ (NSUInteger)maximumItemCount
{
    return 100;
}

+ (NSUInteger)maximumSectionCount
{
    return 20;
}

- (NSIndexPath *)indexPathForItem:(id<CPListTemplateItem>)item
{
    __block NSUInteger found = NSNotFound;
    [_sections enumerateObjectsUsingBlock:^(CPListSection *section, NSUInteger index, BOOL *stop) {
        if ([section.items containsObject:item]) {
            found = index;
            *stop = YES;
        }
    }];
    NSUInteger section = found;
    if (section == NSNotFound) {
        return nil;
    }
    NSArray<id<CPListTemplateItem>> *rows = _sections[section].items;
    NSUInteger row = [rows indexOfObject:item];
    if (row == NSNotFound) {
        return nil;
    }
    return [NSIndexPath indexPathForRow:(NSInteger)row inSection:(NSInteger)section];
}

// The rows, out of the template's own sections, in the section order the caller gave.
- (NSArray<CPListItem *> *)charon_items
{
    NSMutableArray *all = [NSMutableArray array];
    for (CPListSection *section in _sections) {
        for (id<CPListTemplateItem> item in section.items) {
            if ([item isKindOfClass:[CPListItem class]]) {
                [all addObject:(CPListItem *)item];
            }
        }
    }
    return all;
}

// The list, as the table view controller the header says a list template is, with the template's own
// bar buttons drawn in its own bar.
- (UIViewController *)charon_viewControllerForInterfaceController:(CPInterfaceController *)controller
{
    if (_list) {
        return _list;
    }
    _list = [[UITableViewController alloc] initWithStyle:UITableViewStylePlain];
    _list.title = self.title;
    // The release's own chrome, not a flat imitation of it: a UIBarStyleBlack bar, which on iOS 6 is
    // the glossy black one with the release's own gradient and its own hairline, and the release's own
    // grouped cells below it. The list template's own leading bar buttons go in the bar's leading side
    // where a navigation bar puts them.
    _list.navigationItem.title = self.title;
    _list.view.backgroundColor = [UIColor blackColor];
    // A table view controller has no navigation bar of its own on this release, so the glossy black
    // bar the list template needs is a real UINavigationBar the template owns and puts on top of its
    // own view -- the release's own bar, drawn by the release, not a picture of one.
    UINavigationBar *bar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0.0, 0.0, 1024.0, 44.0)];
    bar.barStyle = UIBarStyleBlack;
    bar.translucent = NO;
    [_list.view addSubview:bar];
    _listNavigationBar = bar;
    _list.tableView.backgroundColor = [UIColor blackColor];
    _list.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    NSMutableArray *barItems = [NSMutableArray array];
    for (CPBarButton *button in self.barButtons) {
        [barItems addObject:[[UIBarButtonItem alloc] initWithTitle:button.title
                                                            style:UIBarButtonItemStylePlain
                                                           target:button
                                                           action:@selector(charon_tap)]];
    }
    barItems = [NSMutableArray array];
    for (CPBarButton *button in self.barButtons) {
        [barItems addObject:[[UIBarButtonItem alloc] initWithTitle:button.title
                                                            style:UIBarButtonItemStylePlain
                                                           target:button
                                                           action:@selector(charon_tap)]];
    }
    _listNavigationBar.topItem.leftBarButtonItems = barItems;
    _list.tableView.dataSource = (id)[CharonListSource sourceForTemplate:self];
    _list.tableView.delegate = (id)[CharonListSource sourceForTemplate:self];
    if (_sections.count == 0) {
        if (_charon_showsSpinnerWhileEmpty) {
            // The 18.4 member's answer, drawn here because the empty state is here. CPListTemplate.h:226
            // declares it `assign` and says the template shows a spinner while it is empty, so the
            // spinner is the whole of the property and this is where a caller asking for it sees it. The
            // indicator is this release's own UIActivityIndicatorView, centred in the table's own view,
            // and it spins because the template has nothing to show yet - which is the state the property
            // is about.
            UIActivityIndicatorView *spinner =
                    [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
            spinner.center = CGPointMake(CGRectGetMidX(_list.view.bounds), CGRectGetMidY(_list.view.bounds));
            spinner.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [spinner startAnimating];
            _list.tableView.backgroundView = spinner;
        } else {
            // The header's own empty view, which is the title variants the caller gave, or nothing.
            NSString *empty = _emptyViewTitleVariants.firstObject ?: _emptyViewSubtitleVariants.firstObject;
            UILabel *label = [[UILabel alloc] initWithFrame:_list.view.bounds];
            label.text = empty;
            label.textAlignment = NSTextAlignmentCenter;
            label.textColor = [UIColor colorWithWhite:1.0 alpha:0.6];
            label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            _list.tableView.backgroundView = label;
        }
    }
    _charon_bar = [[CharonCarPlayBar alloc] initWithFrame:CGRectMake(0.0, 0.0, 176.0, 44.0)];
    _charon_bar.charon_buttons = self.barButtons;
    _charon_bar.backgroundColor = [UIColor clearColor];
    [_list.view addSubview:_charon_bar];
    return _list;
}

// The protocol's own leading buttons, which the list template holds the way the header says it does.
- (NSArray<CPBarButton *> *)barButtons
{
    return _charon_bar.charon_buttons ?: @[];
}

- (void)setBarButtons:(NSArray<CPBarButton *> *)barButtons
{
    if (!_charon_bar) {
        _charon_bar = [[CharonCarPlayBar alloc] initWithFrame:CGRectMake(0.0, 0.0, 176.0, 44.0)];
        _charon_bar.backgroundColor = [UIColor clearColor];
    }
    _charon_bar.charon_buttons = barButtons;
}

// The 18.4 and 26.0 objects' storage, reached from CarPlayListTemplate184.m and CarPlayGrid260.m. They
// are declared in CharonCarPlayTemplate.h and every name is Charon-prefixed, so none of this is API and
// none of it appears in this object's exports.
- (BOOL)charon_showsSpinnerWhileEmpty { return _charon_showsSpinnerWhileEmpty; }

- (void)charon_setShowsSpinnerWhileEmpty:(BOOL)showsSpinnerWhileEmpty
{
    _charon_showsSpinnerWhileEmpty = showsSpinnerWhileEmpty;
}

- (NSArray<CPGridButton *> *)charon_headerGridButtons { return _charon_headerGridButtons; }

- (void)charon_setHeaderGridButtons:(NSArray<CPGridButton *> *)headerGridButtons
{
    // `copy` on the way in, per CPListTemplate.h:265, so a later change to the caller's array does not
    // change the template's. A nil in stays nil, which is what `nullable` means.
    _charon_headerGridButtons = [headerGridButtons copy];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_sections forKey:@"CPListTemplateSections"];
    [coder encodeObject:_emptyViewTitleVariants forKey:@"CPListTemplateEmptyViewTitleVariants"];
    [coder encodeObject:_emptyViewSubtitleVariants forKey:@"CPListTemplateEmptyViewSubtitleVariants"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        _sections = [coder decodeObjectForKey:@"CPListTemplateSections"] ?: @[];
        _emptyViewTitleVariants = [coder decodeObjectForKey:@"CPListTemplateEmptyViewTitleVariants"] ?: @[];
        _emptyViewSubtitleVariants = [coder decodeObjectForKey:@"CPListTemplateEmptyViewSubtitleVariants"] ?: @[];
    }
    return self;
}

@end

// The list's own data source and delegate, in the template's own object file so the template owns
// them. Charon's own class, and every member prefixed, so it carries no API.
@implementation CharonListSource {
    __weak CPListTemplate *_template;
}

+ (instancetype)sourceForTemplate:(CPListTemplate *)template
{
    CharonListSource *source = [[CharonListSource alloc] init];
    source->_template = template;
    return source;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return (NSInteger)_template.sectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSArray<CPListSection *> *sections = _template.sections;
    if (section < 0 || (NSUInteger)section >= sections.count) {
        return 0;
    }
    return (NSInteger)sections[(NSUInteger)section].items.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSArray<CPListSection *> *sections = _template.sections;
    if (section < 0 || (NSUInteger)section >= sections.count) {
        return nil;
    }
    return sections[(NSUInteger)section].header;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *const cellIdentifier = @"CharonCarPlayListRow";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:cellIdentifier];
        // The release's own cell: a grouped cell is the release's own gradient plate with a hairline
        // under it, so nothing here is drawn to replace it -- the skin is only what the release's own
        // cell does not give, which is the shadow the release draws per cell and this does not.
        cell.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.92];
        cell.textLabel.textColor = [UIColor colorWithWhite:0.05f alpha:1.0f];
        cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.3 alpha:1.0];
        cell.textLabel.font = [UIFont systemFontOfSize:17.0];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0];
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    }
    NSArray<CPListSection *> *sections = _template.sections;
    if ((NSUInteger)indexPath.section < sections.count) {
        NSArray<id<CPListTemplateItem>> *rows = sections[(NSUInteger)indexPath.section].items;
        if ((NSUInteger)indexPath.row < rows.count && [rows[(NSUInteger)indexPath.row] isKindOfClass:[CPListItem class]]) {
            CPListItem *item = (CPListItem *)rows[(NSUInteger)indexPath.row];
            cell.textLabel.text = item.text;
            cell.detailTextLabel.text = item.detailText;
            cell.imageView.image = item.image;
            cell.accessoryView = item.accessoryImage ? [[UIImageView alloc] initWithImage:item.accessoryImage] : nil;
            if (!item.accessoryImage) {
                cell.accessoryType = item.showsDisclosureIndicator
                    ? UITableViewCellAccessoryDisclosureIndicator
                    : (item.accessoryType == CPListItemAccessoryTypeCloud ? UITableViewCellAccessoryCheckmark
                                                                           : UITableViewCellAccessoryNone);
            }
            cell.userInteractionEnabled = item.isEnabled;
            cell.selectionStyle = item.isEnabled ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSArray<CPListSection *> *sections = _template.sections;
    if ((NSUInteger)indexPath.section >= sections.count) {
        return;
    }
    NSArray<id<CPListTemplateItem>> *rows = sections[(NSUInteger)indexPath.section].items;
    if ((NSUInteger)indexPath.row < rows.count && [rows[(NSUInteger)indexPath.row] isKindOfClass:[CPListItem class]]) {
        // The row's own handler, which is what a program gave the row.
        [(CPListItem *)rows[(NSUInteger)indexPath.row] charon_selected];
    }
}

@end

// ============================ the grid template ============================

@implementation CPGridTemplate {
    NSArray<CPGridButton *> *_gridButtons;
    NSString *_title;
    UICollectionViewController *_grid;
    CharonCarPlayBar *_charon_bar;
}

- (instancetype)initWithTitle:(NSString *)title gridButtons:(NSArray<CPGridButton *> *)gridButtons
{
    self = [super init];
    if (self) {
        _title = [title copy] ?: @"";
        _gridButtons = [gridButtons copy] ?: @[];
    }
    return self;
}

- (NSArray<CPGridButton *> *)gridButtons
{
    return _gridButtons;
}

- (void)updateGridButtons:(NSArray<CPGridButton *> *)gridButtons
{
    _gridButtons = [gridButtons copy] ?: @[];
    [_grid.collectionView reloadData];
}

- (void)updateTitle:(NSString *)title
{
    _title = [title copy] ?: @"";
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_gridButtons forKey:@"CPGridTemplateGridButtons"];
    [coder encodeObject:_title forKey:@"CPGridTemplateTitle"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        _gridButtons = [coder decodeObjectForKey:@"CPGridTemplateGridButtons"] ?: @[];
        _title = [coder decodeObjectForKey:@"CPGridTemplateTitle"] ?: @"";
    }
    return self;
}

- (UIViewController *)charon_viewControllerForInterfaceController:(CPInterfaceController *)controller
{
    if (_grid) {
        return _grid;
    }
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    // The header's own shape for a grid button's image, which the port draws at this size.
    layout.itemSize = CGSizeMake(180.0, 120.0);
    layout.minimumLineSpacing = 16.0;
    layout.minimumInteritemSpacing = 16.0;
    _grid = [[UICollectionViewController alloc] initWithCollectionViewLayout:layout];
    _grid.title = _title;
    _grid.collectionView.backgroundColor = [UIColor blackColor];
    _grid.collectionView.dataSource = (id)[CharonGridSource sourceForTemplate:self];
    _grid.collectionView.delegate = (id)[CharonGridSource sourceForTemplate:self];
    _charon_bar = [[CharonCarPlayBar alloc] initWithFrame:CGRectMake(0.0, 0.0, 176.0, 44.0)];
    _charon_bar.charon_buttons = self.barButtons;
    _charon_bar.backgroundColor = [UIColor clearColor];
    [_grid.view addSubview:_charon_bar];
    return _grid;
}

- (NSArray<CPBarButton *> *)barButtons
{
    return _charon_bar.charon_buttons ?: @[];
}

- (void)setBarButtons:(NSArray<CPBarButton *> *)barButtons
{
    if (!_charon_bar) {
        _charon_bar = [[CharonCarPlayBar alloc] initWithFrame:CGRectMake(0.0, 0.0, 176.0, 44.0)];
        _charon_bar.backgroundColor = [UIColor clearColor];
    }
    _charon_bar.charon_buttons = barButtons;
}

@end

@implementation CharonGridSource {
    __weak CPGridTemplate *_template;
}

+ (instancetype)sourceForTemplate:(CPGridTemplate *)template
{
    CharonGridSource *source = [[CharonGridSource alloc] init];
    source->_template = template;
    return source;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return (NSInteger)_template.gridButtons.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *const cellIdentifier = @"CharonCarPlayGridButton";
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:cellIdentifier
                                                                          forIndexPath:indexPath];
    // The release's own plate behind the button the button itself draws, so a grid button sits on an
    // iOS 6 surface rather than on nothing.
    cell.backgroundColor = [UIColor clearColor];
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context) {
        cell.contentView.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.92f];
    }
    for (UIView *view in cell.contentView.subviews) {
        [view removeFromSuperview];
    }
    NSArray<CPGridButton *> *buttons = _template.gridButtons;
    if ((NSUInteger)indexPath.item < buttons.count) {
        // The grid button, drawn by the button itself, because a CPGridButton is an NSObject and not
        // a view: the template asks it to draw into the cell it is in.
        CPGridButton *button = buttons[(NSUInteger)indexPath.item];
        [(CPGridButton *)button charon_drawInRect:cell.contentView.bounds];
    }
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSArray<CPGridButton *> *buttons = _template.gridButtons;
    if ((NSUInteger)indexPath.item < buttons.count) {
        // The grid button's own handler, which a program gave it.
        [(CPGridButton *)buttons[(NSUInteger)indexPath.item] charon_tap];
    }
}

@end

// ============================ the map template ============================

// The card the navigation alert is drawn in, a class of its own so that dismissing the alert can find it
// and take it off the map: the release's own MKMapView is the only thing it is ever drawn over. It
// carries no row and is not API - it is this port's own drawing, the same shape CharonCarPlayBar and
// CharonMapButtons below already are.
@interface CharonCarPlayAlertCard : UIView
@end

@implementation CharonCarPlayAlertCard
@end

@implementation CPMapTemplate {
    UIColor *_guidanceBackgroundColor;
    NSArray<CPMapButton *> *_mapButtons;
    BOOL _automaticallyHidesNavigationBar;
    BOOL _hidesButtonsWithNavigationBar;
    __weak id<CPMapTemplateDelegate> _mapDelegate;
    BOOL _panningInterfaceVisible;
    CPNavigationAlert *_currentNavigationAlert;
    CPImageSet *_mapImageSet;
    NSString *_title;
    MKMapView *_mapView;
    CharonCarPlayBar *_charon_bar;
    CharonMapButtons *_charon_map_buttons;
    // The session begun by -startNavigationSessionForTrip:, which the class's own file keeps because a
    // category cannot add storage. The method that makes one is in CarPlayNavigationSession12.m, the
    // same 12.0 object this class belongs to.
    id _navigationSession;
    // What CarPlayMapTemplate12.m and CarPlayMapTemplate14.m hold for this class, declared here for the
    // same reason: a category cannot add an ivar. Reached through the Charon-prefixed accessors at the
    // end of this @implementation and declared in CharonCarPlayTemplate.h, which is where this tree
    // keeps a seam two objects share. All of them are Charon's own, so none carries a member row.
    CPNavigationAlert *_charon_navigationAlert;  // the alert being shown, beside the readonly property
    NSArray *_charon_tripPreviews;               // the previews shown; the header's limit is 12
    CPTrip *_charon_selectedTrip;                // the selected one, for the 14.0 member
    NSMutableDictionary *_charon_estimates;      // CPTravelEstimates, per trip
    CPTimeRemainingColor _charon_timeRemainingColor;  // the header's own enum; 0 is its Default case
}

@synthesize guidanceBackgroundColor = _guidanceBackgroundColor;
@synthesize mapButtons = _mapButtons;
@synthesize automaticallyHidesNavigationBar = _automaticallyHidesNavigationBar;
@synthesize hidesButtonsWithNavigationBar = _hidesButtonsWithNavigationBar;
@synthesize mapDelegate = _mapDelegate;
@synthesize panningInterfaceVisible = _panningInterfaceVisible;
@synthesize currentNavigationAlert = _currentNavigationAlert;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _automaticallyHidesNavigationBar = YES;
        _panningInterfaceVisible = YES;
        _mapButtons = @[];
        _guidanceBackgroundColor = [UIColor colorWithWhite:0.0 alpha:0.6];
    }
    return self;
}

- (NSArray<CPBarButton *> *)barButtons
{
    return _charon_bar.charon_buttons ?: @[];
}

- (void)setBarButtons:(NSArray<CPBarButton *> *)barButtons
{
    if (!_charon_bar) {
        _charon_bar = [[CharonCarPlayBar alloc] initWithFrame:CGRectMake(0.0, 0.0, 176.0, 44.0)];
        _charon_bar.backgroundColor = [UIColor clearColor];
    }
    _charon_bar.charon_buttons = barButtons;
}

// The map: the release's own MKMapView, which is the only map this port has, with this port's own
// renderers on it. The map buttons are drawn over it, and the navigation alert is shown over it when
// the map template has one, which is what the header's own currentNavigationAlert is for.
- (UIViewController *)charon_viewControllerForInterfaceController:(CPInterfaceController *)controller
{
    if (_mapView) {
        return (UIViewController *)_mapView;
    }
    // The release's own map view, which is a UIViewController on this release, so it is the map
    // template's own view controller and not a view put inside one.
    _mapView = [[MKMapView alloc] initWithFrame:CGRectMake(0.0, 0.0, 1024.0, 600.0)];
    _mapView.mapType = MKMapTypeStandard;
    _charon_map_buttons = [[CharonMapButtons alloc] initWithFrame:CGRectMake(0.0, 460.0, 1024.0, 120.0)];
    _charon_map_buttons.charon_buttons = _mapButtons;
    _charon_map_buttons.backgroundColor = [UIColor clearColor];
    // The map buttons sit inside the map view's own insets, which is what the window's
    // mapButtonSafeAreaLayoutGuide is for on a release that has layout guides. UILayoutGuide is
    // iOS 9 and the release has none (measured: -mapButtonSafeAreaLayoutGuide is absent from the
    // armv7 cache of 6.1.3, and the gate named _OBJC_CLASS_$_UILayoutGuide as the one import the
    // device's iOS does not export), so the property is registered absent and the inset is this
    // port's own.
    _charon_map_buttons.frame = CGRectMake(0.0, 440.0, 1024.0, 140.0);
    [_mapView addSubview:_charon_map_buttons];
    _charon_bar = [[CharonCarPlayBar alloc] initWithFrame:CGRectMake(0.0, 0.0, 176.0, 44.0)];
    _charon_bar.charon_buttons = self.barButtons;
    _charon_bar.backgroundColor = [UIColor clearColor];
    [_mapView addSubview:_charon_bar];
    // A map template's own chrome is the bar at the top, which on this release is the glossy black
    // UIBarStyleBlack one, over the release's own MKMapView underneath it.
    UINavigationBar *bar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0.0, 0.0, 1024.0, 44.0)];
    bar.barStyle = UIBarStyleBlack;
    bar.translucent = YES;
    [_mapView addSubview:bar];
    return (UIViewController *)_mapView;
}

- (void)charon_showCurrentAlert
{
    // The alert, drawn over the map out of its own title and subtitle variants, and the map
    // template's own delegate told about the map button that was chosen. Charon's own, so no API.
    CPNavigationAlert *alert = _currentNavigationAlert;
    if (!alert || !_mapView) {
        return;
    }
    NSString *title = alert.titleVariants.firstObject ?: @"";
    NSString *subtitle = alert.subtitleVariants.firstObject ?: @"";
    // The card's geometry is this port's own and not a measurement: there is no car screen to measure
    // one on, and the same 420 x 96 is what every alert this port draws has been since the 12.0 object
    // was written. The 1024 x 600 map it is drawn over is the release's own MKMapView at the frame
    // above, so the card is a card over something real.
    CGSize size = CGSizeMake(420.0, 96.0);
    CharonCarPlayAlertCard *card = [[CharonCarPlayAlertCard alloc]
        initWithFrame:CGRectMake(20.0, 20.0, size.width, size.height)];
    card.backgroundColor = _guidanceBackgroundColor;
    card.layer.cornerRadius = 10.0;
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectInset(card.bounds, 12.0, 12.0)];
    label.text = subtitle.length > 0 ? [NSString stringWithFormat:@"%@\n%@", title, subtitle] : title;
    label.numberOfLines = 2;
    label.textColor = [UIColor whiteColor];
    [card addSubview:label];
    [_mapView addSubview:card];
}

// The map the guidance and the map buttons are drawn over, for the file that draws a session's
// estimates: it is the release's own MKMapView and nil until the template has been pushed, so
// guidance asked for before then is not drawn onto a view that does not exist. Charon's own.
- (UIView *)charon_mapView
{
    return _mapView;
}

// The accessors CarPlayMapTemplate12.m and CarPlayMapTemplate14.m reach this class's storage through,
// because a category cannot write an ivar. The members they serve are the SDK's own and are registered
// against their own rows; every name here is Charon's own, so it carries none.

// Presenting an alert, and dismissing one. A nil alert takes the card off the map rather than leaving
// the last one on screen, which is what "Dismiss the currently-visible navigation alert" asks for, and
// that is the whole reason the card is a class of its own: a dismissal has to be able to find it.
- (CPNavigationAlert *)charon_navigationAlert
{
    return _charon_navigationAlert;
}

- (void)charon_setNavigationAlert:(CPNavigationAlert *)alert
{
    _charon_navigationAlert = alert;
    if (alert == nil) {
        _currentNavigationAlert = nil;
        for (UIView *sub in [_mapView.subviews copy]) {
            if ([sub isKindOfClass:[CharonCarPlayAlertCard class]]) {
                [sub removeFromSuperview];
            }
        }
        return;
    }
    _currentNavigationAlert = alert;
    [self charon_showCurrentAlert];
}

// The view the map buttons are drawn in, which is the class's own CharonMapButtons - so the panning
// interface the 12.0 object drives and the buttons a caller set are one set of buttons and not two.
- (UIView *)charon_mapButtons
{
    return _charon_map_buttons;
}

- (BOOL)charon_panningInterfaceVisible
{
    return _panningInterfaceVisible;
}

- (void)charon_setPanningInterfaceVisible:(BOOL)visible
{
    _panningInterfaceVisible = visible;
}

- (NSArray *)charon_tripPreviews
{
    return _charon_tripPreviews;
}

// Copied, because a caller that mutates the array it passed should not change what the template shows;
// the selected trip is not copied because a trip is the caller's own object either way.
- (void)charon_setTripPreviews:(NSArray *)previews selectedTrip:(CPTrip *)selectedTrip
{
    _charon_tripPreviews = [previews copy];
    _charon_selectedTrip = selectedTrip;
}

- (CPTrip *)charon_selectedTrip
{
    return _charon_selectedTrip;
}

- (void)charon_setEstimates:(CPTravelEstimates *)estimates forTrip:(CPTrip *)trip
{
    if (_charon_estimates == nil) {
        _charon_estimates = [NSMutableDictionary dictionary];
    }
    if (trip == nil) {
        return;
    }
    _charon_estimates[trip] = estimates;
}

- (CPTravelEstimates *)charon_estimatesForTrip:(CPTrip *)trip
{
    return trip == nil ? nil : _charon_estimates[trip];
}

// The header's own enumeration, held as the number it is: CPMapTemplate.h:36-41 gives it four cases -
// Default = 0, Green, Orange, Red - and the drawing below names them by those cases.
- (void)charon_setTimeRemainingColor:(CPTimeRemainingColor)color
{
    _charon_timeRemainingColor = color;
}

- (CPTimeRemainingColor)charon_timeRemainingColor
{
    return _charon_timeRemainingColor;
}

// The session begun by -startNavigationSessionForTrip:, and how the file that makes one hands it
// over. Charon's own, so neither carries API.
- (id)charon_navigationSession
{
    return _navigationSession;
}

- (void)charon_setNavigationSession:(id)session
{
    _navigationSession = session;
}

@end

@implementation CharonMapButtons {
    NSArray<CPMapButton *> *_buttons;
}

@synthesize charon_buttons = _buttons;

- (void)setCharon_buttons:(NSArray<CPMapButton *> *)buttons
{
    _buttons = [buttons copy] ?: @[];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    // The buttons the template gave, each drawn by the button itself, laid out left to right, and
    // skipped when the button says it is hidden, which is what CPMapButton's own hidden is for.
    CGFloat size = 88.0;
    CGFloat at = 0.0;
    for (CPMapButton *button in _buttons) {
        if (at + size > CGRectGetWidth(rect)) {
            break;
        }
        [(CPMapButton *)button charon_drawInRect:CGRectMake(at, 0.0, size, size)];
        at += size + 12.0;
    }
}

- (void)charon_tappedAtPoint:(UITapGestureRecognizer *)gesture
{
    CGPoint point = [gesture locationInView:self];
    CGFloat size = 88.0;
    NSUInteger index = point.x >= 0.0 ? (NSUInteger)(point.x / (size + 12.0)) : 0U;
    if (index >= _buttons.count) {
        return;
    }
    CPMapButton *button = _buttons[index];
    if (button.isHidden || !button.isEnabled) {
        return;
    }
    // The button's own handler, which a program gave the button, called by the button.
    [(CPMapButton *)button charon_tap];
}

@end

// ============================ the interface controller ============================

@implementation CPInterfaceController {
    __weak id<CPInterfaceControllerDelegate> _delegate;
    BOOL _prefersDarkUserInterfaceStyle;
    CPTemplate *_rootTemplate;
    NSMutableArray<CPTemplate *> *_templates;
    NSMutableArray<CPTemplate *> *_stack;
    CPWindow *_contentWindow;
}

@synthesize delegate = _delegate;
@synthesize prefersDarkUserInterfaceStyle = _prefersDarkUserInterfaceStyle;

// The content window this controller draws its templates into. Apple's own is the window a car
// draws into; on this port it is a window the application owns, which is what a head unit is here.
- (CPWindow *)contentWindow
{
    if (!_contentWindow) {
        _contentWindow = [[CPWindow alloc] initWithFrame:CGRectMake(0.0, 0.0, 1024.0, 600.0)];
    }
    return _contentWindow;
}

- (CPTemplate *)rootTemplate
{
    return _rootTemplate;
}

- (NSArray<CPTemplate *> *)templates
{
    return [_templates copy] ?: @[];
}

- (CPTemplate *)topTemplate
{
    return _stack.lastObject;
}

- (CPTemplate *)presentedTemplate
{
    return _stack.lastObject;
}

// The header's own car trait collection. There is no car, so the car is this device, and the answer
// is the screen's own trait collection -- a real object, this device's own, and not a stored value.
- (UITraitCollection *)carTraitCollection
{
    return [UIScreen mainScreen].traitCollection;
}

- (void)setRootTemplate:(CPTemplate *)rootTemplate animated:(BOOL)animated completion:(void (^)(BOOL finished, NSError *))completion
{
    _rootTemplate = rootTemplate;
    [_stack removeAllObjects];
    if (rootTemplate) {
        [_stack addObject:rootTemplate];
    }
    [self charon_showTop];
    [self templateWillAppear:rootTemplate animated:animated];
    [self templateDidAppear:rootTemplate animated:animated];
    if (completion) {
        completion(YES, nil);
    }
}

- (void)pushTemplate:(CPTemplate *)templateToPush animated:(BOOL)animated completion:(void (^)(BOOL finished, NSError *))completion
{
    if (!templateToPush) {
        if (completion) {
            completion(NO, nil);
        }
        return;
    }
    CPTemplate *below = self.topTemplate;
    if (below) {
        [self templateWillDisappear:below animated:animated];
    }
    [_stack addObject:templateToPush];
    [CharonCarPlayInterface current].controller = self;
    [self charon_showTop];
    [self templateWillAppear:templateToPush animated:animated];
    [self templateDidAppear:templateToPush animated:animated];
    if (completion) {
        completion(YES, nil);
    }
}

- (void)popTemplateAnimated:(BOOL)animated completion:(void (^)(BOOL finished, NSError *))completion
{
    CPTemplate *going = self.topTemplate;
    if (_stack.count <= 1 || !going) {
        if (completion) {
            completion(YES, nil);
        }
        return;
    }
    [self templateWillDisappear:going animated:animated];
    [_stack removeLastObject];
    [self charon_showTop];
    [self templateDidDisappear:going animated:animated];
    CPTemplate *now = self.topTemplate;
    if (now) {
        [self templateDidAppear:now animated:animated];
    }
    if (completion) {
        completion(YES, nil);
    }
}

- (void)popToRootTemplateAnimated:(BOOL)animated completion:(void (^)(BOOL finished, NSError *))completion
{
    while (_stack.count > 1) {
        [_stack removeLastObject];
    }
    [self charon_showTop];
    CPTemplate *now = self.topTemplate;
    if (now) {
        [self templateDidAppear:now animated:animated];
    }
    if (completion) {
        completion(YES, nil);
    }
}

- (void)popToTemplate:(CPTemplate *)targetTemplate animated:(BOOL)animated completion:(void (^)(BOOL finished, NSError *))completion
{
    NSUInteger index = [_stack indexOfObject:targetTemplate];
    if (index == NSNotFound) {
        if (completion) {
            completion(NO, nil);
        }
        return;
    }
    while (_stack.count > index + 1) {
        [_stack removeLastObject];
    }
    [self charon_showTop];
    if (completion) {
        completion(YES, nil);
    }
}

- (void)presentTemplate:(CPTemplate *)templateToPresent animated:(BOOL)animated completion:(void (^)(BOOL finished, NSError *))completion
{
    [self pushTemplate:templateToPresent animated:animated completion:completion];
}

- (void)dismissTemplateAnimated:(BOOL)animated completion:(void (^)(BOOL finished, NSError *))completion
{
    [self popTemplateAnimated:animated completion:completion];
}

// The header's own deprecated spellings, which are the same operations without the completion.
- (void)setRootTemplate:(CPTemplate *)rootTemplate animated:(BOOL)animated
{
    [self setRootTemplate:rootTemplate animated:animated completion:nil];
}

- (void)pushTemplate:(CPTemplate *)templateToPush animated:(BOOL)animated
{
    [self pushTemplate:templateToPush animated:animated completion:nil];
}

- (void)popTemplateAnimated:(BOOL)animated
{
    [self popTemplateAnimated:animated completion:nil];
}

- (void)popToRootTemplateAnimated:(BOOL)animated
{
    [self popToRootTemplateAnimated:animated completion:nil];
}

- (void)popToTemplate:(CPTemplate *)targetTemplate animated:(BOOL)animated
{
    [self popToTemplate:targetTemplate animated:animated completion:nil];
}

- (void)presentTemplate:(CPTemplate *)templateToPresent animated:(BOOL)animated
{
    [self presentTemplate:templateToPresent animated:animated completion:nil];
}

- (void)dismissTemplateAnimated:(BOOL)animated
{
    [self dismissTemplateAnimated:animated completion:nil];
}

// The delegate's four lifecycle messages, sent for real and in the header's own order, and the
// interface content window the templates are drawn into. Charon's own, so it carries no API.
- (void)charon_showTop
{
    CPWindow *window = [self contentWindow];
    for (UIView *view in window.subviews) {
        [view removeFromSuperview];
    }
    CPTemplate *top = self.topTemplate;
    if (!top) {
        return;
    }
    UIViewController *controller = [top charon_viewControllerForInterfaceController:self];
    if (controller) {
        window.rootViewController = controller;
        [window makeKeyAndVisible];
    }
}

- (void)templateWillAppear:(CPTemplate *)aTemplate animated:(BOOL)animated
{
    if ([_delegate respondsToSelector:@selector(templateWillAppear:animated:)]) {
        void (*send)(id, SEL, CPTemplate *, BOOL) = (void (*)(id, SEL, CPTemplate *, BOOL))objc_msgSend;
        send(_delegate, @selector(templateWillAppear:animated:), aTemplate, animated);
    }
}

- (void)templateDidAppear:(CPTemplate *)aTemplate animated:(BOOL)animated
{
    if ([_delegate respondsToSelector:@selector(templateDidAppear:animated:)]) {
        void (*send)(id, SEL, CPTemplate *, BOOL) = (void (*)(id, SEL, CPTemplate *, BOOL))objc_msgSend;
        send(_delegate, @selector(templateDidAppear:animated:), aTemplate, animated);
    }
}

- (void)templateWillDisappear:(CPTemplate *)aTemplate animated:(BOOL)animated
{
    if ([_delegate respondsToSelector:@selector(templateWillDisappear:animated:)]) {
        void (*send)(id, SEL, CPTemplate *, BOOL) = (void (*)(id, SEL, CPTemplate *, BOOL))objc_msgSend;
        send(_delegate, @selector(templateWillDisappear:animated:), aTemplate, animated);
    }
}

- (void)templateDidDisappear:(CPTemplate *)aTemplate animated:(BOOL)animated
{
    if ([_delegate respondsToSelector:@selector(templateDidDisappear:animated:)]) {
        void (*send)(id, SEL, CPTemplate *, BOOL) = (void (*)(id, SEL, CPTemplate *, BOOL))objc_msgSend;
        send(_delegate, @selector(templateDidDisappear:animated:), aTemplate, animated);
    }
}

- (void)tabBarTemplate:(id)tabBarTemplate didSelectItemAtIndex:(NSUInteger)index
{
    // A tab chosen in the tab bar template, which is the root template here: the template at that
    // index becomes the one on top, which is what a tab means.
    NSArray<CPTemplate *> *templates = self.templates;
    if (index < templates.count) {
        [self pushTemplate:templates[index] animated:YES completion:nil];
    }
}

@end
