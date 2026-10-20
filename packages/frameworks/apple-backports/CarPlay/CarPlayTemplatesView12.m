#import <CarPlay/CarPlay.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "RevenantCarPlayTemplate.h"

@interface CPBarButton (RevenantDrawing)
- (void)revenant_drawInRect:(CGRect)rect alpha:(CGFloat)alpha;
- (void)revenant_tap;
@end

@interface CPGridButton (RevenantDrawing)
- (void)revenant_drawInRect:(CGRect)rect;
- (void)revenant_tap;
@end

@interface CPMapButton (RevenantDrawing)
- (void)revenant_drawInRect:(CGRect)rect;
- (void)revenant_tap;
@end

@interface CPTemplate (RevenantDrawing)
- (UIViewController *)revenant_viewControllerForInterfaceController:(CPInterfaceController *)controller;
@end

@interface RevenantListItemHandler : NSObject
- (void)revenant_call:(id)item completion:(id)completion;
@end

@interface RevenantGridSource : NSObject <UICollectionViewDataSource, UICollectionViewDelegate>
+ (instancetype)sourceForTemplate:(CPGridTemplate *)template;
@end

@interface RevenantCarPlayInterface : NSObject
+ (instancetype)current;
@property (nonatomic, weak) CPInterfaceController *controller;
@end

@interface RevenantMapButtons : UIView
@property (nonatomic, copy) NSArray<CPMapButton *> *revenant_buttons;
@end

@interface CPInterfaceController (RevenantWindow)
@property (nonatomic, readonly, strong) CPWindow *contentWindow;
@end

@interface RevenantListRowState : NSObject
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

@implementation RevenantListRowState
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

@implementation CPListItem (RevenantRow)

- (RevenantListRowState *)revenant_state
{
    static const void *key = &key;
    RevenantListRowState *state = objc_getAssociatedObject(self, key);
    if (!state) {
        state = [[RevenantListRowState alloc] init];
        state.enabled = YES;
        state.showsDisclosureIndicator = YES;
        objc_setAssociatedObject(self, key, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return state;
}

- (RevenantListRowState *)revenant_stateInitWithText:(NSString *)text
                               detailText:(NSString *)detailText
                                    image:(UIImage *)image
                           accessoryImage:(UIImage *)accessoryImage
                            accessoryType:(NSInteger)accessoryType
{
    RevenantListRowState *state = [[RevenantListRowState alloc] init];
    state.text = text ?: @"";
    state.detailText = detailText ?: @"";
    state.image = image;
    state.accessoryImage = accessoryImage;
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
    self = ((id (*)(id, SEL))objc_msgSend)([CPListItem class], @selector(alloc));
    self = ((id (*)(id, SEL, id))objc_msgSend)(self, @selector(init), @"");
    [self revenant_setState:[self revenant_stateInitWithText:text detailText:detailText image:image
                                     accessoryImage:accessoryImage accessoryType:accessoryType]];
    return self;
}

- (void)revenant_setState:(RevenantListRowState *)state
{
    static const void *key = &key;
    objc_setAssociatedObject(self, key, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)text { return [self revenant_state].text; }
- (void)setText:(NSString *)text { [self revenant_state].text = text ?: @""; }
- (NSString *)detailText { return [self revenant_state].detailText; }
- (void)setDetailText:(NSString *)detailText { [self revenant_state].detailText = detailText ?: @""; }
- (UIImage *)image { return [self revenant_state].image; }
- (void)setImage:(UIImage *)image { [self revenant_state].image = image; }
- (UIImage *)accessoryImage { return [self revenant_state].accessoryImage; }
- (void)setAccessoryImage:(UIImage *)image
{
    [self revenant_state].accessoryImage = image;
    if (image) {
        [self revenant_state].accessoryType = 0;
    }
}
- (NSInteger)accessoryType { return [self revenant_state].accessoryType; }
- (void)setAccessoryType:(NSInteger)accessoryType { [self revenant_state].accessoryType = accessoryType; }
- (BOOL)showsDisclosureIndicator { return [self revenant_state].showsDisclosureIndicator; }
- (void)setShowsDisclosureIndicator:(BOOL)shows { [self revenant_state].showsDisclosureIndicator = shows; }
- (id)userInfo { return [self revenant_state].userInfo; }
- (void)setUserInfo:(id)userInfo { [self revenant_state].userInfo = userInfo; }
- (id)handler { return [self revenant_state].handler; }
- (void)setHandler:(id)handler { [self revenant_state].handler = handler; }
- (BOOL)isExplicitContent { return [self revenant_state].explicitContent; }
- (void)setExplicitContent:(BOOL)explicitContent { [self revenant_state].explicitContent = explicitContent; }
- (double)playbackProgress { return [self revenant_state].playbackProgress; }
- (void)setPlaybackProgress:(double)progress { [self revenant_state].playbackProgress = progress; }
- (BOOL)isPlaying { return [self revenant_state].playing; }
- (void)setPlaying:(BOOL)playing { [self revenant_state].playing = playing; }
- (NSInteger)playingIndicatorLocation { return [self revenant_state].playingIndicatorLocation; }
- (void)setPlayingIndicatorLocation:(NSInteger)location { [self revenant_state].playingIndicatorLocation = location; }
- (BOOL)isEnabled { return [self revenant_state].enabled; }
- (void)setEnabled:(BOOL)enabled { [self revenant_state].enabled = enabled; }
- (BOOL)isShowingExplicitLabel { return [self revenant_state].showsExplicitLabel; }
- (void)setShowsExplicitLabel:(BOOL)shows { [self revenant_state].showsExplicitLabel = shows; }

+ (CGSize)maximumImageSize
{
    return CGSizeMake(60.0, 60.0);
}

- (void)revenant_selected
{
    id handler = [self revenant_state].handler;
    void (*call)(id, SEL, id, id) = (void (*)(id, SEL, id, id))objc_msgSend;
    SEL selector = NSSelectorFromString(@"revenant_call");
    if (handler && [handler respondsToSelector:selector]) {
        call(handler, selector, self, ^{
        });
    }
}

@end

@implementation RevenantListItemHandler
- (void)revenant_call:(id)item completion:(id)completion { }
@end

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

- (void)revenant_setHeaderSubtitle:(NSString *)headerSubtitle { _headerSubtitle = [headerSubtitle copy]; }
- (void)revenant_setHeaderImage:(UIImage *)headerImage { _headerImage = headerImage; }
- (void)revenant_setHeaderButton:(CPButton *)headerButton { _headerButton = headerButton; }

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

@interface RevenantCarPlayBar : UIView
@property (nonatomic, copy) NSArray<CPBarButton *> *revenant_buttons;
@end

@implementation RevenantCarPlayBar {
    NSArray<CPBarButton *> *_buttons;
}

@synthesize revenant_buttons = _buttons;

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                action:@selector(revenant_tappedAtPoint:)];
        [self addGestureRecognizer:tap];
    }
    return self;
}

- (void)setRevenant_buttons:(NSArray<CPBarButton *> *)buttons
{
    _buttons = [buttons copy] ?: @[];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    CGFloat width = MIN(88.0, CGRectGetWidth(rect) / (CGFloat)MAX((NSUInteger)_buttons.count, 1U));
    CGFloat at = 0.0;
    for (CPBarButton *button in _buttons) {
        if (at >= 2.0 * width) {
            break;
        }
        if (button.isEnabled) {
            [(CPBarButton *)button revenant_drawInRect:CGRectMake(at, 0.0, width, CGRectGetHeight(rect)) alpha:1.0];
        } else {
            [(CPBarButton *)button revenant_drawInRect:CGRectMake(at, 0.0, width, CGRectGetHeight(rect)) alpha:0.4];
        }
        at += width;
    }
}

- (void)revenant_tappedAtPoint:(UITapGestureRecognizer *)gesture
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
    [(CPBarButton *)button revenant_tap];
}

@end

@interface RevenantListSource : NSObject <UITableViewDataSource, UITableViewDelegate>
+ (instancetype)sourceForTemplate:(CPListTemplate *)template;
@end

static UINavigationBar *_listNavigationBar;

@interface CPListTemplate (RevenantRows)
- (NSArray<CPListItem *> *)revenant_items;
@property (nonatomic, copy) NSString *title;
@end

@implementation CPListTemplate {
    NSArray<CPListSection *> *_sections;
    __weak id<CPListTemplateDelegate> _delegate;
    NSArray<NSString *> *_emptyViewTitleVariants;
    NSArray<NSString *> *_emptyViewSubtitleVariants;
    CPAssistantCellConfiguration *_assistantCellConfiguration;
    UITableViewController *_list;
    RevenantCarPlayBar *_revenant_bar;
    BOOL _revenant_showsSpinnerWhileEmpty;
    NSArray<CPGridButton *> *_revenant_headerGridButtons;
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
    return [self revenant_items].count;
}

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

- (NSArray<CPListItem *> *)revenant_items
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

- (UIViewController *)revenant_viewControllerForInterfaceController:(CPInterfaceController *)controller
{
    if (_list) {
        return _list;
    }
    _list = [[UITableViewController alloc] initWithStyle:UITableViewStylePlain];
    _list.title = self.title;
    _list.navigationItem.title = self.title;
    _list.view.backgroundColor = [UIColor blackColor];
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
                                                           action:@selector(revenant_tap)]];
    }
    barItems = [NSMutableArray array];
    for (CPBarButton *button in self.barButtons) {
        [barItems addObject:[[UIBarButtonItem alloc] initWithTitle:button.title
                                                            style:UIBarButtonItemStylePlain
                                                           target:button
                                                           action:@selector(revenant_tap)]];
    }
    _listNavigationBar.topItem.leftBarButtonItems = barItems;
    _list.tableView.dataSource = (id)[RevenantListSource sourceForTemplate:self];
    _list.tableView.delegate = (id)[RevenantListSource sourceForTemplate:self];
    if (_sections.count == 0) {
        if (_revenant_showsSpinnerWhileEmpty) {
            UIActivityIndicatorView *spinner =
                    [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
            spinner.center = CGPointMake(CGRectGetMidX(_list.view.bounds), CGRectGetMidY(_list.view.bounds));
            spinner.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [spinner startAnimating];
            _list.tableView.backgroundView = spinner;
        } else {
            NSString *empty = _emptyViewTitleVariants.firstObject ?: _emptyViewSubtitleVariants.firstObject;
            UILabel *label = [[UILabel alloc] initWithFrame:_list.view.bounds];
            label.text = empty;
            label.textAlignment = NSTextAlignmentCenter;
            label.textColor = [UIColor colorWithWhite:1.0 alpha:0.6];
            label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            _list.tableView.backgroundView = label;
        }
    }
    _revenant_bar = [[RevenantCarPlayBar alloc] initWithFrame:CGRectMake(0.0, 0.0, 176.0, 44.0)];
    _revenant_bar.revenant_buttons = self.barButtons;
    _revenant_bar.backgroundColor = [UIColor clearColor];
    [_list.view addSubview:_revenant_bar];
    return _list;
}

- (NSArray<CPBarButton *> *)barButtons
{
    return _revenant_bar.revenant_buttons ?: @[];
}

- (void)setBarButtons:(NSArray<CPBarButton *> *)barButtons
{
    if (!_revenant_bar) {
        _revenant_bar = [[RevenantCarPlayBar alloc] initWithFrame:CGRectMake(0.0, 0.0, 176.0, 44.0)];
        _revenant_bar.backgroundColor = [UIColor clearColor];
    }
    _revenant_bar.revenant_buttons = barButtons;
}

- (BOOL)revenant_showsSpinnerWhileEmpty { return _revenant_showsSpinnerWhileEmpty; }

- (void)revenant_setShowsSpinnerWhileEmpty:(BOOL)showsSpinnerWhileEmpty
{
    _revenant_showsSpinnerWhileEmpty = showsSpinnerWhileEmpty;
}

- (NSArray<CPGridButton *> *)revenant_headerGridButtons { return _revenant_headerGridButtons; }

- (void)revenant_setHeaderGridButtons:(NSArray<CPGridButton *> *)headerGridButtons
{
    _revenant_headerGridButtons = [headerGridButtons copy];
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

@implementation RevenantListSource {
    __weak CPListTemplate *_template;
}

+ (instancetype)sourceForTemplate:(CPListTemplate *)template
{
    RevenantListSource *source = [[RevenantListSource alloc] init];
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
    static NSString *const cellIdentifier = @"RevenantCarPlayListRow";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:cellIdentifier];
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
        [(CPListItem *)rows[(NSUInteger)indexPath.row] revenant_selected];
    }
}

@end

@implementation CPGridTemplate {
    NSArray<CPGridButton *> *_gridButtons;
    NSString *_title;
    UICollectionViewController *_grid;
    RevenantCarPlayBar *_revenant_bar;
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

- (UIViewController *)revenant_viewControllerForInterfaceController:(CPInterfaceController *)controller
{
    if (_grid) {
        return _grid;
    }
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.itemSize = CGSizeMake(180.0, 120.0);
    layout.minimumLineSpacing = 16.0;
    layout.minimumInteritemSpacing = 16.0;
    _grid = [[UICollectionViewController alloc] initWithCollectionViewLayout:layout];
    _grid.title = _title;
    _grid.collectionView.backgroundColor = [UIColor blackColor];
    _grid.collectionView.dataSource = (id)[RevenantGridSource sourceForTemplate:self];
    _grid.collectionView.delegate = (id)[RevenantGridSource sourceForTemplate:self];
    _revenant_bar = [[RevenantCarPlayBar alloc] initWithFrame:CGRectMake(0.0, 0.0, 176.0, 44.0)];
    _revenant_bar.revenant_buttons = self.barButtons;
    _revenant_bar.backgroundColor = [UIColor clearColor];
    [_grid.view addSubview:_revenant_bar];
    return _grid;
}

- (NSArray<CPBarButton *> *)barButtons
{
    return _revenant_bar.revenant_buttons ?: @[];
}

- (void)setBarButtons:(NSArray<CPBarButton *> *)barButtons
{
    if (!_revenant_bar) {
        _revenant_bar = [[RevenantCarPlayBar alloc] initWithFrame:CGRectMake(0.0, 0.0, 176.0, 44.0)];
        _revenant_bar.backgroundColor = [UIColor clearColor];
    }
    _revenant_bar.revenant_buttons = barButtons;
}

@end

@implementation RevenantGridSource {
    __weak CPGridTemplate *_template;
}

+ (instancetype)sourceForTemplate:(CPGridTemplate *)template
{
    RevenantGridSource *source = [[RevenantGridSource alloc] init];
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
    static NSString *const cellIdentifier = @"RevenantCarPlayGridButton";
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:cellIdentifier
                                                                          forIndexPath:indexPath];
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
        CPGridButton *button = buttons[(NSUInteger)indexPath.item];
        [(CPGridButton *)button revenant_drawInRect:cell.contentView.bounds];
    }
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSArray<CPGridButton *> *buttons = _template.gridButtons;
    if ((NSUInteger)indexPath.item < buttons.count) {
        [(CPGridButton *)buttons[(NSUInteger)indexPath.item] revenant_tap];
    }
}

@end

@interface RevenantCarPlayAlertCard : UIView
@end

@implementation RevenantCarPlayAlertCard
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
    RevenantCarPlayBar *_revenant_bar;
    RevenantMapButtons *_revenant_map_buttons;
    id _navigationSession;
    CPNavigationAlert *_revenant_navigationAlert;
    NSArray *_revenant_tripPreviews;
    CPTrip *_revenant_selectedTrip;
    NSMutableDictionary *_revenant_estimates;
    CPTimeRemainingColor _revenant_timeRemainingColor;
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
    return _revenant_bar.revenant_buttons ?: @[];
}

- (void)setBarButtons:(NSArray<CPBarButton *> *)barButtons
{
    if (!_revenant_bar) {
        _revenant_bar = [[RevenantCarPlayBar alloc] initWithFrame:CGRectMake(0.0, 0.0, 176.0, 44.0)];
        _revenant_bar.backgroundColor = [UIColor clearColor];
    }
    _revenant_bar.revenant_buttons = barButtons;
}

- (UIViewController *)revenant_viewControllerForInterfaceController:(CPInterfaceController *)controller
{
    if (_mapView) {
        return (UIViewController *)_mapView;
    }
    _mapView = [[MKMapView alloc] initWithFrame:CGRectMake(0.0, 0.0, 1024.0, 600.0)];
    _mapView.mapType = MKMapTypeStandard;
    _revenant_map_buttons = [[RevenantMapButtons alloc] initWithFrame:CGRectMake(0.0, 460.0, 1024.0, 120.0)];
    _revenant_map_buttons.revenant_buttons = _mapButtons;
    _revenant_map_buttons.backgroundColor = [UIColor clearColor];
    _revenant_map_buttons.frame = CGRectMake(0.0, 440.0, 1024.0, 140.0);
    [_mapView addSubview:_revenant_map_buttons];
    _revenant_bar = [[RevenantCarPlayBar alloc] initWithFrame:CGRectMake(0.0, 0.0, 176.0, 44.0)];
    _revenant_bar.revenant_buttons = self.barButtons;
    _revenant_bar.backgroundColor = [UIColor clearColor];
    [_mapView addSubview:_revenant_bar];
    UINavigationBar *bar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0.0, 0.0, 1024.0, 44.0)];
    bar.barStyle = UIBarStyleBlack;
    bar.translucent = YES;
    [_mapView addSubview:bar];
    return (UIViewController *)_mapView;
}

- (void)revenant_showCurrentAlert
{
    CPNavigationAlert *alert = _currentNavigationAlert;
    if (!alert || !_mapView) {
        return;
    }
    NSString *title = alert.titleVariants.firstObject ?: @"";
    NSString *subtitle = alert.subtitleVariants.firstObject ?: @"";
    CGSize size = CGSizeMake(420.0, 96.0);
    RevenantCarPlayAlertCard *card = [[RevenantCarPlayAlertCard alloc]
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

- (UIView *)revenant_mapView
{
    return _mapView;
}

- (CPNavigationAlert *)revenant_navigationAlert
{
    return _revenant_navigationAlert;
}

- (void)revenant_setNavigationAlert:(CPNavigationAlert *)alert
{
    _revenant_navigationAlert = alert;
    if (alert == nil) {
        _currentNavigationAlert = nil;
        for (UIView *sub in [_mapView.subviews copy]) {
            if ([sub isKindOfClass:[RevenantCarPlayAlertCard class]]) {
                [sub removeFromSuperview];
            }
        }
        return;
    }
    _currentNavigationAlert = alert;
    [self revenant_showCurrentAlert];
}

- (UIView *)revenant_mapButtons
{
    return _revenant_map_buttons;
}

- (BOOL)revenant_panningInterfaceVisible
{
    return _panningInterfaceVisible;
}

- (void)revenant_setPanningInterfaceVisible:(BOOL)visible
{
    _panningInterfaceVisible = visible;
}

- (NSArray *)revenant_tripPreviews
{
    return _revenant_tripPreviews;
}

- (void)revenant_setTripPreviews:(NSArray *)previews selectedTrip:(CPTrip *)selectedTrip
{
    _revenant_tripPreviews = [previews copy];
    _revenant_selectedTrip = selectedTrip;
}

- (CPTrip *)revenant_selectedTrip
{
    return _revenant_selectedTrip;
}

- (void)revenant_setEstimates:(CPTravelEstimates *)estimates forTrip:(CPTrip *)trip
{
    if (_revenant_estimates == nil) {
        _revenant_estimates = [NSMutableDictionary dictionary];
    }
    if (trip == nil) {
        return;
    }
    _revenant_estimates[trip] = estimates;
}

- (CPTravelEstimates *)revenant_estimatesForTrip:(CPTrip *)trip
{
    return trip == nil ? nil : _revenant_estimates[trip];
}

- (void)revenant_setTimeRemainingColor:(CPTimeRemainingColor)color
{
    _revenant_timeRemainingColor = color;
}

- (CPTimeRemainingColor)revenant_timeRemainingColor
{
    return _revenant_timeRemainingColor;
}

- (id)revenant_navigationSession
{
    return _navigationSession;
}

- (void)revenant_setNavigationSession:(id)session
{
    _navigationSession = session;
}

@end

@implementation RevenantMapButtons {
    NSArray<CPMapButton *> *_buttons;
}

@synthesize revenant_buttons = _buttons;

- (void)setRevenant_buttons:(NSArray<CPMapButton *> *)buttons
{
    _buttons = [buttons copy] ?: @[];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    CGFloat size = 88.0;
    CGFloat at = 0.0;
    for (CPMapButton *button in _buttons) {
        if (at + size > CGRectGetWidth(rect)) {
            break;
        }
        [(CPMapButton *)button revenant_drawInRect:CGRectMake(at, 0.0, size, size)];
        at += size + 12.0;
    }
}

- (void)revenant_tappedAtPoint:(UITapGestureRecognizer *)gesture
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
    [(CPMapButton *)button revenant_tap];
}

@end

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
    [self revenant_showTop];
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
    [RevenantCarPlayInterface current].controller = self;
    [self revenant_showTop];
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
    [self revenant_showTop];
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
    [self revenant_showTop];
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
    [self revenant_showTop];
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

- (void)revenant_showTop
{
    CPWindow *window = [self contentWindow];
    for (UIView *view in window.subviews) {
        [view removeFromSuperview];
    }
    CPTemplate *top = self.topTemplate;
    if (!top) {
        return;
    }
    UIViewController *controller = [top revenant_viewControllerForInterfaceController:self];
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
    NSArray<CPTemplate *> *templates = self.templates;
    if (index < templates.count) {
        [self pushTemplate:templates[index] animated:YES completion:nil];
    }
}

@end
