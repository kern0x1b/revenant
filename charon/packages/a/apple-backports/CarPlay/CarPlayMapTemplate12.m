#import <CarPlay/CarPlay.h>
#import <UIKit/UIKit.h>
#import "CharonCarPlayTemplate.h"

static const NSUInteger CharonMapMaximumPreviews = 12;

@interface CharonMapPreviewCard : UIView
@end

@implementation CharonMapPreviewCard
@end

@implementation CPMapTemplate (CharonMapTemplate12)

#pragma mark - the navigation alert

- (void)presentNavigationAlert:(CPNavigationAlert *)navigationAlert animated:(BOOL)animated
{
    if (navigationAlert == nil || self.charon_navigationAlert != nil) {
        return;
    }
    if (animated) {
        [UIView beginAnimations:@"charon.alert.present" context:nil];
        [UIView setAnimationDuration:0.25];
    }
    [self charon_setNavigationAlert:navigationAlert];
    if (animated) {
        [UIView commitAnimations];
    }
}

- (void)dismissNavigationAlertAnimated:(BOOL)animated completion:(void (^)(BOOL dismissed))completion
{
    BOOL wasVisible = self.charon_navigationAlert != nil;
    if (animated) {
        [UIView beginAnimations:@"charon.alert.dismiss" context:nil];
        [UIView setAnimationDuration:0.25];
    }
    [self charon_setNavigationAlert:nil];
    if (animated) {
        [UIView commitAnimations];
    }
    if (completion != NULL) {
        completion(wasVisible);
    }
}

#pragma mark - the panning interface

- (void)showPanningInterfaceAnimated:(BOOL)animated
{
    if (self.charon_panningInterfaceVisible) {
        return;
    }
    if (animated) {
        [UIView beginAnimations:@"charon.panning.show" context:nil];
        [UIView setAnimationDuration:0.25];
    }
    [self charon_setPanningInterfaceVisible:YES];
    NSArray<CPMapButton *> *buttons = self.mapButtons;
    for (NSUInteger i = 0; i < buttons.count; i++) {
        [buttons[i] setHidden:i >= 2];
    }
    if (animated) {
        [UIView commitAnimations];
    }
}

- (void)dismissPanningInterfaceAnimated:(BOOL)animated
{
    if (!self.charon_panningInterfaceVisible) {
        return;
    }
    if (animated) {
        [UIView beginAnimations:@"charon.panning.dismiss" context:nil];
        [UIView setAnimationDuration:0.25];
    }
    [self charon_setPanningInterfaceVisible:NO];
    for (CPMapButton *button in self.mapButtons) {
        [button setHidden:NO];
    }
    if (animated) {
        [UIView commitAnimations];
    }
}

#pragma mark - the trip previews

- (void)showTripPreviews:(NSArray<CPTrip *> *)trips textConfiguration:(CPTripPreviewTextConfiguration *)textConfiguration
{
    if (trips == nil) {
        return;
    }
    NSUInteger kept = MIN(trips.count, CharonMapMaximumPreviews);
    [self charon_setTripPreviews:[trips subarrayWithRange:NSMakeRange(0, kept)] selectedTrip:nil];
    [self charon_drawTripPreviews];
}

- (void)showRouteChoicesPreviewForTrip:(CPTrip *)trip textConfiguration:(CPTripPreviewTextConfiguration *)textConfiguration
{
    if (trip == nil) {
        return;
    }
    [self charon_setTripPreviews:@[trip] selectedTrip:trip];
    [self charon_drawTripPreviews];
}

- (void)hideTripPreviews
{
    [self charon_setTripPreviews:nil selectedTrip:nil];
    UIView *map = [self charon_mapView];
    for (UIView *sub in [map.subviews copy]) {
        if ([sub isKindOfClass:[CharonMapPreviewCard class]]) {
            [sub removeFromSuperview];
        }
    }
}

#pragma mark - the travel estimates

- (void)updateTravelEstimates:(CPTravelEstimates *)estimates forTrip:(CPTrip *)trip
{
    [self updateTravelEstimates:estimates forTrip:trip withTimeRemainingColor:CPTimeRemainingColorDefault];
}

- (void)updateTravelEstimates:(CPTravelEstimates *)estimates
                      forTrip:(CPTrip *)trip
         withTimeRemainingColor:(CPTimeRemainingColor)timeRemainingColor
{
    if (trip == nil) {
        return;
    }
    [self charon_setEstimates:estimates forTrip:trip];
    [self charon_setTimeRemainingColor:timeRemainingColor];
}

#pragma mark - the drawing these members reach

static NSString *charon_nameForTimeRemainingColor(CPTimeRemainingColor color)
{
    switch (color) {
        case CPTimeRemainingColorGreen: return @"green";
        case CPTimeRemainingColorOrange: return @"orange";
        case CPTimeRemainingColorRed: return @"red";
        case CPTimeRemainingColorDefault: break;
    }
    return @"default";
}

- (void)charon_drawTripPreviews
{
    UIView *map = [self charon_mapView];
    if (map == nil) {
        return;
    }
    for (UIView *sub in [map.subviews copy]) {
        if ([sub isKindOfClass:[CharonMapPreviewCard class]]) {
            [sub removeFromSuperview];
        }
    }
    NSArray<CPTrip *> *previews = self.charon_tripPreviews;
    if (previews.count == 0) {
        return;
    }
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    for (CPTrip *trip in previews) {
        NSString *origin = trip.origin.name;
        NSString *destination = trip.destination.name;
        [lines addObject:origin.length > 0 ? (destination.length > 0
                                              ? [NSString stringWithFormat:@"%@ to %@", origin, destination]
                                              : origin)
                                           : @"(trip)"];
    }
    if (self.charon_selectedTrip != nil) {
        CPTravelEstimates *estimates = [self charon_estimatesForTrip:self.charon_selectedTrip];
        if (estimates != nil) {
            NSString *remaining = estimates.timeRemaining < 0.0
                ? @"--"
                : [NSString stringWithFormat:@"%.0f min", estimates.timeRemaining / 60.0];
            [lines addObject:[NSString stringWithFormat:@"%@ - %@", remaining,
                                  charon_nameForTimeRemainingColor(self.charon_timeRemainingColor)]];
        }
    }
    CGSize size = CGSizeMake(420.0, 24.0 + 22.0 * (CGFloat)lines.count);
    CharonMapPreviewCard *card = [[CharonMapPreviewCard alloc]
        initWithFrame:CGRectMake(20.0, CGRectGetHeight(map.bounds) - size.height - 20.0,
                                 size.width, size.height)];
    card.backgroundColor = self.guidanceBackgroundColor;
    card.layer.cornerRadius = 10.0;
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectInset(card.bounds, 12.0, 8.0)];
    label.text = [lines componentsJoinedByString:@"\n"];
    label.numberOfLines = (NSInteger)lines.count;
    label.textColor = [UIColor whiteColor];
    [card addSubview:label];
    [map addSubview:card];
}

@end

@implementation CPImageSet (CharonImageSetInitialiser)

- (instancetype)initWithLightContentImage:(UIImage *)lightImage darkContentImage:(UIImage *)darkImage
{
    self = [super init];
    if (self) {
        [self charon_setLightContentImage:lightImage darkContentImage:darkImage];
    }
    return self;
}

@end
