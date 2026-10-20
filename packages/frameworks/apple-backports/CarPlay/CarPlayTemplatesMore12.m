#import <CarPlay/CarPlay.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>

@interface RevenantCarPlayInterface : NSObject
+ (instancetype)current;
@property (nonatomic, weak) CPInterfaceController *controller;
@end

@implementation RevenantCarPlayInterface

@synthesize controller = _controller;

+ (instancetype)current
{
    static RevenantCarPlayInterface *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[RevenantCarPlayInterface alloc] init];
    });
    return shared;
}

@end

@interface RevenantCarPlayCard : UIView
- (void)revenant_showTitle:(NSString *)title
                 message:(NSString *)message
                  actions:(NSArray<CPAlertAction *> *)actions;
@end

@implementation RevenantCarPlayCard {
    NSArray<CPAlertAction *> *_revenant_actions;
}

- (void)revenant_buttonTapped:(UIButton *)button
{
    NSInteger tag = button.tag;
    if (tag < 0 || (NSUInteger)tag >= _revenant_actions.count) {
        return;
    }
    CPAlertAction *action = _revenant_actions[(NSUInteger)tag];
    if (action.handler) {
        action.handler(action);
    }
}

- (void)revenant_showTitle:(NSString *)title message:(NSString *)message actions:(NSArray<CPAlertAction *> *)actions
{
    _revenant_actions = [actions copy] ?: @[];
    for (UIView *view in self.subviews) {
        [view removeFromSuperview];
    }
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectInset(self.bounds, 16.0, 16.0)];
    label.text = message.length > 0 ? [NSString stringWithFormat:@"%@\n%@", title ?: @"", message] : (title ?: @"");
    label.numberOfLines = 3;
    label.textColor = [UIColor whiteColor];
    [self addSubview:label];
    CGFloat width = CGRectGetWidth(self.bounds) / (CGFloat)MAX(_revenant_actions.count, 1U);
    CGFloat at = 0.0;
    for (CPAlertAction *action in _revenant_actions) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.frame = CGRectMake(at, CGRectGetMaxY(self.bounds) - 56.0, width, 44.0);
        [button setTitle:action.title forState:UIControlStateNormal];
        [button setTitleColor:[UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
        button.tag = (NSInteger)[_revenant_actions indexOfObject:action];
        [button addTarget:self action:@selector(revenant_buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:button];
        at += width;
    }
}

- (void)revenant_tappedButtonWithTag:(NSInteger)tag
{
    if (tag < 0 || (NSUInteger)tag >= _revenant_actions.count) {
        return;
    }
    CPAlertAction *action = _revenant_actions[(NSUInteger)tag];
    if (action.handler) {
        action.handler(action);
    }
}

@end

@implementation CPActionSheetTemplate {
    NSString *_title;
    NSString *_message;
    NSArray<CPAlertAction *> *_actions;
    RevenantCarPlayCard *_revenant_card;
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

- (UIViewController *)revenant_viewControllerForInterfaceController:(CPInterfaceController *)controller
{
    UIViewController *host = [[UIViewController alloc] init];
    host.view.backgroundColor = [UIColor blackColor];
    RevenantCarPlayCard *card = [[RevenantCarPlayCard alloc] initWithFrame:CGRectMake(40.0, 40.0, 600.0, 300.0)];
    card.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.85];
    card.layer.cornerRadius = 14.0;
    [host.view addSubview:card];
    [card revenant_showTitle:_title message:_message actions:_actions];
    _revenant_card = card;
    return host;
}

@end

@implementation CPAlertTemplate {
    NSArray<NSString *> *_titleVariants;
    NSArray<CPAlertAction *> *_actions;
    RevenantCarPlayCard *_revenant_card;
}

@synthesize titleVariants = _titleVariants;
@synthesize actions = _actions;

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

+ (NSUInteger)maximumActionCount
{
    return 3;
}

- (void)revenant_dismiss
{
    [self revenant_dismissThroughInterfaceController];
}

- (void)revenant_dismissThroughInterfaceController
{
    id controller = [[RevenantCarPlayInterface current] controller];
    if (controller) {
        SEL dismiss = NSSelectorFromString(@"dismissTemplateAnimated:completion:");
        if ([controller respondsToSelector:dismiss]) {
            void (*send)(id, SEL, BOOL, id) = (void (*)(id, SEL, BOOL, id))objc_msgSend;
            send(controller, dismiss, YES, nil);
        }
    }
}

- (UIViewController *)revenant_viewControllerForInterfaceController:(CPInterfaceController *)controller
{
    UIViewController *host = [[UIViewController alloc] init];
    host.view.backgroundColor = [UIColor blackColor];
    RevenantCarPlayCard *card = [[RevenantCarPlayCard alloc] initWithFrame:CGRectMake(40.0, 40.0, 600.0, 280.0)];
    card.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.85];
    card.layer.cornerRadius = 14.0;
    [host.view addSubview:card];
    [card revenant_showTitle:_titleVariants.firstObject message:@"" actions:_actions];
    _revenant_card = card;
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

@implementation CPImageSet {
    UIImage *_lightContentImage;
    UIImage *_darkContentImage;
}

@synthesize lightContentImage = _lightContentImage;
@synthesize darkContentImage = _darkContentImage;

- (UIImage *)revenant_imageForCurrentAppearance
{
    return _lightContentImage ?: _darkContentImage;
}

- (void)revenant_setLightContentImage:(UIImage *)lightImage darkContentImage:(UIImage *)darkImage
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
    NSArray<CPBarButton *> *_revenant_bar_buttons;
    NSArray<NSString *> *_revenant_destinationNameVariants;
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

- (NSArray<NSString *> *)revenant_destinationNameVariants
{
    return _revenant_destinationNameVariants;
}

- (void)revenant_setDestinationNameVariants:(NSArray<NSString *> *)variants
{
    _revenant_destinationNameVariants = [variants copy];
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

@implementation CPSearchTemplate {
    __weak id<CPSearchTemplateDelegate> _delegate;
    UISearchBar *_revenant_search_bar;
}

@synthesize delegate = _delegate;

- (UIViewController *)revenant_viewControllerForInterfaceController:(CPInterfaceController *)controller
{
    UIViewController *host = [[UIViewController alloc] init];
    host.view.backgroundColor = [UIColor blackColor];
    _revenant_search_bar = [[UISearchBar alloc] initWithFrame:CGRectMake(0.0, 0.0, 1024.0, 60.0)];
    _revenant_search_bar.delegate = (id<UISearchBarDelegate>)self;
    [host.view addSubview:_revenant_search_bar];
    return host;
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    id<CPSearchTemplateDelegate> delegate = _delegate;
    SEL updated = NSSelectorFromString(@"searchTemplate:updatedSearchText:completionHandler:");
    if ([delegate respondsToSelector:updated]) {
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
