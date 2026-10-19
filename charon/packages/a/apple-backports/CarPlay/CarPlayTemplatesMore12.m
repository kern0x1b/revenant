// The CarPlay templates of iOS 12, in the shapes the SDK declares: the action sheet, the alert, the
// image set, the search template, the trip and its route choices, and the trip preview's text.
//
// Like the rest of CarPlay's drawing half, none of these needs a car: an action sheet is a card with
// its own actions, an alert is a card with a title and actions, a search template is a search field
// over a list, and a trip is a pair of map items with the routes between them. The trip preview is
// driven by the interface controller, which is a view controller, not a car.
#import <CarPlay/CarPlay.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>

// The interface controller this port is currently pushing through, which a template that has to
// dismiss itself asks for. The interface controller records itself here when a template is pushed
// and forgets when it is popped, so the answer is the one that presented the template. Charon's own,
// so it carries no API.
@interface CharonCarPlayInterface : NSObject
+ (instancetype)current;
@property (nonatomic, weak) CPInterfaceController *controller;
@end

@implementation CharonCarPlayInterface

@synthesize controller = _controller;

+ (instancetype)current
{
    static CharonCarPlayInterface *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[CharonCarPlayInterface alloc] init];
    });
    return shared;
}

@end

// The card every one of these draws itself in, and the two buttons a card's own actions become. It is
// the same card the map template draws its guidance in, and it is Charon's own: every member prefixed,
// so none of it is API the package carries.
@interface CharonCarPlayCard : UIView
- (void)charon_showTitle:(NSString *)title
                 message:(NSString *)message
                  actions:(NSArray<CPAlertAction *> *)actions;
@end

@implementation CharonCarPlayCard {
    NSArray<CPAlertAction *> *_charon_actions;
}

// The card's own buttons are real UIButtons with a real target, so a tap on one calls that action's
// own handler -- which is the whole of what an action sheet and an alert are. The grid template's
// -collectionView:didSelectItemAtIndexPath: is the same mechanism with a different view.
- (void)charon_buttonTapped:(UIButton *)button
{
    NSInteger tag = button.tag;
    if (tag < 0 || (NSUInteger)tag >= _charon_actions.count) {
        return;
    }
    CPAlertAction *action = _charon_actions[(NSUInteger)tag];
    // The action's own handler, which is what a program gave the action, called with the action.
    if (action.handler) {
        action.handler(action);
    }
}

- (void)charon_showTitle:(NSString *)title message:(NSString *)message actions:(NSArray<CPAlertAction *> *)actions
{
    _charon_actions = [actions copy] ?: @[];
    for (UIView *view in self.subviews) {
        [view removeFromSuperview];
    }
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectInset(self.bounds, 16.0, 16.0)];
    label.text = message.length > 0 ? [NSString stringWithFormat:@"%@\n%@", title ?: @"", message] : (title ?: @"");
    label.numberOfLines = 3;
    label.textColor = [UIColor whiteColor];
    [self addSubview:label];
    // The card's own actions, as the buttons they are: the action's own handler called when its own
    // button is tapped, which is what an action sheet is.
    CGFloat width = CGRectGetWidth(self.bounds) / (CGFloat)MAX(_charon_actions.count, 1U);
    CGFloat at = 0.0;
    for (CPAlertAction *action in _charon_actions) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.frame = CGRectMake(at, CGRectGetMaxY(self.bounds) - 56.0, width, 44.0);
        [button setTitle:action.title forState:UIControlStateNormal];
        [button setTitleColor:[UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
        button.tag = (NSInteger)[_charon_actions indexOfObject:action];
        [button addTarget:self action:@selector(charon_buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:button];
        at += width;
    }
}

- (void)charon_tappedButtonWithTag:(NSInteger)tag
{
    if (tag < 0 || (NSUInteger)tag >= _charon_actions.count) {
        return;
    }
    // The action's own handler, which is what a program gave the action.
    CPAlertAction *action = _charon_actions[(NSUInteger)tag];
    // The action's own handler, which is what a program gave the action, called with the action.
    if (action.handler) {
        action.handler(action);
    }
}

@end

// ============================ the action sheet ============================

@implementation CPActionSheetTemplate {
    NSString *_title;
    NSString *_message;
    NSArray<CPAlertAction *> *_actions;
    CharonCarPlayCard *_charon_card;
}

@synthesize title = _title;
@synthesize message = _message;
@synthesize actions = _actions;

- (instancetype)initWithTitle:(NSString *)title message:(NSString *)message actions:(NSArray<CPAlertAction *> *)actions
{
    self = [super init];
    if (self) {
        _title = [title copy];
        _message = [message copy];
        _actions = [actions copy] ?: @[];
        self.tabTitle = title;
    }
    return self;
}

- (UIViewController *)charon_viewControllerForInterfaceController:(CPInterfaceController *)controller
{
    // The action sheet, as the card its own title, message and actions are drawn in.
    // The card, in a view controller of its own, because the interface controller pushes view
    // controllers and a card is a view.
    UIViewController *host = [[UIViewController alloc] init];
    host.view.backgroundColor = [UIColor blackColor];
    CharonCarPlayCard *card = [[CharonCarPlayCard alloc] initWithFrame:CGRectMake(40.0, 40.0, 600.0, 300.0)];
    card.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.85];
    card.layer.cornerRadius = 14.0;
    [host.view addSubview:card];
    [card charon_showTitle:_title message:_message actions:_actions];
    _charon_card = card;
    return host;
}

@end

// ============================ the alert ============================

@implementation CPAlertTemplate {
    NSArray<NSString *> *_titleVariants;
    NSArray<CPAlertAction *> *_actions;
    CharonCarPlayCard *_charon_card;
}

@synthesize titleVariants = _titleVariants;
@synthesize actions = _actions;

// The header's own designated initialiser: the title variants and the actions themselves, which are
// the header's own CPAlertAction objects, so a program's own actions are this alert's actions.
- (instancetype)initWithTitleVariants:(NSArray<NSString *> *)titleVariants
                              actions:(NSArray<CPAlertAction *> *)actions
{
    self = [super init];
    if (self) {
        _titleVariants = [titleVariants copy] ?: @[];
        _actions = [actions copy] ?: @[];
        self.tabTitle = _titleVariants.firstObject;
    }
    return self;
}

// The header's own class limit on the actions an alert may have, which is a limit and not a count.
+ (NSUInteger)maximumActionCount
{
    return 3;
}

- (void)charon_dismiss
{
    // An alert is dismissed by the interface controller that showed it, which is a view controller
    // and not a car. Charon's own, so it carries no API.
    [self charon_dismissThroughInterfaceController];
}

- (void)charon_dismissThroughInterfaceController
{
    // The interface controller that presented this alert, which the port's own interface controller
    // records when it pushes a template and forgets when it pops it, so an alert's own action
    // dismisses through the same controller that presented it.
    id controller = [[CharonCarPlayInterface current] controller];
    if (controller) {
        SEL dismiss = NSSelectorFromString(@"dismissTemplateAnimated:completion:");
        if ([controller respondsToSelector:dismiss]) {
            void (*send)(id, SEL, BOOL, id) = (void (*)(id, SEL, BOOL, id))objc_msgSend;
            send(controller, dismiss, YES, nil);
        }
    }
}

- (UIViewController *)charon_viewControllerForInterfaceController:(CPInterfaceController *)controller
{
    UIViewController *host = [[UIViewController alloc] init];
    host.view.backgroundColor = [UIColor blackColor];
    CharonCarPlayCard *card = [[CharonCarPlayCard alloc] initWithFrame:CGRectMake(40.0, 40.0, 600.0, 280.0)];
    card.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.85];
    card.layer.cornerRadius = 14.0;
    [host.view addSubview:card];
    [card charon_showTitle:_titleVariants.firstObject message:@"" actions:_actions];
    _charon_card = card;
    return host;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_titleVariants forKey:@"CPAlertTemplateTitleVariants"];
    [coder encodeObject:_actions forKey:@"CPAlertTemplateActions"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        _titleVariants = [coder decodeObjectForKey:@"CPAlertTemplateTitleVariants"] ?: @[];
        _actions = [coder decodeObjectForKey:@"CPAlertTemplateActions"] ?: @[];
    }
    return self;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

@end

// ============================ the image set ============================

@implementation CPImageSet {
    UIImage *_lightContentImage;
    UIImage *_darkContentImage;
}

@synthesize lightContentImage = _lightContentImage;
@synthesize darkContentImage = _darkContentImage;

// The header's own pair: a light image and a dark one, so a card can be drawn for the screen it is
// on. The image the port picks is the light one, and the reason is written down: the release has no
// dark mode for a car screen to be in.
- (UIImage *)charon_imageForCurrentAppearance
{
    return _lightContentImage ?: _darkContentImage;
}

// The class's own storage, reached from the object that carries
// -initWithLightContentImage:darkContentImage:, which CPImageSet.h declares and a category cannot
// write an ivar for. Both images are kept as given, nil included, and the accessor above is what picks
// between them - so an image set with neither is one with nothing to draw, not a placeholder.
- (void)charon_setLightContentImage:(UIImage *)lightImage darkContentImage:(UIImage *)darkImage
{
    _lightContentImage = lightImage;
    _darkContentImage = darkImage;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_lightContentImage forKey:@"CPImageSetLight"];
    [coder encodeObject:_darkContentImage forKey:@"CPImageSetDark"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _lightContentImage = [coder decodeObjectForKey:@"CPImageSetLight"];
        _darkContentImage = [coder decodeObjectForKey:@"CPImageSetDark"];
    }
    return self;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

@end

// ============================ the trip and its route choices ============================

@implementation CPRouteChoice {
    NSArray<NSString *> *_summaryVariants;
    NSArray<NSString *> *_selectionSummaryVariants;
    NSArray<NSString *> *_additionalInformationVariants;
    id _userInfo;
}

@synthesize summaryVariants = _summaryVariants;
@synthesize selectionSummaryVariants = _selectionSummaryVariants;
@synthesize additionalInformationVariants = _additionalInformationVariants;
@synthesize userInfo = _userInfo;

- (instancetype)initWithSummaryVariants:(NSArray<NSString *> *)summaryVariants
            additionalInformationVariants:(NSArray<NSString *> *)additionalInformationVariants
                selectionSummaryVariants:(NSArray<NSString *> *)selectionSummaryVariants
{
    self = [super init];
    if (self) {
        _summaryVariants = [summaryVariants copy] ?: @[];
        _additionalInformationVariants = [additionalInformationVariants copy];
        _selectionSummaryVariants = [selectionSummaryVariants copy];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithSummaryVariants:_summaryVariants
                                additionalInformationVariants:_additionalInformationVariants
                                    selectionSummaryVariants:_selectionSummaryVariants];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_summaryVariants forKey:@"CPRouteChoiceSummaryVariants"];
    [coder encodeObject:_additionalInformationVariants forKey:@"CPRouteChoiceAdditionalInformationVariants"];
    [coder encodeObject:_selectionSummaryVariants forKey:@"CPRouteChoiceSelectionSummaryVariants"];
    [coder encodeObject:_userInfo forKey:@"CPRouteChoiceUserInfo"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _summaryVariants = [coder decodeObjectForKey:@"CPRouteChoiceSummaryVariants"] ?: @[];
        _additionalInformationVariants = [coder decodeObjectForKey:@"CPRouteChoiceAdditionalInformationVariants"];
        _selectionSummaryVariants = [coder decodeObjectForKey:@"CPRouteChoiceSelectionSummaryVariants"];
        _userInfo = [coder decodeObjectForKey:@"CPRouteChoiceUserInfo"];
    }
    return self;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

@end

@implementation CPTrip {
    MKMapItem *_origin;
    MKMapItem *_destination;
    NSArray<CPRouteChoice *> *_routeChoices;
    id _userInfo;
    NSArray<CPBarButton *> *_charon_bar_buttons;
    // The 17.4 member's storage, reached from CarPlayTrip174.m through the charon_ accessors below. See
    // the comment on those accessors for why it is here and not there.
    NSArray<NSString *> *_charon_destinationNameVariants;
}

@synthesize origin = _origin;
@synthesize destination = _destination;
@synthesize routeChoices = _routeChoices;
@synthesize userInfo = _userInfo;

- (instancetype)initWithOrigin:(MKMapItem *)origin
                   destination:(MKMapItem *)destination
                  routeChoices:(NSArray<CPRouteChoice *> *)routeChoices
{
    self = [super init];
    if (self) {
        _origin = origin;
        _destination = destination;
        _routeChoices = [routeChoices copy] ?: @[];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_origin forKey:@"CPTripOrigin"];
    [coder encodeObject:_destination forKey:@"CPTripDestination"];
    [coder encodeObject:_routeChoices forKey:@"CPTripRouteChoices"];
    [coder encodeObject:_userInfo forKey:@"CPTripUserInfo"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self initWithOrigin:[coder decodeObjectForKey:@"CPTripOrigin"]
                   destination:[coder decodeObjectForKey:@"CPTripDestination"]
                  routeChoices:[coder decodeObjectForKey:@"CPTripRouteChoices"] ?: @[]];
}

// The 17.4 member's storage, reached from CarPlayTrip174.m. A category cannot add an ivar and the class's
// @implementation is this file, so the value lives here behind a Charon-prefixed accessor - the same
// shape CarPlayNavigationSession12.m uses for _turnCardTimeColor. The name is Charon-prefixed, so none of
// it is API and none of it appears in this object's exports: this file is 12.0 and stays 12.0, and the
// 17.4 selectors live in their own object.
- (NSArray<NSString *> *)charon_destinationNameVariants
{
    return _charon_destinationNameVariants;
}

- (void)charon_setDestinationNameVariants:(NSArray<NSString *> *)variants
{
    // CPTrip.h:158 declares the property `copy, nullable`, so the copy happens here and a nil in is a nil
    // out.
    _charon_destinationNameVariants = [variants copy];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

@end

@implementation CPTripPreviewTextConfiguration {
    NSString *_startButtonTitle;
    NSString *_additionalRoutesButtonTitle;
    NSString *_overviewButtonTitle;
}

@synthesize startButtonTitle = _startButtonTitle;
@synthesize additionalRoutesButtonTitle = _additionalRoutesButtonTitle;
@synthesize overviewButtonTitle = _overviewButtonTitle;

- (instancetype)initWithStartButtonTitle:(NSString *)startButtonTitle
              additionalRoutesButtonTitle:(NSString *)additionalRoutesButtonTitle
                       overviewButtonTitle:(NSString *)overviewButtonTitle
{
    self = [super init];
    if (self) {
        _startButtonTitle = [startButtonTitle copy];
        _additionalRoutesButtonTitle = [additionalRoutesButtonTitle copy];
        _overviewButtonTitle = [overviewButtonTitle copy];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_startButtonTitle forKey:@"CPTripPreviewStartButtonTitle"];
    [coder encodeObject:_additionalRoutesButtonTitle forKey:@"CPTripPreviewAdditionalRoutesButtonTitle"];
    [coder encodeObject:_overviewButtonTitle forKey:@"CPTripPreviewOverviewButtonTitle"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _startButtonTitle = [coder decodeObjectForKey:@"CPTripPreviewStartButtonTitle"];
        _additionalRoutesButtonTitle = [coder decodeObjectForKey:@"CPTripPreviewAdditionalRoutesButtonTitle"];
        _overviewButtonTitle = [coder decodeObjectForKey:@"CPTripPreviewOverviewButtonTitle"];
    }
    return self;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

@end

// ============================ the search template ============================

@implementation CPSearchTemplate {
    __weak id<CPSearchTemplateDelegate> _delegate;
    UISearchBar *_charon_search_bar;
}

@synthesize delegate = _delegate;

// The search template, as a search field over an empty list: the header's own
// -searchTemplate:updatedSearchText:completionHandler: is the answer, and this is the field the
// user's text goes into and the delegate is told about.
- (UIViewController *)charon_viewControllerForInterfaceController:(CPInterfaceController *)controller
{
    UIViewController *host = [[UIViewController alloc] init];
    host.view.backgroundColor = [UIColor blackColor];
    _charon_search_bar = [[UISearchBar alloc] initWithFrame:CGRectMake(0.0, 0.0, 1024.0, 60.0)];
    _charon_search_bar.delegate = (id<UISearchBarDelegate>)self;
    [host.view addSubview:_charon_search_bar];
    return host;
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    id<CPSearchTemplateDelegate> delegate = _delegate;
    SEL updated = NSSelectorFromString(@"searchTemplate:updatedSearchText:completionHandler:");
    if ([delegate respondsToSelector:updated]) {
        // The header's own answer: the program searches and answers with its own results.
        void (*send)(id, SEL, CPSearchTemplate *, NSString *, id) =
            (void (*)(id, SEL, CPSearchTemplate *, NSString *, id))objc_msgSend;
        send(delegate, updated, self, searchText ?: @"", ^(NSArray<CPListItem *> *results) {
        });
    }
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    id<CPSearchTemplateDelegate> delegate = _delegate;
    SEL pressed = NSSelectorFromString(@"searchTemplateSearchButtonPressed:");
    if ([delegate respondsToSelector:pressed]) {
        void (*send)(id, SEL, CPSearchTemplate *) = (void (*)(id, SEL, CPSearchTemplate *))objc_msgSend;
        send(delegate, pressed, self);
    }
}

@end
